import 'package:flutter/material.dart';

import 'app/guide_app.dart';
import 'features/tour_controller.dart';
import 'infrastructure/demo_adapters.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    GuideApp(
      controller: TourController(
        places: FixturePoiRepository(),
        location: const MockLocationProvider(),
        routes: MockRouteProvider(),
        speech: UnavailableSpeechOutput(),
        repository: MemoryTourRepository(),
        credentials: EmptyCredentialStore(),
      ),
    ),
  );
}
