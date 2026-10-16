// Optional local preview, not a golden test or Android device screenshot.
// flutter test tool/preview.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/app/guide_app.dart';

import '../test/tour_test.dart' show controller;

void main() {
  testWidgets('render phone previews', (tester) async {
    const path = String.fromEnvironment('PREVIEW_FONT');
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    if (path.isNotEmpty) {
      final bytes = await tester.runAsync(() => File(path).readAsBytes());
      for (final family in ['Roboto', 'serif']) {
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes!)));
        await tester.runAsync(loader.load);
      }
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = controller();
    await tester.runAsync(c.load);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GuideApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('tour');
    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pumpAndSettle();
    await capture('actions');
    await tester.tap(find.text('Маршрут'));
    await tester.pumpAndSettle();
    await capture('route');
    expect(tester.takeException(), isNull);
  });
}
