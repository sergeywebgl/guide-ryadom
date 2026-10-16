import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/auth.dart';
import 'package:guide_ryadom/infrastructure/auth/openai_transport.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String frame(Map<String, dynamic> event) =>
    'data: ${jsonEncode(event)}\r\n\r\n';
Map<String, dynamic> completed({
  String status = 'completed',
  String id = 'r1',
}) => {
  'type': 'response.completed',
  'response': {
    'id': id,
    'status': status,
    'output': [
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Факт о соборе.'},
        ],
      },
    ],
  },
};
Stream<List<int>> chunks(String value) =>
    Stream.fromIterable(utf8.encode(value).map((b) => [b]));

void main() {
  for (final entry in <String, ResponseMedia>{
    '': ResponseMedia.missing,
    'application/json': ResponseMedia.json,
    'application/problem+json; charset=utf-8': ResponseMedia.json,
    'text/html': ResponseMedia.html,
    'text/plain': ResponseMedia.text,
    'application/octet-stream': ResponseMedia.binary,
    'text/event-stream-invalid; secret=TOKEN': ResponseMedia.other,
  }.entries) {
    test('unexpected media ${entry.value.name} is safe and cancels body', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final transport = OpenAiTransport(
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            body.stream,
            200,
            headers: {if (entry.key.isNotEmpty) 'content-type': entry.key},
          ),
        ),
      );
      // Even completed-looking JSON or SSE must not bypass the format check.
      body.add(utf8.encode(jsonEncode(completed())));
      try {
        await transport.probe(
          'mock',
          'model',
          (_) => fail('No partial expected'),
        );
        fail('Unexpected format must fail');
      } on AuthFailure catch (error) {
        final failure = error.atStage(AuthStage.response);
        expect(failure.code, 'response_format');
        expect(failure.status, 200);
        expect(failure.media, entry.value);
        expect(
          failure.diagnostic,
          'M1.4 / response / response_format / HTTP 200 / media=${entry.value.name}',
        );
        expect(failure.diagnostic, isNot(contains('TOKEN')));
        expect(cancelled, isTrue);
      } finally {
        await body.close();
      }
    });
  }

  test('valid MIME type is case insensitive and permits parameters', () async {
    final transport = OpenAiTransport(
      MockClient(
        (_) async => http.Response(
          frame(completed()),
          200,
          headers: {'content-type': 'Text/Event-Stream; charset=utf-8'},
        ),
      ),
    );
    expect(await transport.probe('mock', 'model', (_) {}), 'Факт о соборе.');
  });

  test('SSE byte boundaries, UTF8, comments and multiline data; completed text authoritative', () async {
    final partials = <String>[];
    final data =
        ': keepalive\n\nevent: response.created\n${frame({
          'type': 'response.created',
          'response': {'id': 'r1'},
        })}'
        '${frame({'type': 'response.output_text.delta', 'delta': 'Факт'})}'
        'data: {"type":"unknown",\ndata: "value":1}\n\n'
        '${frame(completed())}';
    expect(
      await parseResponseStream(chunks(data), partials.add),
      'Факт о соборе.',
    );
    expect(partials, ['Факт']);
  });

  for (final ending in [
    '',
    'data: [DONE]\n\n',
    'data: not-json\n\n',
    frame({'type': 'response.failed'}),
    frame({'type': 'response.incomplete'}),
    frame({'type': 'error'}),
    frame(completed(status: 'in_progress')),
    frame(completed(id: 'different')),
  ]) {
    test('partial text never succeeds without valid completion: $ending', () async {
      final data =
          '${frame({
            'type': 'response.created',
            'response': {'id': 'r1'},
          })}'
          '${frame({'type': 'response.output_text.delta', 'delta': 'partial'})}$ending';
      await expectLater(
        parseResponseStream(chunks(data), (_) {}),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'stream')),
      );
    });
  }

  test(
    'response request uses public endpoint and only supported fields',
    () async {
      final transport = OpenAiTransport(
        MockClient((r) async {
          expect(r.url.toString(), 'https://api.openai.com/v1/responses');
          expect(r.followRedirects, isFalse);
          expect(r.headers['Authorization'], 'Bearer mock-token');
          expect(jsonDecode(r.body), {
            'model': 'discovered-model',
            'stream': true,
            'store': false,
            'input': [
              {'role': 'user', 'content': diagnosticPrompt},
            ],
          });
          return http.Response(
            frame(completed()),
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      expect(
        await transport.probe('mock-token', 'discovered-model', (_) {}),
        'Факт о соборе.',
      );
    },
  );

  for (final entry in {
    401: 'expired',
    403: 'forbidden',
    429: 'quota',
    500: 'network',
    302: 'network',
  }.entries) {
    test('HTTP ${entry.key} is safe and never exposes server body', () async {
      final transport = OpenAiTransport(
        MockClient((r) async => http.Response('SECRET TOKEN', entry.key)),
      );
      try {
        await transport.probe('mock', 'model', (_) {});
        fail('Must reject HTTP error');
      } on AuthFailure catch (e) {
        expect(e.code, entry.value);
        expect(e.toString(), isNot(contains('SECRET')));
      }
    });
  }

  test('quota SSE failure and empty model eligibility', () async {
    await expectLater(
      parseResponseStream(
        chunks(
          frame({
            'type': 'response.failed',
            'response': {
              'error': {'code': 'subscription_sharing_usage_limit_exceeded'},
            },
          }),
        ),
        (_) {},
      ),
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'quota')),
    );
    final transport = OpenAiTransport(
      MockClient((r) async => http.Response('{"models":[]}', 200)),
    );
    await expectLater(
      transport.models('mock'),
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'models')),
    );
  });
}
