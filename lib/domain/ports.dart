import 'tour.dart';

abstract interface class AiProvider {
  Future<StorySegment> prepare(TourStop stop, TourAction action);
}

abstract interface class PoiRepository {
  Future<List<TourStop>> loadStops();
}

enum LocationStatus { demo, denied, unavailable }

abstract interface class LocationProvider {
  Future<LocationStatus> status();
}

abstract interface class RouteProvider {
  List<String> orderedStopIds(List<TourStop> stops);
  bool get isSchematic;
}

abstract interface class SpeechOutput {
  bool get available;
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class TourRepository {
  Future<int?> loadSelectedStop();
  Future<void> saveSelectedStop(int index);
}

abstract interface class CredentialStore {
  Future<bool> get hasCredentials;
  Future<void> clear();
}
