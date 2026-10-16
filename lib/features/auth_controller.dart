import 'package:flutter/foundation.dart';

import '../domain/auth.dart';

enum AccountState { disconnected, connecting, connected, error }

class AuthController extends ChangeNotifier {
  AuthController(this.provider);
  final AuthProvider provider;
  AccountState state = AccountState.disconnected;
  bool busy = false;
  bool initialized = false;
  bool completed = false;
  String? message;
  String text = '';
  List<AvailableModel> models = [];
  String? selectedModel;
  bool _disposed = false;
  AccountInfo? get account => provider.account;
  bool get inferenceAllowed => provider.inferenceAllowed;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(Object error) {
    message = error is AuthFailure
        ? error.message
        : const AuthFailure('network').message;
    state = account == null ? AccountState.error : AccountState.connected;
  }

  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    busy = true;
    try {
      await provider.restore();
      state = account == null
          ? AccountState.disconnected
          : AccountState.connected;
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> connect({String? clientId}) async {
    if (busy) return;
    busy = true;
    completed = false;
    text = '';
    message = null;
    models = [];
    selectedModel = null;
    state = AccountState.connecting;
    _notify();
    try {
      await provider.signIn(clientId: clientId);
      state = AccountState.connected;
      if (provider.inferenceAllowed) {
        models = await provider.discoverModels();
        selectedModel = models.first.slug;
      }
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  void cancel() {
    provider.cancel();
    message = 'Отмена…';
    _notify();
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    completed = false;
    text = '';
    models = [];
    selectedModel = null;
    _notify();
    try {
      final revoked = await provider.signOut();
      state = AccountState.disconnected;
      message = revoked ? 'Аккаунт отключён.' : 'Локальный выход выполнен. Отзыв на сервере не подтверждён; отключите приложение в настройках ChatGPT.';
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> loadModels() async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      models = await provider.discoverModels();
      selectedModel = models.first.slug;
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  void selectModel(String? value) {
    selectedModel = value;
    completed = false;
    text = '';
    _notify();
  }

  Future<void> runProbe() async {
    final model = selectedModel;
    if (busy || model == null) return;
    busy = true;
    completed = false;
    text = '';
    message = null;
    _notify();
    try {
      text = await provider.probe(model, (partial) {
        text = partial;
        _notify();
      });
      completed = true;
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    provider.dispose();
    super.dispose();
  }
}
