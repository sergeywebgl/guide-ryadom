import 'probe_trace.dart';

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
  Future<String> probe(
    String model,
    void Function(String) onPartial, {
    ProbeTrace? trace,
  });
  void dispose();
}

/// Safe, closed vocabulary. Never include provider bodies, URLs or token values.
enum AuthStage {
  restore,
  host,
  metadata,
  listener,
  browser,
  callback,
  foreground,
  exchange,
  identity,
  jwks,
  tokenSet,
  storage,
  refresh,
  models,
  response,
  cleanup,
}

enum AuthCause {
  socket,
  tls,
  httpClient,
  timeout,
  format,
  state,
  type,
  platform,
  unknown,
}

enum ResponseMedia { missing, json, html, text, binary, other }

class AuthFailure implements Exception {
  const AuthFailure(
    this.code, {
    this.status,
    this.stage,
    this.cause,
    this.osError,
    this.media,
  });
  final String code;
  final int? status;
  final AuthStage? stage;
  final AuthCause? cause;
  final int? osError;
  final ResponseMedia? media;
  AuthFailure atStage(AuthStage value) => AuthFailure(
    code,
    status: status,
    stage: stage ?? value,
    cause: cause,
    osError: osError,
    media: media,
  );
  String get diagnostic =>
      'M1.6 / ${stage?.name ?? 'unknown'} / $code${cause == null ? '' : ' / ${cause!.name}'}${status == null ? '' : ' / HTTP $status'}${osError == null ? '' : ' / os=$osError'}${media == null ? '' : ' / media=${media!.name}'}';
  String? get stageLabel => switch (stage) {
    AuthStage.restore => 'Чтение сохранённой сессии',
    AuthStage.host => 'Подготовка установки',
    AuthStage.metadata => 'Загрузка настроек OpenAI',
    AuthStage.listener => 'Запуск локального callback',
    AuthStage.browser => 'Открытие браузера',
    AuthStage.callback => 'Получение и проверка ответа браузера',
    AuthStage.foreground => 'Ожидание возврата в приложение',
    AuthStage.exchange => 'Обмен кода на токены',
    AuthStage.identity => 'Проверка аккаунта и подписи',
    AuthStage.jwks => 'Загрузка ключей проверки подписи',
    AuthStage.tokenSet => 'Проверка набора токенов',
    AuthStage.storage => 'Сохранение защищённой сессии',
    AuthStage.refresh => 'Обновление сессии',
    AuthStage.models => 'Загрузка доступных моделей',
    AuthStage.response => 'Получение ответа GPT',
    AuthStage.cleanup => 'Закрытие локального callback',
    null => null,
  };
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
    'stream_empty' => 'Сервис вернул пустой ответ. Ответ GPT не получен.',
    'stream_no_events' => 'В ответе сервиса нет событий потока GPT.',
    'models' => 'Нет доступных моделей для проверки.',
    'storage' => 'Защищённое хранилище недоступно. Переподключите аккаунт.',
    'browser' => 'Не удалось открыть системный браузер.',
    'loopback' => 'Не удалось запустить официальный локальный callback.',
    'busy' => 'Дождитесь завершения текущей операции.',
    'protocol' => 'Ответ сервиса не соответствует официальному контракту.',
    'response_format' => 'Сервис вернул неожиданный формат вместо потока GPT. Передайте код диагностики разработчику.',
    'internal' =>
      'Внутренняя ошибка приложения. Передайте код диагностики разработчику.',
    'tls' => 'Не удалось установить защищённое соединение с OpenAI.',
    _ =>
      'Сетевая ошибка${status == null ? '' : ' (HTTP $status)'}. Повторите позже.',
  };
  @override
  String toString() =>
      'AuthFailure($code${status == null ? '' : ', HTTP $status'})';
}
