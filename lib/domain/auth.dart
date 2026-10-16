class AccountInfo {
  const AccountInfo({
    required this.clientId,
    required this.subject,
    this.email,
  });
  final String clientId;
  final String subject;
  final String? email;
  String get label =>
      '${email ?? 'Аккаунт ChatGPT'} · ${clientId.substring(clientId.length > 6 ? clientId.length - 6 : 0)}';
}

class AvailableModel {
  const AvailableModel(this.slug, this.name);
  final String slug;
  final String name;
}

abstract interface class AuthProvider {
  AccountInfo? get account;
  List<AccountInfo> get registrations;
  bool get inferenceAllowed;
  Future<void> restore();
  Future<void> signIn({String? clientId});
  void cancel();

  /// True only if remote revocation was confirmed (or there was no session).
  Future<bool> signOut();
  Future<List<AvailableModel>> discoverModels();
  Future<String> probe(String model, void Function(String) onPartial);
  void dispose();
}

/// Safe, closed vocabulary. Never include provider bodies, URLs or token values.
class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.status});
  final String code;
  final int? status;
  String get message => switch (code) {
    'cancelled' => 'Вход или запрос отменён.',
    'denied' => 'Вход или разрешение отклонено в браузере.',
    'timeout' =>
      'Время ожидания истекло. Вернитесь в приложение и начните снова.',
    'state' => 'Ответ браузера не соответствует попытке входа. Начните снова.',
    'identity' => 'Не удалось подтвердить подпись или данные аккаунта.',
    'client' => 'Регистрация клиента не подтверждена. Повторите вход.',
    'scope' =>
      'Аккаунт подключён, но использование плана ChatGPT не разрешено.',
    'expired' => 'Сессия истекла или отозвана. Войдите снова.',
    'quota' => 'Достигнут лимит ChatGPT. Проверьте Usage в настройках ChatGPT.',
    'forbidden' =>
      'Доступ запрещён для этого аккаунта, региона или интеграции.',
    'stream' => 'Поток завершился без подтверждённого полного ответа.',
    'models' => 'Нет доступных моделей для проверки.',
    'storage' => 'Защищённое хранилище недоступно. Переподключите аккаунт.',
    'browser' => 'Не удалось открыть системный браузер.',
    'loopback' => 'Не удалось запустить официальный локальный callback.',
    'busy' => 'Дождитесь завершения текущей операции.',
    'protocol' => 'Ответ сервиса не соответствует официальному контракту.',
    _ =>
      'Сетевая ошибка${status == null ? '' : ' (HTTP $status)'}. Повторите позже.',
  };
  @override
  String toString() =>
      'AuthFailure($code${status == null ? '' : ', HTTP $status'})';
}
