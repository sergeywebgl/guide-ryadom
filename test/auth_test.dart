import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/auth.dart';
import 'package:guide_ryadom/infrastructure/auth/auth_service.dart';
import 'package:guide_ryadom/infrastructure/auth/oauth_contract.dart';
import 'package:guide_ryadom/infrastructure/auth/openai_transport.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';

final epoch = DateTime.utc(2026, 10, 16);
Matcher fails(String code) =>
    throwsA(isA<AuthFailure>().having((e) => e.code, 'code', code));
const metadata = {
  'issuer': issuer,
  'authorization_endpoint': authorizeEndpoint,
  'token_endpoint': tokenEndpoint,
  'jwks_uri': '$issuer/.well-known/jwks.json',
  'revocation_endpoint': '$issuer/api/accounts/oauth/revoke',
  'id_token_signing_alg_values_supported': ['RS256'],
};

class MemoryVault implements AuthVault {
  String? value;
  bool rejectSessionWrites = false;
  @override
  Future<String> hostId() async =>
      'urn:uuid:00000000-0000-4000-8000-000000000001';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (rejectSessionWrites && jsonDecode(value)['session'] != null) {
      throw StateError('simulated storage failure');
    }
    this.value = value;
  }
}

class Receiver implements CallbackReceiver {
  final result = Completer<Uri>();
  bool closed = false;
  final redirect = Uri.parse('http://127.0.0.1:43210/auth/callback');
  @override
  Future<Uri> start() async => redirect;
  @override
  Future<Uri> get callback => result.future;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class Browser implements SystemBrowser {
  Browser(this.onOpen);
  final void Function(Uri) onOpen;
  @override
  Future<void> open(Uri uri) async => onOpen(uri);
}

class Harness {
  Harness(
    this.key, {
    this.autoCallback = true,
    this.timeout = const Duration(seconds: 2),
  }) {
    service = ChatGptAuthService(
      vault: vault,
      browser: Browser((uri) {
        authorization = uri;
        if (!opened.isCompleted) opened.complete();
        if (autoCallback) {
          receiver.result.complete(
            receiver.redirect.replace(
              queryParameters: {
                'state': uri.queryParameters['state']!,
                'code': 'mock-code',
                'client_id': 'issued-client',
              },
            ),
          );
        }
      }),
      receiverFactory: () => receiver = Receiver(),
      clientFactory: () => MockClient(handle),
      now: () => clock,
      loginTimeout: timeout,
    );
  }
  final JsonWebKey key;
  final bool autoCallback;
  final Duration timeout;
  final vault = MemoryVault();
  final opened = Completer<void>();
  late ChatGptAuthService service;
  late Receiver receiver;
  late Uri authorization;
  DateTime clock = epoch;
  Map<String, dynamic> claimOverrides = {};
  Map<String, dynamic> tokenOverrides = {};
  String scope = requestedScopes;
  int exchangeStatus = 200;
  int revokeStatus = 200;
  final requests = <http.Request>[];
  int refreshes = 0;

  String signed([Map<String, dynamic> overrides = const {}]) {
    final builder = JsonWebSignatureBuilder()
      ..jsonContent = {
        'iss': issuer,
        'aud': 'issued-client',
        'sub': 'mock-subject',
        'email': 'owner@example.invalid',
        'iat': clock.millisecondsSinceEpoch ~/ 1000,
        'exp': clock.millisecondsSinceEpoch ~/ 1000 + 3600,
        'nonce': authorization.queryParameters['nonce'],
        ...overrides,
      }
      ..setProtectedHeader('kid', 'test-key')
      ..addRecipient(key, algorithm: 'RS256');
    return builder.build().toCompactSerialization();
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    Object body = {};
    var status = 200;
    if (request.url.path.endsWith('openid-configuration')) {
      body = metadata;
    } else if (request.url.path.endsWith('jwks.json')) {
      final raw = key.toJson();
      body = {
        'keys': [
          {
            'kty': 'RSA',
            'kid': 'test-key',
            'n': raw['n'],
            'e': raw['e'],
            'alg': 'RS256',
          },
        ],
      };
    } else if (request.url.path.endsWith('/token')) {
      final refresh = request.bodyFields['grant_type'] == 'refresh_token';
      if (refresh) refreshes++;
      status = exchangeStatus;
      body = status == 200
          ? {
              'access_token': 'mock-access-$refreshes',
              'refresh_token': 'mock-refresh-$refreshes',
              'token_type': 'Bearer',
              'expires_in': 3600,
              if (!refresh) 'scope': scope,
              'id_token': signed(claimOverrides),
              ...tokenOverrides,
            }
          : {
              'error': 'invalid_grant',
              'error_description': 'SECRET MUST NOT LEAK',
            };
    } else if (request.url.path.endsWith('/revoke')) {
      return http.Response('', revokeStatus);
    } else if (request.url.path.endsWith('/models')) {
      body = {
        'models': [
          {'slug': 'hidden', 'display_name': 'Hidden', 'visibility': 'hide'},
          {
            'slug': 'available',
            'display_name': 'Available',
            'visibility': 'list',
          },
        ],
      };
    } else {
      throw StateError('Unexpected mock endpoint');
    }
    return http.Response(jsonEncode(body), status);
  }
}

void main() {
  late JsonWebKey key;
  setUpAll(() {
    final generated = JsonWebKey.generate('RS256', keyBitLength: 2048);
    key = JsonWebKey.fromJson({...generated.toJson(), 'kid': 'test-key'});
  });

  for (final invalid in <Map<String, dynamic>>[
    {'access_token': ''},
    {'token_type': 'Basic'},
    {'expires_in': -1},
    {'refresh_token': null},
    {'id_token': null},
  ]) {
    test('reject unusable token response $invalid', () async {
      final h = Harness(key)..tokenOverrides = invalid;
      addTearDown(h.service.dispose);
      await expectLater(h.service.signIn(), throwsA(isA<AuthFailure>()));
      expect(h.service.account, isNull);
      expect(h.vault.value, isNull);
    });
  }

  test(
    'failed rotated token persistence leaves no old token on disk',
    () async {
      final h = Harness(key);
      addTearDown(h.service.dispose);
      await h.service.signIn();
      h.clock = h.clock.add(const Duration(hours: 2));
      h.vault.rejectSessionWrites = true;
      await expectLater(h.service.discoverModels(), fails('storage'));
      expect(h.service.account, isNull);
      expect(jsonDecode(h.vault.value!)['session'], isNull);
      expect(h.refreshes, 1);
      await expectLater(h.service.discoverModels(), fails('expired'));
      expect(h.refreshes, 1);
    },
  );

  test('separate installations have no shared account state', () async {
    final first = Harness(key);
    final second = Harness(key)
      ..claimOverrides = {
        'sub': 'second-subject',
        'email': 'second@example.invalid',
      };
    addTearDown(first.service.dispose);
    addTearDown(second.service.dispose);
    await first.service.signIn();
    expect(second.service.account, isNull);
    await second.service.signIn();
    await first.service.signOut();
    expect(second.service.account!.subject, 'second-subject');
    await second.service.restore();
    expect(second.service.account!.email, 'second@example.invalid');
  });

  test('PKCE RFC7636 vector and independent secure attempt values', () {
    expect(
      pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
    final values = List.generate(20, (_) => secureValue());
    expect(values.toSet(), hasLength(20));
    expect(
      values.every((v) => RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(v)),
      isTrue,
    );
    final a = OAuthAttempt(
      redirect: Uri.parse('http://127.0.0.1:1/auth/callback'),
      hostId: 'host',
    );
    expect(a.verifier.length, inInclusiveRange(43, 128));
    expect(
      a.authorizationUri.queryParameters['client_id'],
      'dynamic_agent_client',
    );
    expect(a.authorizationUri.queryParameters['code_challenge_method'], 'S256');
    expect(a.state, isNot(a.nonce));
  });

  test(
    'callback rejects wrong origin, state, duplicates and client mapping',
    () {
      final a = OAuthAttempt(
        redirect: Uri.parse('http://127.0.0.1:1234/auth/callback'),
        hostId: 'host',
        state: 'expected',
      );
      final good = a.redirect.replace(
        queryParameters: {
          'state': 'expected',
          'code': 'code',
          'client_id': 'issued',
        },
      );
      expect(a.validateCallback(good).clientId, 'issued');
      for (final bad in [
        good.replace(host: 'localhost'),
        good.replace(port: 1235),
        good.replace(path: '/other'),
        good.replace(fragment: 'x'),
        Uri.parse('$good&state=expected'),
        good.replace(query: 'state=wrong&error=access_denied'),
      ]) {
        expect(() => a.validateCallback(bad), fails('state'));
      }
      expect(
        () => a.validateCallback(good.replace(query: 'state=expected&code=c')),
        fails('client'),
      );
      expect(
        () => a.validateCallback(
          good.replace(query: 'state=expected&error=access_denied'),
        ),
        fails('denied'),
      );
      final returning = OAuthAttempt(
        redirect: a.redirect,
        hostId: 'host',
        savedClientId: 'saved',
        state: 'expected',
      );
      expect(
        returning
            .validateCallback(good.replace(query: 'state=expected&code=c'))
            .clientId,
        'saved',
      );
      expect(() => returning.validateCallback(good), fails('client'));
    },
  );

  test('full mocked sign in, issued client exchange, models, refresh rotation, logout', () async {
    final h = Harness(key);
    addTearDown(h.service.dispose);
    await h.service.restore();
    await h.service.signIn();
    expect(h.service.account!.email, 'owner@example.invalid');
    expect(h.service.inferenceAllowed, isTrue);
    final tokenRequest = h.requests.firstWhere(
      (r) => r.url.path.endsWith('/token'),
    );
    expect(tokenRequest.bodyFields['client_id'], 'issued-client');
    expect(
      tokenRequest.bodyFields['redirect_uri'],
      h.receiver.redirect.toString(),
    );
    expect(
      pkceChallenge(tokenRequest.bodyFields['code_verifier']!),
      h.authorization.queryParameters['code_challenge'],
    );
    expect((await h.service.discoverModels()).single.slug, 'available');
    for (var i = 0; i < 2; i++) {
      h.clock = h.clock.add(const Duration(hours: 2));
      await h.service.discoverModels();
    }
    final refreshes = h.requests
        .where(
          (r) =>
              r.url.path.endsWith('/token') &&
              r.bodyFields['grant_type'] == 'refresh_token',
        )
        .toList();
    expect(refreshes.map((r) => r.bodyFields['refresh_token']), [
      'mock-refresh-0',
      'mock-refresh-1',
    ]);
    expect(refreshes.every((r) => !r.bodyFields.containsKey('scope')), isTrue);
    expect(await h.service.signOut(), isTrue);
    expect(h.service.account, isNull);
    expect(h.vault.value, isNot(contains('mock-access')));
    expect(h.vault.value, isNot(contains('mock-refresh')));
    expect(h.service.registrations, hasLength(1));
    await h.service.signIn(clientId: 'issued-client');
    expect(
      h.authorization.queryParameters.containsKey('id_token_hint'),
      isFalse,
    );
    expect(
      h.authorization.queryParameters.containsKey('agent_name_hint'),
      isFalse,
    );
  });

  for (final claims in <Map<String, dynamic>>[
    {'nonce': 'wrong'},
    {'iss': 'https://evil.invalid'},
    {'aud': 'other'},
    {'exp': 1},
    {'iat': 9999999999},
    {'sub': ''},
    {
      'aud': ['issued-client', 'other'],
    },
  ]) {
    test('reject invalid signed claims $claims', () async {
      final h = Harness(key)..claimOverrides = claims;
      addTearDown(h.service.dispose);
      await expectLater(h.service.signIn(), fails('identity'));
      expect(h.service.account, isNull);
      expect(h.vault.value, isNull);
    });
  }

  test('signature tampering rejected even with valid claims', () async {
    final h = Harness(key);
    addTearDown(h.service.dispose);
    await h.service.signIn();
    final jwt = h.signed().split('.');
    jwt[2] = '${jwt[2][0] == 'A' ? 'B' : 'A'}${jwt[2].substring(1)}';
    final transport = OpenAiTransport(MockClient(h.handle));
    await expectLater(
      transport.verifyIdentity(
        jwt.join('.'),
        'issued-client',
        nonce: h.authorization.queryParameters['nonce'],
        now: epoch,
      ),
      fails('identity'),
    );
  });

  test(
    'token exchange failure retains issued ID for fresh auth, never code',
    () async {
      final h = Harness(key)..exchangeStatus = 400;
      addTearDown(h.service.dispose);
      await expectLater(h.service.signIn(), fails('expired'));
      expect(h.service.account, isNull);
      h.exchangeStatus = 200;
      await h.service.signIn();
      expect(h.authorization.queryParameters['client_id'], 'issued-client');
      expect(h.authorization.queryParameters.containsKey('code'), isFalse);
    },
  );

  test('cancellation closes listener and cannot save a session', () async {
    final h = Harness(key, autoCallback: false);
    addTearDown(h.service.dispose);
    final pending = h.service.signIn();
    final expectation = expectLater(pending, fails('cancelled'));
    await h.opened.future;
    h.service.cancel();
    await expectation;
    expect(h.receiver.closed, isTrue);
    expect(h.service.account, isNull);
    expect(h.vault.value, isNull);
  });

  test(
    'returning without callback times out; concurrent requests are serialized',
    () async {
      final h = Harness(
        key,
        autoCallback: false,
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(h.service.dispose);
      final pending = expectLater(h.service.signIn(), fails('timeout'));
      await h.opened.future;
      await expectLater(h.service.signIn(), fails('busy'));
      await pending;
      expect(h.receiver.closed, isTrue);
    },
  );

  test('no direct scope prevents inference; failed revocation still clears session', () async {
    final h = Harness(key)
      ..scope = 'openid profile email offline_access'
      ..revokeStatus = 400;
    addTearDown(h.service.dispose);
    await h.service.signIn();
    expect(h.service.inferenceAllowed, isFalse);
    await expectLater(h.service.discoverModels(), fails('scope'));
    expect(await h.service.signOut(), isFalse);
    expect(jsonDecode(h.vault.value!)['session'], isNull);
  });

  test(
    'invalidated refresh clears credentials and requires fresh sign in',
    () async {
      final h = Harness(key);
      addTearDown(h.service.dispose);
      await h.service.signIn();
      h.clock = h.clock.add(const Duration(hours: 2));
      h.exchangeStatus = 400;
      await expectLater(h.service.discoverModels(), fails('expired'));
      expect(h.service.account, isNull);
      expect(jsonDecode(h.vault.value!)['session'], isNull);
    },
  );
}
