import 'package:flutter/material.dart';

import 'app/guide_app.dart';
import 'features/tour_controller.dart';
import 'infrastructure/demo_adapters.dart';
import 'features/auth_controller.dart';
import 'infrastructure/auth/auth_service.dart';
import 'infrastructure/auth/android_auth.dart';
import 'infrastructure/auth/foreground_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    GuideApp(
      auth:
          const bool.fromEnvironment('ENABLE_CHATGPT_AUTH', defaultValue: true)
          ? AuthController(
              ChatGptAuthService(
                vault: AndroidAuthVault(),
                browser: AndroidSystemBrowser(),
                receiverFactory: LoopbackReceiver.new,
                waitForForeground: waitForAndroidForeground,
              ),
            )
          : null,
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
