import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guide_ryadom/domain/tour.dart';
import 'package:guide_ryadom/domain/ports.dart';
import 'package:guide_ryadom/features/tour_controller.dart';
import 'package:guide_ryadom/infrastructure/demo_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<TourStop> stops;
  setUp(() async {
    stops = await FixturePoiRepository().loadStops();
  });

  test('all three stops have distinct grounded segments', () {
    expect(stops.length, 3);
    for (final stop in stops) {
      final sources = stop.sources.map((s) => s.id).toSet();
      for (final segment in [stop.intro, stop.detail, stop.surprise]) {
        expect(sources.containsAll(segment.evidenceIds), isTrue);
      }
      expect(stop.sources.every((s) => s.url.scheme == 'https'), isTrue);
    }
  });

  test(
    'preparing detail does not consume it; selection adds novel claims once',
    () async {
      final e = TourEngine(stops);
      final initial = e.consumedClaims;
      await MockAiProvider().prepare(e.current, TourAction.tellMore);
      expect(e.consumedClaims, initial);
      expect(e.shownSegments, {stops.first.intro.id});
      expect(
        e.dispatch(TourAction.tellMore, expectedRevision: e.revision),
        isTrue,
      );
      expect(e.segment.text, isNot(stops.first.intro.text));
      expect(e.segment.claims.intersection(initial), isEmpty);
      expect(
        e.dispatch(TourAction.tellMore, expectedRevision: e.revision),
        isFalse,
      );
      expect(
        e.dispatch(TourAction.surpriseMe, expectedRevision: e.revision),
        isTrue,
      );
      expect(e.hasSurprise, isFalse);
    },
  );

  test('duplicate transition, back, skip, completion and explicit restart', () {
    final e = TourEngine(stops);
    final revision = e.revision;
    e.dispatch(TourAction.nextStop, expectedRevision: revision);
    expect(
      e.dispatch(TourAction.nextStop, expectedRevision: revision),
      isFalse,
    );
    expect(e.index, 1);
    e.dispatch(TourAction.back, expectedRevision: e.revision);
    expect(e.index, 0);
    e.dispatch(TourAction.skip, expectedRevision: e.revision);
    expect(e.skippedStops, {stops.first.id});
    e.dispatch(TourAction.nextStop, expectedRevision: e.revision);
    e.dispatch(TourAction.nextStop, expectedRevision: e.revision);
    expect(e.completed, isTrue);
    expect(e.index, 2);
    expect(
      e.dispatch(TourAction.nextStop, expectedRevision: e.revision),
      isFalse,
    );
    e.dispatch(TourAction.back, expectedRevision: e.revision);
    expect(e.completed, isFalse);
    expect(e.index, 2);
    e.dispatch(TourAction.restart, expectedRevision: e.revision);
    expect(e.index, 0);
    expect(e.skippedStops, isEmpty);
    expect(e.shownSegments, {stops.first.intro.id});
  });

  test('empty fixture fails rather than showing a fake tour', () {
    expect(() => TourEngine([]), throwsArgumentError);
  });

  test('malformed evidence is rejected', () async {
    final repo = FixturePoiRepository(bundle: _BadBundle());
    await expectLater(repo.loadStops(), throwsFormatException);
  });

  test(
    'controller serializes rapid taps and survives disposal during loading',
    () async {
      final c = controller();
      await c.load();
      final revision = c.engine!.revision;
      await Future.wait([
        c.act(TourAction.nextStop, revision),
        c.act(TourAction.nextStop, revision),
      ]);
      expect(c.engine!.index, 1);
      c.dispose();
      final pending = Completer<List<TourStop>>();
      final loading = controller(places: _PendingPlaces(pending));
      final future = loading.load();
      loading.dispose();
      pending.complete(stops);
      await future;
    },
  );

  test('failed load retries; denied location still permits demo', () async {
    final flaky = _FlakyPlaces(stops);
    final c = controller(
      places: flaky,
      location: const MockLocationProvider(LocationStatus.denied),
    );
    await c.load();
    expect(c.error, isNotNull);
    await c.load();
    expect(c.error, isNull);
    expect(c.engine, isNotNull);
    expect(c.locationStatus, LocationStatus.denied);
    c.dispose();
  });
}

TourController controller({
  PoiRepository? places,
  LocationProvider? location,
}) => TourController(
  places: places ?? FixturePoiRepository(),
  location: location ?? const MockLocationProvider(),
  routes: MockRouteProvider(),
  speech: UnavailableSpeechOutput(),
  repository: MemoryTourRepository(),
  credentials: EmptyCredentialStore(),
);

class _PendingPlaces implements PoiRepository {
  _PendingPlaces(this.pending);
  final Completer<List<TourStop>> pending;
  @override
  Future<List<TourStop>> loadStops() => pending.future;
}

class _FlakyPlaces implements PoiRepository {
  _FlakyPlaces(this.stops);
  final List<TourStop> stops;
  bool first = true;
  @override
  Future<List<TourStop>> loadStops() async {
    if (first) {
      first = false;
      throw const FormatException('broken fixture');
    }
    return stops;
  }
}

class _BadBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw const FormatException('broken JSON');
}
