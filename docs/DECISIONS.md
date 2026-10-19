# Engineering decisions & open questions

## M2.0 — explicit stories from a small evidence packet

Owner tentatively confirmed M1 and authorized continuing on 19 October 2026. Implement one cathedral stop with seven reviewed facts and a versioned narration port. Reuse the authenticated streaming transport; prompt for JSON and validate locally rather than assuming preview schema-format support. Three fixed fact groups guarantee ID novelty; semantic faithfulness remains a manual acceptance check, explicitly disclosed in UI. Display stories only after completion/validation, consume IDs on display, never on failed/cancelled generation. Account changes and page exit discard local history. No persistence/prefetch or new location permissions. See M2_VALIDATION.md for sources, checks and limitations.

## M1.7 — use streamed text after valid empty-output completion

Owner's M1.6 trace confirms successful terminal inference with `output: []` after text deltas; our final-output-only assumption rejected it. Use accumulated deltas only when the validated final output list is empty. Preserve final-output precedence, terminal status and ID checks, and failure handling. Regression reproduced the exact structural rejection before the fix; 92 tests pass after it. Corrected device UI acceptance remains pending.

## M1.6 — diagnose completion in one report

Owner received text deltas in M1.5 but no accepted completion. Replace incremental short-code diagnosis with bounded structural tracing through transport, SSE parser and UI. Expose event counts/history, timings, terminal response shape and exact rejection without raw bodies, credentials or account data. Trace is optional through the provider boundary and memory-only. Do not infer completion from fluent text or relax terminal validation without evidence. Tests cover malformed completion, pending EOF frame, bounded/redacted history and UI cleanup; device report is still required.

## M1.5 — validate headerless Responses bodies

Observed M1.4 HTTP 200/media=missing confirms the premature Content-Type rejection but not the body format. Accept an absent header only by parsing the same documented SSE events and requiring valid completed output. Explicit incompatible types remain errors; JSON is never a success fallback. A failing transport regression with a headerless valid SSE body passes after this change. Add safe empty/no-event distinctions and retain status/media on parser errors. Actual inference on the phone still requires owner confirmation. See M1_VALIDATION.md and the official models-and-inference reference there.

## M1.3 foreground-only start of token exchange

Owner reproduced the same socket os=7 on Wi-Fi and mobile data, without VPN/filtering. M1.2 did not resolve it. Callback processing previously started exchange while the browser could still be foreground. Add a required foreground-wait dependency to AuthService, wired to Flutter lifecycle events in the Android app. Await resumed after validation, with cancellation and a one-minute timeout; only then send the code once. Tests prove sequencing and adapter cleanup. Actual device cause and resolution remain unconfirmed; do not blame home Wi-Fi or claim DNS configuration is at fault solely from errno.

## M1.4 response-format validation

Owner confirmed M1.3 sign-in and model discovery on one phone, followed by `response / protocol` during the explicit GPT test. Code narrows this to the HTTP-200 media-type guard; the live header is unknown. A synthetic mixed-case valid SSE header reproduced the rejection. Normalize the exact MIME type, cancel rejected streams, and expose only a closed media-category enum plus HTTP status. Keep valid `response.completed` mandatory; do not accept JSON-200 as successful streaming inference or introduce an alternate endpoint. Local format/analysis and 73 tests passed. Device resolution remains pending; see M1_VALIDATION.md.

## M1.2 connection isolation

Actual owner diagnostic narrowed the failure to `exchange / network / socket`. Use a fresh HTTP client after the browser round trip so the one-time code exchange cannot reuse pre-consent pooled connections. A synthetic stale-client fault fails before and passes after this change; the actual device/network cause remains unconfirmed. Do not replay the code. Add numeric OS socket errors to the safe diagnostic only, retaining no addresses/messages. Validate on the owner's phone before claiming a fix.

## M1.1 diagnostic follow-up

Owner confirmed consent and receipt of the loopback return page, then supplied a screenshot of a generic network error without HTTP status. Root cause remains unknown. An injected exchange StateError reproduced a separate reporting defect: all unexpected exceptions were classified as network errors. Add safe stage/cause enum codes and a copy action, preserve JWKS transport errors, and distinguish internal failures from socket/TLS/HTTP failures. No raw exceptions, credentials or callback URLs in diagnostics; no speculative OAuth workaround. Regression tests cover classification/redaction and UI display. Next evidence needed is the code from an actual device retry; do not call this a successful authentication fix.

## M1 implementation record — 16 October 2026

- Owner confirmed the M0 real-Android offline smoke test and explicitly authorized M1. No further device coverage is inferred.
- Implement the official OSS SIWC contract with a Dart loopback listener and an Android system-browser/Keystore bridge, behind `AuthProvider` and `ENABLE_CHATGPT_AUTH`. Public metadata confirms the issuer, token and JWKS locations and RS256. Reviewed docs neither prove reliable Android support nor state a categorical prohibition; physical-device feasibility remains an acceptance gate. Sources and exact checks: [M1_VALIDATION.md](M1_VALIDATION.md).
- Public OAuth endpoints and public Responses API only. No API-key fallback, embedded WebView, custom redirect scheme or private ChatGPT backend.
- Retain issued-client/subject account mappings after logout. Credentials and stable host UUID are installation-local, excluded from backups. Verified email is a display label, never the account key.
- Serialize operations. Persist a session tombstone before rotating refresh tokens so process death or failed replacement storage cannot revive the old token. The tradeoff is interactive reauthentication after an interrupted refresh.
- Model discovery and explicit diagnostic inference are separate from the offline tour. A completed SSE response is the only success signal; generated diagnostic facts are unverified and cannot enter tour history.
- HTTP, JWT and UI tests use mocks; local loopback socket tests are host-only. Keystore, browser/process lifecycle, account eligibility, actual consent/scopes and subscription inference require the two owners' physical-device checks. Stop at M1 pending these results.

## M0 implementation record — 16 October 2026

- Flutter 3.47.7 / Dart 3.13.5 standard Android scaffold; no runtime third-party packages. ChangeNotifier coordinates UI while TourEngine and ports remain pure Dart.
- Consume a segment when displayed. Loading/preparing fixture content never marks a segment as displayed. Revision-based transitions and controller serialization prevent duplicate next actions from the same screen state.
- Source-grounded short Russian demo summaries and an original schematic arch illustration; no remote photos, network services or fabricated citations.
- Audio is explicitly unavailable, not simulated as playing. Camera is deferred to M4; location is a labelled mock. No real permission prompts in M0.
- Persistent storage deferred: memory adapter only, clearly disclosed in settings and README. Story lengths are intentionally reduced for the first demo.
- Direct pushes to main authorized by owner; no PR required. M1 remains a separate reviewed task. The README's original parallel OAuth suggestion was corrected to match kickoff.
- Local Flutter checks are available after installing a workspace SDK. Android SDK/device are absent; APK build attempted and blocked. CI includes APK build but device behavior must still be validated.


## ADR-001 (proposed): Android-first Flutter and domain/provider separation

**Decision:** Flutter for presentation; pure Dart domain/ports; per-platform adapters. **Why:** ship quickly on Android while preserving future iOS and audio/AR glasses integrations. **Trade-off:** some OAuth and glasses SDK functionality requires native Kotlin bridges.

## ADR-002 (proposed): Official open-source Sign in with ChatGPT, not unofficial session reuse

**Decision:** attempt official OAuth2/OIDC PKCE with eligible user subscription, after Android feasibility spike. **Why:** user and spouse have separate Plus subscriptions and want no paid per-call API initially. **Risk:** loopback browser OAuth contract is not yet demonstrated on Android; preview eligibility/limits are not guaranteed. If blocked, retain demo mode and review supported alternative. **Never** scrape ChatGPT cookies or impersonate official clients.

## ADR-003 (proposed): No centralized backend initially

**Decision:** keep app state on device, access OpenAI directly using authorized user OAuth where supported; separate POI and route adapters. **Why:** personal two-user prototype and lower operations burden. **Future:** a backend-held API credential will be required for a paid commercial architecture; do not embed long-lived secret keys in shipped mobile applications.

## ADR-004 (proposed): Sources first, generation second

**Decision:** fetch/curate historical evidence before asking GPT to tell a story. Store valid citations/claim IDs; demonstrate honest uncertainty, legends labelled. **Why:** differentiates the product from entertaining hallucinations.

## Open questions to resolve with tests

- OAuth loopback on Android and behavior on both devices.
- Best licensed POI/maps/routing provider with adequate UK historical coverage.
- Russian TTS voice quality and lock-screen capabilities.
- Sources and media licensing for actual production content.
- Choice of open-source license before public GitHub publication.
