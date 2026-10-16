# Codex kickoff task — Milestone M0

You are the implementation engineer for **Guide Ryadom (Гид рядом)**, an Android-first, voice-oriented AI walking-tour guide. Read the repository's `README.md`, `docs/PRODUCT.md`, `docs/DESIGN.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, and `AGENTS.md` in full before writing code.

**Objective for THIS task:** Create a clean, runnable Flutter Android project that demonstrates the primary product flow **offline with deterministic data**, and leaves well-defined adapters for future GPS, camera and official ChatGPT subscription auth. The task is *not* to claim complete functionality or silently consume a paid OpenAI API.

### Implement

1. Initialize Flutter stable project in the existing repo, respecting README/docs. Set sensible package ID (e.g. `com.example.guideryadom` for now) and document how to change it for release. Ensure Git ignores generated files, secrets and user photos.
2. Build a polished, Russian-first, accessible phone UI inspired by a contemporary historical tour: top area/location indicator explicitly `Демо: Питерборо`, photo/illustration card or offline-friendly placeholder, story card, progress, dominant `Идём дальше`, secondary `Подробнее`, `Что это?`, `Удиви меня`, clear `Слушать/Пауза`, bottom navigation `Экскурсия / Маршрут / Настройки`. Don't use a text chat as the main interface.
3. Include three curated Peterborough Cathedral stops from app assets (facade, Catherine of Aragon burial, former Mary Queen of Scots burial), intro + non-repeating extended detail + surprise fact + source links. Label any fabricated illustrative content as a sample; do not invent historical citations. Don't require online photos or API keys for demo.
4. Create domain ports (`AiProvider`, `PoiRepository`, `LocationProvider`, `RouteProvider`, `SpeechOutput`, `TourRepository`, `CredentialStore`) and fake/mock implementations; controller/service takes `TourAction` enum. Persist selected stop and preferences locally if straightforward, without delaying compile. Separate domain, infra and Flutter features.
5. Show useful fallback states for offline/no sign-in, denied location, unavailable camera (camera button can show explicit `Будет в M4` explanation in this task, rather than pretending it identifies photos). A route tab can show ordered stops with **clearly schematic** navigation, not a fake GPS map.
6. Provide unit tests for progress, back/skip, `tellMore` showing new content rather than repeating intro; widget tests for primary controls, Russian labels, compact phone/large text. Add GitHub Actions/flutter analysis/test workflow only if it is reliable in the environment.
7. Document precise build/run/test commands and what still requires Android hardware.

### Explicitly out of scope

Real OAuth token flow, OpenAI API calls, automatic source retrieval, live GPS/maps, real camera recognition, always-on microphone, AR SDK integration, paid API keys and commercial accounts. Prepare interfaces only. Do not commit any secrets.

### Acceptance criteria

- A new developer with Flutter and Android SDK can run the demo on Android using documented commands.
- Demo loads without account credentials, internet or third-party keys.
- All specified UI actions work (unimplemented hardware actions have transparent disabled/coming-soon UX).
- No obvious layout overflow at large text scale and small phone width.
- `flutter analyze` and `flutter test` pass if toolchain available; otherwise note exact environment constraints and leave CI/test files ready.
- At the end, report files changed, tests and commands, screenshots if possible, architecture deviations, blockers and the next M1 auth-spike plan.

**Important:** Do not move to M1 without review. Respect the strict OAuth feasibility gate from `docs/DESIGN.md`; never implement undocumented ChatGPT cookie/session scraping as a shortcut.
