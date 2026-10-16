# M0 validation and handoff

## Implemented

Offline Android-targeted Flutter app: three Peterborough stops; intro, unique detail and surprise; source URLs; next/back/skip; explicit completion/restart; route and settings; accessible Russian UI. All historical text is bundled in assets/fixtures/peterborough.json. Source IDs are mapped to claims per segment; fixture parsing rejects missing evidence and repeated claim/segment IDs.

Domain has no Flutter imports. Provider seams: AiProvider, PoiRepository, LocationProvider, RouteProvider, SpeechOutput, TourRepository, CredentialStore. M0 uses fixtures directly; MockAiProvider is available to test future preparation without consuming narrative state. No prefetch scheduler.

## Local evidence (16 October 2026)

- Flutter 3.47.7, Dart 3.13.5 on Windows.
- `dart format --output=none --set-exit-if-changed lib test tool`: run before commit.
- `flutter analyze`: no issues.
- `flutter test`: 9 passed. Covers novel claims, prepared/consumed distinction, stale duplicate transition, skip/back/end/restart, corrupt/empty data, retry, denied location, disposal during load, serialized taps, primary controls and compact 320px phone at 200% system text scale.
- Optional widget-rendered previews: `flutter test tool/preview.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf`. Output is build/previews; font stays local. These are Flutter test renders, not device screenshots.
- `flutter doctor -v`: Android SDK absent, no Android device/emulator connected.
- `flutter build apk --debug`: failed with `No Android SDK found`. GitHub Actions is configured to build with its Android toolchain and upload an APK only after success. Consult the actual run for remote build evidence.

## Manual Android acceptance still needed

Remote build confirmed: [GitHub Actions run 38863116504](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38863116504) succeeded for commit `4ac41f47a61de7f50593b83e4f60f1fc2672ce49`: formatting, analysis, all tests, debug APK build and artifact upload. Download `guide-ryadom-m0-debug` from that run and extract `app-debug.apk`. This proves compilation, not behavior on a physical device.

1. Build/install the debug APK on each phone; record Android version and device model.
2. Enable airplane mode before cold launch. Complete all three stops without credentials; no permission requests should appear.
3. Tap More and Surprise, verify distinct text and disabled exhausted actions. Rapidly double-tap Next; verify one transition. Check Back, Skip, finish, and explicit restart.
4. Test the smallest screen, largest system font and TalkBack labels/focus. Source-copy should work offline; opening a source externally requires internet.
5. Verify camera and audio controls explain unavailable functionality. They must not capture, upload or pretend to play audio.
6. Kill/relaunch: current M0 intentionally resets state. Settings explicitly disclose this.

## Next task (not executed)

Review M0 and perform the Android smoke test first. M1 is a time-boxed investigation of the current official SIWC contract and Android browser/loopback lifecycle, with each owner's account consent. Reverify external docs and eligibility before implementation. If unsupported, document the result and keep the offline demo working. No paid API substitution, camera/live GPS work, or M7 scheduler in this task.
