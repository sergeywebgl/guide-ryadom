import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/ports.dart';
import '../domain/tour.dart';

class FixturePoiRepository implements PoiRepository {
  FixturePoiRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  @override
  Future<List<TourStop>> loadStops() async {
    final json = jsonDecode(
      await bundle.loadString('assets/fixtures/peterborough.json'),
    ) as Map<String, dynamic>;
    final sources = (json['sources'] as List)
        .map(
          (dynamic e) => Evidence(
            id: e['id'] as String,
            title: e['title'] as String,
            url: Uri.parse(e['url'] as String),
          ),
        )
        .toList();
    final sourceIds = sources.map((s) => s.id).toSet();
    final segments = <String>{};
    final claims = <String>{};
    StorySegment read(dynamic e) {
      final segment = StorySegment(
        id: e['id'] as String,
        text: e['text'] as String,
        claims: (e['claims'] as List).cast<String>().toSet(),
        evidenceIds: (e['sources'] as List).cast<String>(),
      );
      if (segment.text.trim().isEmpty ||
          !segments.add(segment.id) ||
          segment.claims.isEmpty ||
          segment.evidenceIds.isEmpty ||
          !sourceIds.containsAll(segment.evidenceIds) ||
          segment.claims.any((c) => !claims.add(c))) {
        throw const FormatException('Invalid or repeated fixture evidence');
      }
      return segment;
    }

    return (json['stops'] as List)
        .map(
          (dynamic e) => TourStop(
            id: e['id'] as String,
            title: e['title'] as String,
            subtitle: e['subtitle'] as String,
            intro: read(e['intro']),
            detail: read(e['detail']),
            surprise: read(e['surprise']),
            sources: sources
                .where((s) => (e['sources'] as List).contains(s.id))
                .toList(),
          ),
        )
        .toList();
  }
}

class MockAiProvider implements AiProvider {
  @override
  Future<StorySegment> prepare(TourStop stop, TourAction action) async =>
      switch (action) {
        TourAction.tellMore => stop.detail,
        TourAction.surpriseMe => stop.surprise,
        _ => stop.intro,
      };
}

class MockLocationProvider implements LocationProvider {
  const MockLocationProvider([this.value = LocationStatus.demo]);
  final LocationStatus value;
  @override
  Future<LocationStatus> status() async => value;
}

class MockRouteProvider implements RouteProvider {
  @override
  bool get isSchematic => true;
  @override
  List<String> orderedStopIds(List<TourStop> stops) =>
      stops.map((s) => s.id).toList();
}

/// Explicitly unavailable: M0 must not animate pretend speech as real audio.
class UnavailableSpeechOutput implements SpeechOutput {
  @override
  bool get available => false;
  @override
  Future<void> speak(String text) async =>
      throw UnsupportedError('TTS is not connected in M0');
  @override
  Future<void> stop() async {}
}

class MemoryTourRepository implements TourRepository {
  int? _index;
  @override
  Future<int?> loadSelectedStop() async => _index;
  @override
  Future<void> saveSelectedStop(int index) async {
    _index = index;
  }
}

class EmptyCredentialStore implements CredentialStore {
  @override
  Future<bool> get hasCredentials async => false;
  @override
  Future<void> clear() async {}
}
