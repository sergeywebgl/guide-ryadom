import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/app/guide_app.dart';

import 'tour_test.dart' show controller;

void main() {
  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('offline tour controls, sources and fallback explanations', (
    tester,
  ) async {
    final c = controller();
    await tester.runAsync(c.load);
    await tester.pumpWidget(GuideApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Демо: Питерборо'), findsOneWidget);
    await tap(tester, 'Подробнее');
    expect(c.engine!.segment.id, 'facade.detail');
    await tap(tester, 'Удиви меня');
    expect(c.engine!.segment.id, 'facade.surprise');
    await tap(tester, 'Что это?');
    expect(c.notice, contains('M4'));
    await tap(tester, 'Слушать · скоро');
    expect(c.notice, contains('звук не воспроизводится'));
    await tap(tester, 'Источники');
    expect(find.text('Peterborough Cathedral — History'), findsOneWidget);
    await tap(tester, 'Идём дальше');
    expect(c.engine!.index, 1);
    await tap(tester, 'Назад');
    expect(c.engine!.index, 0);
    await tap(tester, 'Пропустить остановку');
    expect(c.engine!.skippedStops, contains('facade'));
    await tester.tap(find.text('Маршрут'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Схема демо'), findsOneWidget);
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ChatGPT не подключён'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px phone with 200% text has no overflows on all tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = controller();
    await tester.runAsync(c.load);
    await tester.pumpWidget(GuideApp(controller: c));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    for (final tab in ['Маршрут', 'Настройки']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
