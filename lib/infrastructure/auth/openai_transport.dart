import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

import '../../domain/auth.dart';
import 'oauth_contract.dart';
import 'auth_errors.dart';

const diagnosticPrompt =
    'Расскажи один интересный и общеизвестный факт о Питерборском соборе в двух предложениях.';

class OpenAiTransport {
  OpenAiTransport(this.client);
  final http.Client client;
  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _jwks;

  Future<http.StreamedResponse> send(http.Request request) async {
    request.followRedirects = false;
    return client.send(request).timeout(const Duration(seconds: 25));
  }

  Future<Map<String, dynamic>> jsonRequest(
    String method,
    Uri uri, {
    Map<String, String>? form,
    String? token,
    AuthStage? stage,
  }) async {
    try {
      return await _jsonRequest(method, uri, form: form, token: token);
    } catch (error) {
      if (stage == null) rethrow;
      throw safeAuthFailure(error, stage);
    }
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    Uri uri, {
    Map<String, String>? form,
    String? token,
  }) async {
    final request = http.Request(method, uri);
    if (form != null) request.bodyFields = form;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final response = await send(request);
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const AuthFailure('protocol');
      }
      bytes.addAll(chunk);
    }
    Map<String, dynamic> body;
    try {
      body = bytes.isEmpty
          ? {}
          : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode != 200) throw httpFailure(response.statusCode);
      throw const AuthFailure('protocol');
    }
    if (response.statusCode != 200) {
      throw httpFailure(response.statusCode, body);
    }
    return body;
  }

  Future<Map<String, dynamic>> metadata() async {
    if (_metadata != null) return _metadata!;
    final data = await jsonRequest(
      'GET',
      Uri.parse('$issuer/.well-known/openid-configuration'),
      stage: AuthStage.metadata,
    );
    if (data['issuer'] != issuer ||
        data['authorization_endpoint'] != authorizeEndpoint ||
        data['token_endpoint'] != tokenEndpoint ||
        !(data['id_token_signing_alg_values_supported'] as List? ?? [])
            .contains('RS256')) {
      throw const AuthFailure('protocol');
    }
    trustedAuthUri(data['jwks_uri']);
    trustedAuthUri(data['revocation_endpoint']);
    return _metadata = data;
  }

  Uri trustedAuthUri(dynamic value) {
    if (value is! String) throw const AuthFailure('protocol');
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host != 'auth.openai.com' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const AuthFailure('protocol');
    }
    return uri;
  }

  Future<AccountInfo> verifyIdentity(
    String encoded,
    String clientId, {
    required String? nonce,
    String? expectedSubject,
    DateTime? now,
  }) async {
    try {
      final metadataValue = await metadata();
      final parts = encoded.split('.');
      if (parts.length != 3 || encoded.length > 64000) {
        throw const AuthFailure('identity');
      }
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
      ) as Map<String, dynamic>;
      if (header['alg'] != 'RS256' ||
          header['kid'] is! String ||
          header.containsKey('crit')) {
        throw const AuthFailure('identity');
      }
      final jwksUri = trustedAuthUri(metadataValue['jwks_uri']);
      _jwks ??= await jsonRequest('GET', jwksUri, stage: AuthStage.jwks);
      List<dynamic> matching() => (_jwks!['keys'] as List)
          .where(
            (dynamic k) =>
                k['kid'] == header['kid'] &&
                k['kty'] == 'RSA' &&
                (k['use'] == null || k['use'] == 'sig') &&
                (k['alg'] == null || k['alg'] == 'RS256'),
          )
          .toList();
      var keys = matching();
      if (keys.isEmpty) {
        _jwks = await jsonRequest('GET', jwksUri, stage: AuthStage.jwks);
        keys = matching();
      }
      if (keys.length != 1) throw const AuthFailure('identity');
      final store = JsonWebKeyStore()
        ..addKey(
          JsonWebKey.fromJson(Map<String, dynamic>.from(keys.single as Map)),
        );
      final jwt = JsonWebToken.unverified(encoded);
      if (!await jwt.verify(store, allowedArguments: ['RS256'])) {
        throw const AuthFailure('identity');
      }
      final claims = jwt.claims.toJson();
      final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      final aud = claims['aud'];
      final validAud = aud == clientId || aud is List && aud.contains(clientId);
      if (claims['iss'] != issuer ||
          !validAud ||
          (aud is List && aud.length > 1 && claims['azp'] != clientId) ||
          (claims['azp'] != null && claims['azp'] != clientId) ||
          claims['exp'] is! num ||
          (claims['exp'] as num) <= seconds - 5 ||
          claims['iat'] is! num ||
          (claims['iat'] as num) > seconds + 5 ||
          (claims['nbf'] != null &&
              (claims['nbf'] is! num ||
                  (claims['nbf'] as num) > seconds + 5)) ||
          (nonce != null && claims['nonce'] != nonce) ||
          claims['sub'] is! String ||
          (claims['sub'] as String).isEmpty ||
          (expectedSubject != null && claims['sub'] != expectedSubject)) {
        throw const AuthFailure('identity');
      }
      return AccountInfo(
        clientId: clientId,
        subject: claims['sub'] as String,
        email: claims['email'] is String ? claims['email'] as String : null,
      );
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('identity');
    }
  }

  Future<List<AvailableModel>> models(String token) async {
    final body = await jsonRequest(
      'GET',
      Uri.parse('$resource/models'),
      token: token,
    );
    final data = body['models'];
    if (data is! List) throw const AuthFailure('protocol');
    final models = <AvailableModel>[];
    for (final item in data) {
      if (item is Map &&
          item['visibility'] == 'list' &&
          item['slug'] is String &&
          (item['slug'] as String).isNotEmpty &&
          item['display_name'] is String) {
        models.add(
          AvailableModel(
            item['slug'] as String,
            item['display_name'] as String,
          ),
        );
      }
    }
    if (models.isEmpty) throw const AuthFailure('models');
    return models;
  }

  Future<String> probe(
    String token,
    String model,
    void Function(String) onPartial,
  ) async {
    final request = http.Request('POST', Uri.parse('$resource/responses'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'input': [
          {'role': 'user', 'content': diagnosticPrompt},
        ],
        'store': false,
        'stream': true,
      });
    final response = await send(request);
    if (response.statusCode != 200) {
      // Status is safe to expose; never print arbitrary error bodies.
      await response.stream.listen((_) {}).cancel();
      throw httpFailure(response.statusCode);
    }
    // MIME type/subtype are case insensitive; parameters are not the type.
    final mediaType = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (mediaType != 'text/event-stream') {
      // Release the rejected stream. Never expose arbitrary header/body values.
      await response.stream.listen((_) {}).cancel();
      throw AuthFailure(
        'response_format',
        status: response.statusCode,
        media: switch (mediaType) {
          '' => ResponseMedia.missing,
          'application/json' ||
          'application/problem+json' => ResponseMedia.json,
          'text/html' => ResponseMedia.html,
          'text/plain' => ResponseMedia.text,
          'application/octet-stream' => ResponseMedia.binary,
          _ => ResponseMedia.other,
        },
      );
    }
    return parseResponseStream(
      response.stream,
      onPartial,
    ).timeout(const Duration(seconds: 90));
  }
}

AuthFailure httpFailure(int status, [Map<String, dynamic>? body]) {
  final error = body?['error'];
  final code = error is Map ? error['code'] ?? error['type'] : error;
  if (const {
    'invalid_grant',
    'invalid_refresh_token',
    'token_expired',
    'refresh_token_expired',
    'refresh_token_invalidated',
    'refresh_token_reused',
  }.contains(code)) {
    return AuthFailure('expired', status: status);
  }
  if (status == 429 || code == 'subscription_sharing_usage_limit_exceeded') {
    return AuthFailure('quota', status: status);
  }
  if (status == 401) return AuthFailure('expired', status: status);
  if (status == 403) return AuthFailure('forbidden', status: status);
  return AuthFailure('network', status: status);
}

/// SSE frame boundaries and UTF-8 may be split across arbitrary network chunks.
Future<String> parseResponseStream(
  Stream<List<int>> bytes,
  void Function(String) onPartial,
) async {
  final data = <String>[];
  var text = '';
  var size = 0;
  String? responseId;
  await for (final line
      in bytes
          .timeout(const Duration(seconds: 25))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    size += line.length;
    if (size > 512 * 1024) throw const AuthFailure('stream');
    if (line.startsWith('data:')) {
      data.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
    }
    if (line.isNotEmpty || data.isEmpty) continue;
    final payload = data.join('\n');
    data.clear();
    if (payload == '[DONE]') throw const AuthFailure('stream');
    Map<String, dynamic> event;
    try {
      event = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthFailure('stream');
    }
    final type = event['type'];
    if (type == 'response.created') {
      final response = event['response'];
      if (response is! Map || response['id'] is! String) {
        throw const AuthFailure('stream');
      }
      responseId = response['id'] as String;
    } else if (type == 'response.output_text.delta') {
      if (event['delta'] is! String) throw const AuthFailure('stream');
      text += event['delta'] as String;
      onPartial(text);
    } else if (type == 'response.failed' ||
        type == 'response.incomplete' ||
        type == 'error') {
      final response = event['response'];
      final error = response is Map ? response['error'] : event['error'];
      if (error is Map &&
          error['code'] == 'subscription_sharing_usage_limit_exceeded') {
        throw const AuthFailure('quota');
      }
      throw const AuthFailure('stream');
    } else if (type == 'response.completed') {
      final response = event['response'];
      if (response is! Map ||
          response['status'] != 'completed' ||
          response['id'] is! String ||
          (responseId != null && response['id'] != responseId) ||
          response['output'] is! List) {
        throw const AuthFailure('stream');
      }
      final result = StringBuffer();
      for (final output in response['output'] as List) {
        if (output is Map &&
            output['type'] == 'message' &&
            output['role'] == 'assistant' &&
            output['content'] is List) {
          for (final content in output['content'] as List) {
            if (content is Map &&
                content['type'] == 'output_text' &&
                content['text'] is String) {
              result.write(content['text']);
            }
          }
        }
      }
      if (result.isEmpty) throw const AuthFailure('stream');
      return result.toString();
    }
  }
  throw const AuthFailure('stream');
}
