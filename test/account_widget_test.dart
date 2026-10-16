import 'package:guide_ryadom/domain/probe_trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/auth.dart';
import 'package:guide_ryadom/features/account_section.dart';
import 'package:guide_ryadom/features/auth_controller.dart';

class FakeAuth implements AuthProvider {
  @override
  AccountInfo? account;
  bool failProbe = false;
  @override
  List<AccountInfo> get registrations => [];
  @override
  bool get inferenceAllowed => account != null;
  @override
  Future<void> restore() async {}
  @override
  Future<void> signIn({String? clientId}) async {
    account = const AccountInfo(
      clientId: 'client',
      subject: 'subject',
      email: 'test@example.invalid',
    );
  }

  @override
  Future<bool> signOut() async {
    account = null;
    return true;
  }

  @override
  Future<List<AvailableModel>> discoverModels() async => [
    const AvailableModel('model', 'Доступная модель'),
  ];
  @override
  Future<String> probe(
    String model,
    void Function(String) onPartial, {
    ProbeTrace? trace,
  }) async {
    onPartial('Часть ответа');
    if (failProbe) throw const AuthFailure('stream', stage: AuthStage.response);
    return 'Полный ответ';
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  testWidgets('account UI sign in, completed/failed diagnostics and logout', (
    tester,
  ) async {
    final provider = FakeAuth();
    final c = AuthController(provider);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AccountSection(controller: c)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Не подключён'), findsOneWidget);
    await tester.tap(find.text('Подключить ChatGPT'));
    await tester.pumpAndSettle();
    expect(find.text('Подключён'), findsOneWidget);
    expect(find.textContaining('test@example.invalid'), findsOneWidget);
    await tester.ensureVisible(find.text('Отправить тестовый запрос'));
    await tester.tap(find.text('Отправить тестовый запрос'));
    await tester.pumpAndSettle();
    expect(find.text('Ответ завершён · response.completed'), findsOneWidget);
    provider.failProbe = true;
    await tester.tap(find.text('Отправить тестовый запрос'));
    await tester.pumpAndSettle();
    expect(find.text('Ответ завершён · response.completed'), findsNothing);
    expect(find.text('Частичный ответ — успех не подтверждён'), findsOneWidget);
    expect(find.text('Этап: Получение ответа GPT'), findsOneWidget);
    expect(find.text('Диагностика: M1.6 / response / stream'), findsOneWidget);
    expect(find.text('Копировать код ошибки'), findsOneWidget);
    expect(find.text('Копировать весь отчёт'), findsOneWidget);
    expect(c.trace!.report, contains('UI completed=false'));
    await tester.ensureVisible(find.text('Отключить аккаунт'));
    await tester.tap(find.text('Отключить аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Не подключён'), findsOneWidget);
    expect(find.text('Подключить ChatGPT'), findsOneWidget);
    expect(find.text('Часть ответа'), findsNothing);
    expect(find.text('Копировать код ошибки'), findsNothing);
    expect(find.text('Копировать весь отчёт'), findsNothing);
    expect(c.trace, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account section fits 320px phone with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = AuthController(FakeAuth());
    addTearDown(c.dispose);
    await c.initialize();
    await c.connect();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AccountSection(controller: c)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
