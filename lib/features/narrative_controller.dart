import 'package:flutter/foundation.dart';

import '../domain/auth.dart';
import '../domain/narrative.dart';
import '../domain/probe_trace.dart';
import 'auth_controller.dart';

class NarrativeController extends ChangeNotifier {
  NarrativeController(this.auth) {
    _account = auth.account;
    auth.addListener(_accountChanged);
  }
  final AuthController auth;
  AccountInfo? _account;
  final List<NarrativeSegment> history = [];
  final Set<String> consumed = {};
  bool busy = false, _disposed = false;
  int received = 0, _epoch = 0;
  String? error;
  ProbeTrace? trace;
  bool available(NarrativeAction action) =>
      NarrativeRequest(action, consumed).selected.isNotEmpty;

  void _accountChanged() {
    if (_account?.subject == auth.account?.subject &&
        _account?.clientId == auth.account?.clientId) {
      return;
    }
    _account = auth.account;
    _epoch++;
    if (busy) auth.provider.cancel();
    busy = false;
    history.clear();
    consumed.clear();
    trace = null;
    error = null;
    received = 0;
    if (!_disposed) notifyListeners();
  }

  Future<void> generate(NarrativeAction action) async {
    if (busy || auth.busy || !available(action)) return;
    final provider = auth.provider;
    final model = auth.selectedModel;
    if (provider is! NarrativeProviderV1 ||
        model == null ||
        !auth.inferenceAllowed) {
      error = 'Подключите ChatGPT и выберите модель в настройках.';
      notifyListeners();
      return;
    }
    final request = NarrativeRequest(action, consumed);
    final epoch = ++_epoch;
    busy = true;
    error = null;
    received = 0;
    trace = ProbeTrace()
      ..note('narrative_v1 action=${action.name} evidence=$evidenceRevision');
    notifyListeners();
    try {
      final raw = await (provider as NarrativeProviderV1).generate(
        model,
        request.prompt,
        (partial) {
          if (!_disposed && epoch == _epoch) {
            received = partial.length;
            notifyListeners();
          }
        },
        trace: trace,
      );
      if (_disposed || epoch != _epoch) return;
      final segment = NarrativeSegment.parse(raw, request);
      history.add(segment);
      consumed.addAll(segment.claimIds);
      trace?.note('narrative_validated claims=${segment.claimIds.length}');
    } catch (e) {
      if (_disposed || epoch != _epoch) return;
      error = e is AuthFailure ? e.message : 'Ответ не прошёл проверку структуры и источников. Можно повторить запрос.';
      trace?.note(
        e is AuthFailure
            ? e.diagnostic
            : e is NarrativeValidationFailure
            ? 'narrative_validation_failed reason=${e.code}'
            : 'narrative_internal_failure',
      );
    } finally {
      if (!_disposed && epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    if (!busy) return;
    _epoch++;
    auth.provider.cancel();
    busy = false;
    error = 'Запрос отменён. История не изменилась.';
    trace?.note('narrative_cancelled');
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    if (busy) auth.provider.cancel();
    auth.removeListener(_accountChanged);
    super.dispose();
  }
}
