import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/auth.dart';
import 'oauth_contract.dart';
import 'openai_transport.dart';
import 'auth_errors.dart';

class _Session {
  _Session({
    required this.account,
    required this.access,
    required this.refresh,
    required this.idToken,
    required this.scopes,
    required this.expires,
  });
  final AccountInfo account;
  final String access;
  final String? refresh;
  final String idToken;
  final Set<String> scopes;
  final DateTime expires;
  Map<String, dynamic> toJson() => {
    'clientId': account.clientId,
    'subject': account.subject,
    'email': account.email,
    'access': access,
    'refresh': refresh,
    'idToken': idToken,
    'scopes': scopes.toList(),
    'expires': expires.toUtc().toIso8601String(),
  };
  static _Session fromJson(Map<String, dynamic> value) => _Session(
    account: AccountInfo(
      clientId: value['clientId'] as String,
      subject: value['subject'] as String,
      email: value['email'] as String?,
    ),
    access: value['access'] as String,
    refresh: value['refresh'] as String?,
    idToken: value['idToken'] as String,
    scopes: (value['scopes'] as List).cast<String>().toSet(),
    expires: DateTime.parse(value['expires'] as String),
  );
}

class ChatGptAuthService implements AuthProvider {
  ChatGptAuthService({
    required this.vault,
    required this.browser,
    required this.receiverFactory,
    http.Client Function()? clientFactory,
    this.loginTimeout = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : clientFactory = clientFactory ?? http.Client.new,
       now = now ?? DateTime.now;
  final AuthVault vault;
  final SystemBrowser browser;
  final CallbackReceiver Function() receiverFactory;
  final http.Client Function() clientFactory;
  final Duration loginTimeout;
  final DateTime Function() now;
  final Map<String, AccountInfo> _registrations = {};
  _Session? _session;
  String? _hostId;
  Completer<void>? _work;
  Completer<void>? _cancelSignal;
  Timer? _loginTimer;
  String? _pendingClientId;
  http.Client? _client;
  CallbackReceiver? _receiver;
  int _epoch = 0;
  bool _disposed = false;
  List<AvailableModel> _models = [];
  AuthStage _stage = AuthStage.restore;
  @override
  AccountInfo? get account => _session?.account;
  @override
  List<AccountInfo> get registrations =>
      List.unmodifiable(_registrations.values);
  @override
  bool get inferenceAllowed =>
      _session?.scopes.contains('chatgpt.tokens.use.direct') == true &&
      _session?.scopes.contains('resource.invoke') == true;

  void _check(int epoch) {
    if (_disposed || epoch != _epoch) throw const AuthFailure('cancelled');
  }

  Future<T> _run<T>(
    Future<T> Function(OpenAiTransport transport, int epoch) action,
  ) async {
    if (_disposed) throw const AuthFailure('cancelled');
    if (_work != null) throw const AuthFailure('busy');
    final done = Completer<void>();
    _work = done;
    _cancelSignal = Completer<void>();
    final epoch = ++_epoch;
    final client = clientFactory();
    _client = client;
    var failed = false;
    try {
      return await action(OpenAiTransport(client), epoch);
    } catch (error) {
      failed = true;
      if (epoch != _epoch) throw AuthFailure('cancelled', stage: _stage);
      throw safeAuthFailure(error, _stage);
    } finally {
      _loginTimer?.cancel();
      _loginTimer = null;
      try {
        client.close();
        if (!identical(_client, client)) _client?.close();
        await _receiver?.close();
      } catch (error) {
        if (!failed) throw safeAuthFailure(error, AuthStage.cleanup);
      } finally {
        _receiver = null;
        _client = null;
        _cancelSignal = null;
        _work = null;
        done.complete();
      }
    }
  }

  String _snapshot([_Session? session, bool useCurrent = true]) => jsonEncode({
    'version': 1,
    'registrations': _registrations.values
        .map(
          (a) => {
            'clientId': a.clientId,
            'subject': a.subject,
            'email': a.email,
          },
        )
        .toList(),
    'session': (useCurrent ? _session : session)?.toJson(),
  });

  Future<void> _save() async {
    _stage = AuthStage.storage;
    try {
      await vault.write(_snapshot());
    } catch (_) {
      throw const AuthFailure('storage');
    }
  }

  @override
  Future<void> restore() => _run((transport, epoch) async {
    _stage = AuthStage.restore;
    try {
      _hostId = await vault.hostId();
      final raw = await vault.read();
      _check(epoch);
      if (raw == null) return;
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['version'] != 1) throw const FormatException();
      for (final item in value['registrations'] as List) {
        final account = AccountInfo(
          clientId: item['clientId'] as String,
          subject: item['subject'] as String,
          email: item['email'] as String?,
        );
        _registrations[account.clientId] = account;
      }
      if (value['session'] != null) {
        final session = _Session.fromJson(
          value['session'] as Map<String, dynamic>,
        );
        if (_registrations[session.account.clientId]?.subject !=
            session.account.subject) {
          throw const FormatException();
        }
        _session = session;
      }
    } on AuthFailure {
      rethrow;
    } catch (_) {
      _session = null;
      throw const AuthFailure('storage');
    }
  });

  @override
  Future<void> signIn({String? clientId}) => _run((transport, epoch) async {
    _stage = AuthStage.host;
    final previous = _session;
    final registration = clientId == null ? null : _registrations[clientId];
    if (clientId != null && registration == null) {
      throw const AuthFailure('client');
    }
    _hostId ??= await vault.hostId();
    _stage = AuthStage.metadata;
    await transport.metadata();
    _check(epoch);
    final receiver = receiverFactory();
    _receiver = receiver;
    _stage = AuthStage.listener;
    final redirect = await receiver.start();
    _check(epoch);
    final attempt = OAuthAttempt(
      redirect: redirect,
      hostId: _hostId!,
      savedClientId: clientId ?? _pendingClientId,
      idTokenHint: previous?.account.clientId == clientId
          ? previous?.idToken
          : null,
      loginHint: registration?.email,
    );
    // Attach the callback/error listener before opening the browser.
    final timeout = Completer<Uri>();
    _loginTimer = Timer(
      loginTimeout,
      () => timeout.completeError(const AuthFailure('timeout')),
    );
    final callback = Future.any<Uri>([
      receiver.callback,
      timeout.future,
      _cancelSignal!.future.then<Uri>(
        (_) => throw const AuthFailure('cancelled'),
      ),
    ]);
    // Guard against an early rejected callback while the platform opens the browser.
    unawaited(callback.then<void>((_) {}, onError: (Object _) {}));
    _stage = AuthStage.browser;
    await browser.open(attempt.authorizationUri);
    _stage = AuthStage.callback;
    final result = attempt.validateCallback(await callback);
    _loginTimer?.cancel();
    _stage = AuthStage.cleanup;
    await receiver.close();
    _check(epoch);
    // Consent can outlive the metadata connection or switch networks. Use a
    // new pool for the first and only code exchange; never retry a used code.
    _client?.close();
    final exchangeClient = clientFactory();
    _client = exchangeClient;
    transport = OpenAiTransport(exchangeClient);
    Map<String, dynamic> tokens;
    _stage = AuthStage.exchange;
    try {
      tokens = await transport.jsonRequest(
        'POST',
        Uri.parse(tokenEndpoint),
        form: {
          'grant_type': 'authorization_code',
          'client_id': result.clientId,
          'code': result.code,
          'code_verifier': attempt.verifier,
          'redirect_uri': redirect.toString(),
          'resource': resource,
        },
      );
    } on AuthFailure catch (error) {
      // Retain the issued ID only for a fresh attempt in this process, not as a verified identity.
      if (error.code == 'expired') _pendingClientId = result.clientId;
      rethrow;
    }
    _check(epoch);
    final idToken = tokens['id_token'];
    _stage = AuthStage.identity;
    if (idToken is! String) throw const AuthFailure('identity');
    final identity = await transport.verifyIdentity(
      idToken,
      result.clientId,
      nonce: attempt.nonce,
      expectedSubject: registration?.subject,
      now: now(),
    );
    _stage = AuthStage.tokenSet;
    final session = _readTokens(tokens, identity, idToken);
    _check(epoch);
    final oldRegistration = _registrations[identity.clientId];
    if (oldRegistration != null &&
        oldRegistration.subject != identity.subject) {
      throw const AuthFailure('identity');
    }
    _registrations[identity.clientId] = identity;
    _session = session;
    try {
      await _save();
      _check(epoch);
      _models = [];
      _pendingClientId = null;
    } catch (_) {
      _session = previous;
      if (oldRegistration == null) {
        _registrations.remove(identity.clientId);
      } else {
        _registrations[identity.clientId] = oldRegistration;
      }
      await _save();
      rethrow;
    }
  });

  _Session _readTokens(
    Map<String, dynamic> body,
    AccountInfo identity,
    String idToken, {
    _Session? old,
  }) {
    final access = body['access_token'];
    final expires = body['expires_in'];
    final scopes = body['scope'] is String
        ? (body['scope'] as String)
              .split(' ')
              .where((s) => s.isNotEmpty)
              .toSet()
        : old?.scopes ?? <String>{};
    final refresh = body['refresh_token'];
    if (access is! String ||
        access.isEmpty ||
        access.contains(RegExp(r'[\r\n]')) ||
        body['token_type'] is! String ||
        (body['token_type'] as String).toLowerCase() != 'bearer' ||
        expires is! num ||
        !expires.isFinite ||
        expires <= 0 ||
        expires > 86400 ||
        (scopes.contains('offline_access') &&
            (refresh is! String || refresh.isEmpty))) {
      throw const AuthFailure('protocol');
    }
    return _Session(
      account: identity,
      access: access,
      refresh: refresh is String ? refresh : null,
      idToken: idToken,
      scopes: scopes,
      expires: now().add(Duration(seconds: expires.toInt())),
    );
  }

  Future<String> _access(OpenAiTransport transport, int epoch) async {
    final current = _session;
    if (current == null) throw const AuthFailure('expired');
    if (!inferenceAllowed) throw const AuthFailure('scope');
    if (current.expires.isAfter(now().add(const Duration(seconds: 60)))) {
      return current.access;
    }
    if (current.refresh == null) throw const AuthFailure('expired');
    // A crash or lost response after rotation must never restore and reuse the
    // previous refresh token. Persist a tombstone before sending it. An
    // interrupted refresh deliberately requires fresh interactive sign-in.
    try {
      await vault.write(_snapshot(null, false));
    } catch (_) {
      throw const AuthFailure('storage');
    }
    _session = null;
    _check(epoch);
    _stage = AuthStage.refresh;
    try {
      // _run is the single-operation mutex; refreshes cannot race or share a rotating token.
      final body = await transport.jsonRequest(
        'POST',
        Uri.parse(tokenEndpoint),
        form: {
          'grant_type': 'refresh_token',
          'client_id': current.account.clientId,
          'refresh_token': current.refresh!,
          'resource': resource,
        },
      );
      _check(epoch);
      final returnedId = body['id_token'];
      if (returnedId != null) {
        if (returnedId is! String) throw const AuthFailure('identity');
        await transport.verifyIdentity(
          returnedId,
          current.account.clientId,
          nonce: null,
          expectedSubject: current.account.subject,
          now: now(),
        );
      }
      _check(epoch);
      final next = _readTokens(
        body,
        current.account,
        returnedId is String ? returnedId : current.idToken,
        old: current,
      );
      _session = next;
      // Atomically replace the entire set. A failed write must not reuse the old refresh token.
      try {
        await _save();
      } catch (_) {
        _session = null;
        rethrow;
      }
      _check(epoch);
      if (!inferenceAllowed) throw const AuthFailure('scope');
      return next.access;
    } on AuthFailure catch (error) {
      if (error.code == 'expired') {
        _session = null;
        await _save();
      }
      rethrow;
    }
  }

  @override
  void cancel() {
    _epoch++;
    if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
      _cancelSignal!.complete();
    }
    _client?.close();
    unawaited(_receiver?.close());
  }

  @override
  Future<bool> signOut() async {
    cancel();
    await _work?.future;
    return _run((transport, epoch) async {
      final old = _session;
      _session = null;
      _models = [];
      _pendingClientId = null;
      var revoked = old == null;
      try {
        if (old?.refresh != null) {
          final metadata = await transport.metadata();
          final endpoint = transport.trustedAuthUri(
            metadata['revocation_endpoint'],
          );
          for (var attempt = 0; attempt < 2; attempt++) {
            try {
              await transport.jsonRequest(
                'POST',
                endpoint,
                form: {
                  'token': old!.refresh!,
                  'token_type_hint': 'refresh_token',
                  'client_id': old.account.clientId,
                },
              );
              revoked = true;
              break;
            } on AuthFailure catch (error) {
              if (attempt == 1 || error.status != null && error.status! < 500) {
                break;
              }
              await Future<void>.delayed(const Duration(milliseconds: 500));
            } catch (_) {
              if (attempt == 1) break;
            }
          }
        }
      } catch (_) {
        revoked = false;
      } finally {
        await _save();
      }
      return revoked;
    });
  }

  @override
  Future<List<AvailableModel>> discoverModels() =>
      _run((transport, epoch) async {
        _stage = AuthStage.models;
        final token = await _access(transport, epoch);
        _stage = AuthStage.models;
        final models = await transport.models(token);
        _check(epoch);
        return _models = models;
      });

  @override
  Future<String> probe(String model, void Function(String) onPartial) => _run((
    transport,
    epoch,
  ) async {
    if (!_models.any((m) => m.slug == model)) throw const AuthFailure('models');
    final token = await _access(transport, epoch);
    _stage = AuthStage.response;
    final result = await transport.probe(token, model, (text) {
      if (epoch == _epoch && !_disposed) onPartial(text);
    });
    _check(epoch);
    return result;
  });

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}
