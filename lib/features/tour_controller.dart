import 'package:flutter/foundation.dart';

import '../domain/ports.dart';
import '../domain/tour.dart';

class TourController extends ChangeNotifier {
  TourController({
    required this.places,
    required this.location,
    required this.routes,
    required this.speech,
    required this.repository,
    required this.credentials,
  });
  final PoiRepository places;
  final LocationProvider location;
  final RouteProvider routes;
  final SpeechOutput speech;
  final TourRepository repository;
  final CredentialStore credentials;
  TourEngine? engine;
  bool loading = false;
  String? error;
  String? notice;
  LocationStatus locationStatus = LocationStatus.demo;
  bool _disposed = false;
  bool _transitioning = false;
  double textScale = 1;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final stops = await places.loadStops();
      final status = await location.status();
      if (_disposed) return;
      engine = TourEngine(stops);
      locationStatus = status;
    } catch (_) {
      error = 'Не удалось загрузить демо. Попробуйте ещё раз.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> act(TourAction action, int revision) async {
    if (_transitioning || engine == null) return;
    _transitioning = true;
    try {
      await speech.stop();
      if (_disposed) return;
      if (engine!.dispatch(action, expectedRevision: revision)) {
        notice = null;
        await repository.saveSelectedStop(engine!.index);
      }
    } catch (_) {
      notice = 'Не удалось выполнить действие. Попробуйте снова.';
    } finally {
      _transitioning = false;
      _notify();
    }
  }

  void explainCamera() => showNotice(
    'Камера появится в M4. Сейчас фотографии не снимаются и не отправляются.',
  );
  void explainSpeech() => showNotice(
    'Озвучка ещё не подключена в M0. Историю можно прочитать; звук не воспроизводится.',
  );
  void showNotice(String value) {
    notice = value;
    _notify();
  }

  void setTextScale(double value) {
    textScale = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
