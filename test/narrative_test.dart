import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/auth.dart';
import 'package:guide_ryadom/domain/narrative.dart';
import 'package:guide_ryadom/domain/probe_trace.dart';
import 'package:guide_ryadom/features/auth_controller.dart';
import 'package:guide_ryadom/features/narrative_controller.dart';
import 'package:guide_ryadom/features/narrative_page.dart';

Map<String, dynamic> answer(NarrativeAction action) {
  final r = NarrativeRequest(action, {});
  return {
    'version': 1,
    'text': 'Рассказ о соборе.',
    'claimIds': r.selected.map((c) => c.id).toList(),
    'sourceIds': r.selected.map((c) => c.source).toSet().toList(),
  };
}

class FakeNarrator implements AuthProvider, NarrativeProviderV1 {
  @override
  AccountInfo? account = const AccountInfo(
    clientId: 'client',
    subject: 'person',
  );
  @override
  List<AccountInfo> get registrations => [];
  @override
  bool get inferenceAllowed => account != null;
  @override
  Future<void> restore() async {}
  @override
  Future<void> signIn({String? clientId}) async {}
  @override
  Future<bool> signOut() async {
    account = null;
    return true;
  }

  @override
  Future<List<AvailableModel>> discoverModels() async => [
    const AvailableModel('model', 'Модель'),
  ];
  int requests = 0, cancels = 0;
  String? prompt;
  Completer<String>? pending;
  bool invalid = false;
  @override
  Future<String> generate(
    String model,
    String prompt,
    void Function(String) onPartial, {
    ProbeTrace? trace,
  }) async {
    requests++;
    this.prompt = prompt;
    onPartial('{');
    if (pending != null) return pending!.future;
    if (invalid) return '{}';
    final action = NarrativeAction.values.firstWhere(
      (a) => prompt.contains('Действие: ${a.name}.'),
    );
    return jsonEncode(answer(action));
  }

  @override
  Future<String> probe(
    String model,
    void Function(String) onPartial, {
    ProbeTrace? trace,
  }) => throw UnimplementedError();
  @override
  void cancel() {
    cancels++;
  }

  @override
  void dispose() {}
}

void main() {
  test(
    'claims are new across intro/more/surprise and source mapping is local',
    () {
      final used = <String>{};
      for (final action in NarrativeAction.values) {
        final r = NarrativeRequest(action, used);
        final segment = NarrativeSegment.parse(jsonEncode(answer(action)), r);
        expect(segment.claimIds.intersection(used), isEmpty);
        expect(segment.sourceIds.every(evidenceSources.containsKey), isTrue);
        used.addAll(segment.claimIds);
        expect(NarrativeRequest(action, used).selected, isEmpty);
      }
      expect(used.length, 7);
    },
  );
  for (final variant in [
    'unknown_claim',
    'repeated_claim',
    'unknown_source',
    'missing_claim',
    'url',
    'empty',
    'version',
  ]) {
    test('invalid narrative rejected: $variant', () {
      final a = answer(NarrativeAction.intro);
      switch (variant) {
        case 'unknown_claim':
          a['claimIds'] = ['invented'];
        case 'repeated_claim':
          (a['claimIds'] as List).add('fire');
        case 'unknown_source':
          a['sourceIds'] = ['invented'];
        case 'missing_claim':
          a['claimIds'] = ['fire'];
        case 'url':
          a['text'] = 'https://invented.invalid';
        case 'empty':
          a['text'] = ' ';
        case 'version':
          a['version'] = 2;
      }
      expect(
        () => NarrativeSegment.parse(
          jsonEncode(a),
          NarrativeRequest(NarrativeAction.intro, {}),
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'failure and cancellation never consume facts; retry and follow-up work',
    () async {
      final p = FakeNarrator();
      final auth = AuthController(p)..selectedModel = 'model';
      final c = NarrativeController(auth);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      p.invalid = true;
      await c.generate(NarrativeAction.intro);
      expect(c.consumed, isEmpty);
      expect(c.error, isNotNull);
      p.invalid = false;
      p.pending = Completer<String>();
      final pending = c.generate(NarrativeAction.intro);
      await c.generate(NarrativeAction.intro);
      expect(p.requests, 2);
      c.cancel();
      p.pending!.complete(jsonEncode(answer(NarrativeAction.intro)));
      await pending;
      expect(c.history, isEmpty);
      expect(c.consumed, isEmpty);
      p.pending = null;
      await c.generate(NarrativeAction.intro);
      await c.generate(NarrativeAction.more);
      expect(c.history.length, 2);
      expect(c.consumed.length, 5);
      expect(p.prompt, contains('"fire"'));
      await auth.disconnect();
      expect(c.history, isEmpty);
      expect(c.trace, isNull);
    },
  );
  testWidgets('story page actions, evidence and 320px large text layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(FakeNarrator());
    await auth.loadModels();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: NarrativePage(auth: auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Начать рассказ'), 300);
    await tester.tap(find.text('Начать рассказ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Рассказ о соборе.'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Рассказ о соборе.'), findsOneWidget);
    expect(find.text('Источники фактов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
