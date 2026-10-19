import 'dart:convert';

/// Memory-only, bounded structural diagnostics. Never records payload text,
/// credentials, arbitrary header values, IDs or provider error messages.
class ProbeTrace {
  final _clock = Stopwatch()..start();
  final started = DateTime.now().toUtc();
  final _first = <String>[];
  final _last = <String>[];
  final counts = <String, int>{};
  int bytes = 0, chunks = 0, events = 0;

  void note(String safeDetail) {
    final line = '${_clock.elapsedMilliseconds}ms $safeDetail';
    if (_first.length < 10) {
      _first.add(line);
    } else {
      _last.add(line);
      if (_last.length > 50) _last.removeAt(0);
    }
  }

  void chunk(int length) {
    bytes += length;
    chunks++;
    if (chunks == 1) note('first_body_chunk bytes=$length');
  }

  static String label(dynamic value, Set<String> allowed) => value == null
      ? 'missing'
      : allowed.contains(value)
      ? value as String
      : 'other';

  void event(Map<String, dynamic> event) {
    events++;
    final type = label(event['type'], {
      'response.created',
      'response.queued',
      'response.in_progress',
      'response.output_item.added',
      'response.output_item.done',
      'response.content_part.added',
      'response.content_part.done',
      'response.output_text.delta',
      'response.output_text.done',
      'response.reasoning_summary_part.added',
      'response.reasoning_summary_part.done',
      'response.reasoning_summary_text.delta',
      'response.reasoning_summary_text.done',
      'response.completed',
      'response.failed',
      'response.incomplete',
      'error',
    });
    counts[type] = (counts[type] ?? 0) + 1;
    final r = event['response'];
    final error = r is Map ? r['error'] : event['error'];
    final output = r is Map ? r['output'] : null;
    final shape = <String, dynamic>{
      'type': type,
      'response_object': r is Map,
      if (r is Map) ...{
        'id_string': r['id'] is String,
        'status': label(r['status'], {
          'completed',
          'failed',
          'incomplete',
          'in_progress',
          'queued',
          'cancelled',
        }),
        'output_list': output is List,
        'output_count': output is List ? output.length : null,
        'incomplete_reason': label(
          r['incomplete_details'] is Map
              ? r['incomplete_details']['reason']
              : null,
          {'max_output_tokens', 'content_filter'},
        ),
      },
      if (output is List)
        'output_shapes': output
            .take(8)
            .map(
              (o) => o is Map
                  ? {
                      'type': label(o['type'], {
                        'message',
                        'reasoning',
                        'function_call',
                        'web_search_call',
                      }),
                      'role': label(o['role'], {
                        'assistant',
                        'user',
                        'system',
                        'developer',
                      }),
                      'content_list': o['content'] is List,
                      if (o['content'] is List)
                        'content': (o['content'] as List)
                            .take(8)
                            .map(
                              (c) => c is Map
                                  ? {
                                      'type': label(c['type'], {
                                        'output_text',
                                        'refusal',
                                      }),
                                      'text_string': c['text'] is String,
                                      'text_length': c['text'] is String
                                          ? (c['text'] as String).length
                                          : null,
                                    }
                                  : {'object': false},
                            )
                            .toList(),
                    }
                  : {'object': false},
            )
            .toList(),
      'error_present': error != null,
      if (error != null)
        'error_code': label(error is Map ? error['code'] : null, {
          'subscription_sharing_usage_limit_exceeded',
          'subscription_sharing_usage_unavailable',
          'rate_limit_exceeded',
          'server_error',
          'invalid_request_error',
          'model_not_found',
        }),
    };
    note('event#$events ${jsonEncode(shape)}');
  }

  String get report => [
    'Guide Ryadom M2.0 / diagnostic schema 1',
    'UTC $started',
    'POST https://api.openai.com/v1/responses',
    'OAuth bearer omitted; stream=true store=false input=user/text',
    'Limits: headers=25s idle=25s total=90s parser=512Ki characters',
    'bytes=$bytes chunks=$chunks events=$events counts=${jsonEncode(counts)}',
    ..._first,
    if (events > 60) '[middle history omitted; counts include all events]',
    ..._last,
    'No tokens, account IDs, raw headers, bodies or generated text included.',
  ].join('\n');
}
