import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../domain/auth.dart';

const issuer = 'https://auth.openai.com';
const resource = 'https://api.openai.com/v1';
const authorizeEndpoint = '$issuer/api/accounts/authorize';
const tokenEndpoint = '$issuer/api/accounts/oauth/token';
const requestedScopes =
    'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';

String secureValue([int length = 32]) {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(length, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

String pkceChallenge(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

class OAuthAttempt {
  OAuthAttempt({
    required this.redirect,
    required this.hostId,
    this.savedClientId,
    this.idTokenHint,
    this.loginHint,
    String? state,
    String? nonce,
    String? verifier,
  }) : state = state ?? secureValue(),
       nonce = nonce ?? secureValue(),
       verifier = verifier ?? secureValue(64);
  final Uri redirect;
  final String hostId;
  final String? savedClientId;
  final String? idTokenHint;
  final String? loginHint;
  final String state;
  final String nonce;
  final String verifier;
  Uri get authorizationUri => Uri.parse(authorizeEndpoint).replace(
    queryParameters: {
      'client_id': savedClientId ?? 'dynamic_agent_client',
      if (savedClientId == null) 'agent_name_hint': 'Guide Ryadom',
      'ext_agent_host_id': hostId,
      'id_token_hint': ?idTokenHint,
      'login_hint': ?loginHint,
      'response_type': 'code',
      'redirect_uri': redirect.toString(),
      'scope': requestedScopes,
      'resource': resource,
      'state': state,
      'nonce': nonce,
      'code_challenge_method': 'S256',
      'code_challenge': pkceChallenge(verifier),
    },
  );

  ({String code, String clientId}) validateCallback(Uri uri) {
    if (uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        uri.port != redirect.port ||
        uri.path != '/auth/callback' ||
        uri.fragment.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll.values.any((v) => v.length != 1)) {
      throw const AuthFailure('state');
    }
    final q = uri.queryParameters;
    if (q['state'] != state) throw const AuthFailure('state');
    if (q.containsKey('error')) {
      throw AuthFailure(q['error'] == 'access_denied' ? 'denied' : 'protocol');
    }
    final id = q['client_id'] ?? savedClientId;
    if (id == null ||
        id.isEmpty ||
        id == 'dynamic_agent_client' ||
        (savedClientId != null && id != savedClientId)) {
      throw const AuthFailure('client');
    }
    final code = q['code'];
    if (code == null || code.isEmpty) throw const AuthFailure('protocol');
    return (code: code, clientId: id);
  }
}

abstract interface class AuthVault {
  Future<String> hostId();
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class SystemBrowser {
  Future<void> open(Uri uri);
}

abstract interface class CallbackReceiver {
  Future<Uri> start();
  Future<Uri> get callback;
  Future<void> close();
}
