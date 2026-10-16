# Instructions for Codex / coding agents

Read `README.md`, `docs/PRODUCT.md`, `docs/DESIGN.md`, and `docs/ROADMAP.md` before modifying project behavior.

## Engineering conventions

- Build **real, executable, tested code** in small, reviewable increments. No placeholder happy-path pretending external functionality works.
- Flutter/Dart, Android-first. Preserve pure Dart domain boundaries. UI must not import OpenAI HTTP or Android OAuth implementation directly.
- Russian-first accessible UI. Use a clean, modern historical walking-tour aesthetic; mobile-sized interactive targets and robust status states.
- Keep demo fixture fully offline and deterministic. It must remain available when OAuth is unconfigured or denied.
- Preserve extension points for independently replaceable AI providers and future wearables, without overengineering.
- Do not add a backend unless explicitly approved by the project owner.
- Maintain a strict distinction between speculative **prepared** narrative and user-**consumed** narrative. Do not update heard claims, route progress, or visit history simply because a background request completed. See `docs/PREFETCH.md`; implement the scheduler only in its planned milestone.
- Verify external library APIs and OpenAI docs rather than guessing. Document unknowns, blockers and findings in `docs/DECISIONS.md`.
- Never scrape ChatGPT session cookies, automate unofficial ChatGPT web endpoints or emulate internal clients; use documented SIWC only.
- Do not embed paid OpenAI API keys, tokens or personally identifiable information in source or logs. Do not commit user photos or precise location history.
- OAuth must use PKCE and state/nonce, validate ID token, enforce granted scopes and use encrypted storage; protect rotating refresh tokens.
- For SIWC `/v1/responses` set `store:false`, `stream:true`, pass `input` array, and avoid fields explicitly unsupported in the preview.
- AI historical claims must have real source evidence. Do not generate or silently trust fabricated citations. Legends must be labelled.
- No 'fake-live' claims: demo text/location must be visibly labelled demo, device features marked unsupported until tested.
- Unit/widget tests for each nontrivial feature. Attempt `dart format`, `flutter analyze`, `flutter test`; if Flutter SDK cannot be installed/run, say exactly which checks were impossible and why.
- Keep changes scoped to the current milestone; request review before major architecture pivots. Avoid unrelated refactors.
- Each code task's final report: files changed; feature behavior; commands/tests run and results; device-only manual tests outstanding; limitations/risks; next suggested task.

## Coding task process

Owner workflow: commit and push directly to `main` after relevant checks; no pull request or repeated permission request is needed for routine scoped implementation. Stop at the current milestone boundary. This supersedes older PR instructions in planning documents.

1. Identify milestone and acceptance criteria.
2. Implement domain contracts + fake adapters first.
3. Build functional UI with error/empty states.
4. Add tests, format/analyze/test, and update README with run commands.
5. Explain clearly what is real vs mock; do not assert device behaviors without executing device tests.
