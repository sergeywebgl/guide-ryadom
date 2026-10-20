# Гид рядом / Guide Ryadom

A voice-first, location-aware AI walking-tour guide. **Personal open-source prototype** for two separate Android devices, each using its owner's ChatGPT Plus account, subject to account eligibility and current Sign in with ChatGPT restrictions.

**Status:** Owner confirmed M2 works on their phone on 20 October 2026. M3.1 adds explicit foreground location measurement; device acceptance is pending. See [M3.1 checklist](docs/M3_VALIDATION.md). M1 second-phone/lifecycle checks remain separate.

## Run the app

**M3.1 (1.3.1+11):** foreground coordinates/accuracy, approximate permission, cancellation and clear failure states. [Successful APK build 39387304639](https://github.com/sergeywebgl/guide-ryadom/actions/runs/39387304639), artifact `guide-ryadom-m31-debug`. Format, analysis, 113 tests and Android debug build passed. Physical-device verification remains pending.

**Previous APK — M2.0 (1.2.0+10):** [successful build 39336901614](https://github.com/sergeywebgl/guide-ryadom/actions/runs/39336901614), artifact `guide-ryadom-m2-debug`. Formatting, analysis, 103 tests and Android build passed. Open **Экскурсия → История с GPT · Питерборский собор**, load/select a model and tap **Начать рассказ**, then **Подробнее** or **Удиви меня**. Owner reported successful operation on 20 October 2026. Story history resets when this separate screen closes.

Use Flutter **3.47.7** (Dart **3.13.5**) and the Android SDK with Java 17. Install Android command-line/platform tools through Android Studio, accept SDK licences, and connect an Android phone with USB debugging or start an emulator.

```sh
flutter doctor -v
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

The initial dependency download/build needs internet. The installed demo itself works in airplane mode without accounts or keys.

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`. GitHub Actions runs the same checks and publishes `guide-ryadom-m31-debug` when its build succeeds; check the run status before expecting an artifact. This is a debug build, not a store release.

**M1 download:** open [successful M1 build 38898910026](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38898910026) (code `bd8cbe7`) and download `guide-ryadom-m1-debug`. Format, analysis, 51 tests and Android build passed. Unzip and install `app-debug.apk`. In Settings, tap **Подключить ChatGPT**, finish consent in the system browser, return to the app, then tap **Отправить тестовый запрос**. Only **Ответ завершён · response.completed** confirms the request completed. No API key is needed. Full instructions and update-signing caveat: [M1_VALIDATION.md](docs/M1_VALIDATION.md).

To build only the offline interface: `flutter run --dart-define=ENABLE_CHATGPT_AUTH=false` (or pass the same define to `flutter build apk --debug`).

The temporary package ID is `com.example.guide_ryadom`. For release, update `applicationId` and `namespace` in `android/app/build.gradle.kts`, and the package declaration/path of `MainActivity.kt`; configure release signing separately. Do not commit signing keys.

### What works now

- Three bundled Peterborough stops with original short Russian summaries and source links that can be copied into a browser.
- Distinct intro/detail/surprise segments, next/back/skip, explicit finish and restart; duplicate transitions are rejected.
- Tour, schematic route and settings tabs; text size control; clear demo/no-account indicators.
- Pure Dart domain and replaceable provider interfaces; prepared content does not become consumed until displayed.
- Separate ChatGPT account UI, documented PKCE/OIDC loopback sign-in, Android Keystore encrypted credentials, model discovery, explicit streamed diagnostic request and logout. The tour continues using its offline fixture.

### Current limitations

M3.1 adds one-shot device coordinates through **Экскурсия → Места рядом → Определить местоположение**. Maps, nearby discovery, audio and camera are not connected. The Listen and camera controls explain their unavailable state. No network requests or account are required by the demo. Location permission is requested only after the measurement button is tapped; no background location or camera permission is requested. Coordinates are not persisted or sent by the app. Tour progress and text settings reset when the process restarts; OAuth credentials persist separately in Android-backed encrypted storage. Narratives are deliberately shorter than production word-count targets. Background/lock-screen playback is not implemented.

Local validation on 16 October 2026: analysis clean and 9 tests passed, including 320px/200% text layout. Local APK build was attempted but blocked by **No Android SDK found**; this is not a successful device test. See [M0 validation](docs/M0_VALIDATION.md).

## Product promise

Walk around an unfamiliar city; the guide discovers relevant historical places, tells engaging and **source-grounded** stories, explains photographed objects, remembers what it has already said, and offers one-tap actions: **Next stop**, **Tell me more**, **What's this?**, **Surprise me**, **Pause / Listen**.

- Russian-first experience; English later.
- Phone-first, spoken narration with Android TTS.
- No chatbot as the main UI; chat may be an optional expert mode in the future.
- Location/photo permissions are opt-in and contextual.
- Architecture isolates UI, tour engine, content sourcing, AI, maps and device capabilities, so AR glasses can be integrated later.

## Start here

1. Read [PRODUCT.md](docs/PRODUCT.md).
2. Read [DESIGN.md](docs/DESIGN.md), especially the **OAuth feasibility gate**.
3. Read [AGENTS.md](AGENTS.md) (instructions for coding agents).
4. Follow [ROADMAP.md](docs/ROADMAP.md). For future fast next-action responses, see [PREFETCH.md](docs/PREFETCH.md).
5. Paste [CODEX_KICKOFF.md](codex/CODEX_KICKOFF.md) into **Codex** with this repository selected.

## First deliverable

M0 implements the **offline demo** with the Peterborough Cathedral example and responsive Russian UI. M1 is the authorized Android OAuth proof of concept; its physical-device acceptance gate remains open. Do **not** claim subscription inference is working until the owner completes that gate. The original kickoff is historical M0 scope; the owner has separately authorized M2. Stop before M3.

## Technology proposal

Flutter/Dart; clean-ish layered architecture; Riverpod or comparably testable state management; local app storage; Android Text-to-Speech; native platform adapters only where necessary. No backend required for initial prototype. `TourEngine` and `AiProvider` remain replaceable.

## External docs

- [SIWC OSS overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [OAuth registration & sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Models & inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [Codex with GitHub](https://help.openai.com/en/articles/11390924)

**Security:** Never commit user photos, location traces, access/refresh tokens, OAuth codes, client-generated host secrets or `.env` values. Use mocks and sanitized logs.
