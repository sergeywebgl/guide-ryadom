# Technical Design Document — Guide Ryadom

**Status:** Proposed architecture, v0.1 (15 October 2026). MVP: Android personal/open-source prototype for two independent Plus accounts. Verify eligibility and actual mobile functionality before treating SIWC as shipped.

## 1. Goals, boundaries, assumptions

Build an independently testable location-aware AI guide. No centralized backend in v0.1. The app must function in offline **demo** mode before any external service setup. The critical uncertainty is whether the documented local loopback OAuth flow works reliably on actual Android devices with the system browser; prove it in a time-boxed spike. Do not replace official SIWC with browser-cookie scraping or unsupported ChatGPT backend APIs.

We assume Flutter UI, pure Dart domain layer, minimal Android native bridge for capabilities not cleanly supported in Flutter, and plugin-based providers. iOS compatibility is a future consideration, not a claimed tested deliverable.

## 2. Proposed modules

```text
lib/
  app/                     bootstrap, routing, theme, DI/providers
  features/
    tour/                   tour screen, controller, route/list views
    discover/               free-walk POI discovery
    camera/                 capture, crop, identify interaction
    settings/               language, interests, voice, account state
    onboarding/             demo/permissions/sign-in
  domain/
    models/                 Place, Tour, TourStop, StorySegment, Evidence, PhotoMatch
    services/               TourEngine, NarrativeOrchestrator, NextStopPlanner,
                            PrefetchScheduler (later)
    ports/                  AiProvider, PoiRepository, RouteProvider, LocationProvider,
                            SpeechOutput, PhotoInput, CredentialStore, TourRepository, NarrativeCache (later)
  infrastructure/
    ai/                     MockAiProvider, SiwcResponsesProvider, ApiKeyProvider (later)
    geo/                    MockLocationProvider, DeviceLocationProvider
    places/                 FixturePoiRepository; OSM/Wikidata adapters (later)
    routing/                MockRouteProvider, real route adapter (later)
    audio/                  AndroidSpeechOutput (TTS)
    storage/                local preferences, encrypted credentials
  shared/                   error types, results, logging, utilities
assets/fixtures/            Peterborough JSON facts & stop stories, properly attributed
test/                       unit and widget tests
integration_test/           scripted tour tests
```

Providers are interface-driven. Domain must not import Flutter, network libraries, platform plugins, or device SDKs. UI interacts with controllers, not OpenAI SDK calls.

## 3. Core contracts (illustrative)

```dart
enum TourAction { nextStop, tellMore, surpriseMe, identifyObject, pause, resume }

enum EvidenceKind { documented, interpretation, legend, unverified }

class SourceEvidence {
  final Uri url;
  final String title;
  final EvidenceKind kind;
  final List<String> claimIds;
  // ... immutable constructor
}

abstract interface class AiProvider {
  Stream<AiNarrativeEvent> generateStory(StoryRequest request);
  Stream<AiIdentificationEvent> identifyObject(PhotoRequest request);
}

abstract interface class PoiRepository {
  Future<List<Place>> findNear(Coordinate location, double radiusMetres);
}

abstract interface class TourRepository {
  Future<TourState?> loadActive();
  Future<void> save(TourState state);
}
```

`StoryRequest`: current stop ID, candidate factual sources, prior narrated segment IDs and key claims, selected interests, length/locale, mode (`intro`, `more`, `surprise`), optional selected image context. `StoryResponse`: spoken and displayed text, stop ID, `usedClaimIds`, cited evidence IDs, suggested visual cues, uncertainty/legend markers. Validate all IDs and URLs against retrieved/curated source inputs; if output is malformed or claims ungrounded, fail gracefully / regenerate when safe. Never treat model-supplied URL as verified.

## 4. Tour state machine

`notStarted → active(stop n, segment k) ↔ paused → completed`; temporary substates `loading`, `speaking`, `offlineFallback`, `needsAuth`, `error`. Store durable event/state snapshots to survive process death. Maintain `heardClaimIds` and `shownSegmentIds` so details don't repeat. `NextStop` commits completion and advances to the chosen stop exactly once (idempotency). Audio cancellation must not change completed-story state incorrectly.

`nextStop`, `tellMore`, `surpriseMe`, `identifyObject` map from button, voice or future wearable. Never let AI mutate route history directly; orchestrator validates proposed change.

## 4a. Speculative narrative prefetch (future implementation, design constraint now)

The tour must behave as a graph of user actions: while a current story is being read or spoken, the orchestrator may pre-generate *validated* immediate successor nodes (`tellMore`, deterministic `nextStop`, optionally `surpriseMe`). A prepared node is not yet user-consumed; do **not** update narrated claim IDs, progress, or visit history until the user commits the transition. On tap, choose a valid prepared node instantly, join an in-flight request if present, or invoke the AI provider normally if absent/stale. Do not block initial story rendering on speculative generation.

Keep geographic route selection and storytelling nodes separate. Any prefetched `nextStop` must be revalidated against the route and current context before use. Implement depth-1, budgeted, cancellable and deduplicated speculation; avoid generating an exponential graph or exhausting ChatGPT Plus limits. The response cache must have a canonical context hash, source revision, size/TTL bounds, explicit invalidation, and complete-response validation. Never speculate on images the user has not captured. This is response precomputation rather than automatic API prompt caching. See **[PREFETCH.md](PREFETCH.md)** for full RFC, contracts, queue priorities, race conditions, and tests.

## 5. Place discovery and route planning

MVP: bundled Peterborough fixture, mock route and location to test everything offline. Then implement foreground GPS using explicit permission, detect accuracy; never silently select a small indoor object using GPS alone. Query POIs via an adapter (OSM/Overpass/Wikidata or another licensed source); request only geographic bounds needed, cache and rate-limit. Cross-reference identities and deduplicate. Distinguish POI discovery from factual research: OSM tags alone are not adequate historical evidence.

Routing: use a real foot-routing provider when introduced; do not draw straight-line polylines as if they are walking routes. Rank future stops by significance, interests, walking time, availability and whether already visited. The user may skip and override, with resume logic. Comply with map tile/geocoding usage policies and attribution; do not bulk-hit public OSM endpoints.

## 6. Historical evidence and AI narrative

Pipeline: candidate POI → canonical identity → source retrieval/cached curated records → extract evidence claims → short story grounded in claim IDs → semantic repetition check → human-readable source links. Sources can include official museum/cathedral pages, heritage organizations, trustworthy archives, Wikidata as discoverability hints, Wikipedia with corroboration for notable claims. Record `retrievedAt`, source URL, licensing and source quality. Distinguish direct fact, interpretation and folklore.

Do not ask a model to freely invent web citations. If source lookup fails, say historical information could not be verified or use explicitly curated cached content. No invented quotes; no assertive identification from an ambiguous photograph. Treat scraped content as untrusted input (prompt injection resistance). Prefer approachable Russian narration with compelling hooks over bland encyclopaedia style. Add regression cases for repetitive narration, spurious sourcing and image uncertainty.

## 7. Vision / camera interaction

Camera is user-triggered. Optionally locally compress/resize and strip EXIF before network upload. Send only consented image plus coarse location, candidates and model instructions; never perform passive capture or upload. Confirm model accepts image input for current account. UI can offer top candidates if confidence is uncertain; do not invent an exact numeric certainty if model cannot calibrate it. Do not store photo in logs; delete transient files after use. An online response may not be possible with account quota reached; show offline explanation.

## 8. Voice

Use local Android TextToSpeech first, checking availability and selected Russian voice. Expose play/pause/stop and speaker state to screen; preserve playback position if platform permits; TTS events may be approximate. Use OS audio focus/interruption handling. Do not claim headphone, lock screen or background playback support until device validated. No always-on recording; a future voice-command adapter can implement push-to-talk with permission.

## 9. Authentication and AI provider: **feasibility gate**

OpenAI's open-source Sign in with ChatGPT (SIWC) documentation describes dynamic OAuth client registration with browser sign-in; use `client_id=dynamic_agent_client` on first registration, a stable host ID (`ext_agent_host_id`), PKCE S256, random state/nonce, `openid profile email offline_access resource.invoke chatgpt.tokens.use.direct`, resource `https://api.openai.com/v1`, and an **HTTP 127.0.0.1 loopback callback**. The callback path, host, authorization/exchange redirect URI consistency and ID-token validation are non-negotiable. On first registration retain the issued `client_id`; never persist `dynamic_agent_client` as issued ID. Only allow plan inference if granted scope includes `chatgpt.tokens.use.direct`.

**Android constraint:** official docs are written for clients able to receive loopback callbacks. A loopback listener + system browser may be viable on Android but is not a proven implementation here. Spike must test callback on physical device, browser switching/backgrounding, deep app lifecycle, sign-in for two *separate* Plus accounts on separate devices, token refresh (rotating tokens), logout/revoke, and failure cases. Do not use an embedded WebView for OAuth and do not invent a custom URI scheme as replacement for the documented callback without official support.

SIWC inference: `GET https://api.openai.com/v1/models` with account's bearer access token to enumerate available models; select an available model (no hard-coded entitlement). `POST https://api.openai.com/v1/responses` with `store:false`, `stream:true`, `input` array; omit unsupported request fields such as `temperature`, `max_output_tokens`, `conversation`, `previous_response_id`, `metadata` per preview docs. Send full required local context. Consume SSE through `response.completed`; expose cancellation/errors. Text and image inputs supported *if selected model accepts them*. OpenAI-hosted TTS/transcription is not in this flow. Web search depends on model/account/workspace policy, so external fact sourcing cannot assume it. Use robust network timeouts, bounded retry for transient errors and user-friendly quota handling.

Secure access/refresh and optional ID tokens via OS-backed secure storage; never print or commit. Refresh tokens rotate: serialize refresh, atomically store replacements. Two users never share tokens. Network traffic to OpenAI uses HTTPS. Handle consent denial, ineligible account, no internet, quota, 401/403, 429, malformed SSE, lost callback, restart and token expiry.

A future `PaidOpenAiProvider` may be added with backend-held API key to avoid shipping keys to a commercial client. For personal MVP, **do not embed an unrestricted paid API key in the Flutter app**.

## 10. Local data and privacy

Store preferences and tour snapshots on-device (SQLite later if needed). Secure credentials only in platform protected store. Default ephemeral location fixes; persistent route visit state stores POI IDs/timestamps rather than continuous raw location trail. Let users clear history and disconnect ChatGPT. No location or photo analytics by default. Redact tokens, user identity and precise location from logs. Surface source attribution / map licensing. Required permissions: foreground location on demand, camera on demand; microphone only if voice commands are implemented. No background-location permission MVP.

## 11. UI architecture

Material 3, Russian strings centralized for future l10n, accessible large targets (>=48 logical pixels), good large-text handling and small-screen portrait. Main tour card with big Next action, short intro, progressive details, voice control, sources, route tab and camera action. Clearly distinguish app demo mode vs real GPS/AI; never show fake location as live user location. Display progress and graceful loading skeletons. Avoid a chatbot as navigation.

## 12. Wearables / AR portability

Input ports: `CameraInput`, `LocationProvider`, `TourActionSource` (touch now; voice/glasses later). Output ports: `StoryRenderer`, `SpeechOutput`, `NavigationHints`. TourState/event stream device-agnostic; same phone runtime can drive glasses over SDK. A future Meta-specific Kotlin adapter talks to a supported device SDK, but availability and permissions must be validated when implemented. Display glasses show short cues; audio-only glasses receive speech; full AR world anchoring remains out-of-scope until SDK/device capability proves possible.

## 13. Tests and CI

- Pure Dart unit tests for idempotent Next, story novelty context, skip/undo, resume state, offline error paths, provider errors.
- Widget tests for Next / More / Photo, permission denial, accessibility, Russian labels, large text, loading/error.
- Mock AI golden fixtures; API contract tests for SSE parser with normal, partial, malformed, premature EOF; abort and retry.
- Android integration smoke tests: GPS, camera permission, TTS Russian, browser loopback OAuth, successful plan inference/refresh on real hardware. Record screenshots and explicit pass/fail notes; do not fake CI proof if SDK unavailable.
- GitHub Actions CI when configured: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`; pin stable toolchain from lockfiles/setup.

## 14. Operational and failure expectations

Offline demo always works. Online free-walk should show cached stories when offline with provenance and last-updated date. For a route interrupted by network loss, show current stop and preserve history. Retry only safe/idempotent reads; avoid duplicate story/state append. Handle battery-saving and Android lifecycle; keep foreground positioning bounded. Performance goals at first iteration: UI interactions feel instant (<150 ms under normal conditions), visible progress indicator for AI network calls, avoid blocking frame rendering. Verify realistic rates on devices rather than promising fixed AI response times.

## 15. First review decisions / unresolved questions

1. Can SIWC loopback+PKCE be implemented safely/reliably on Android under actual system browser/lifecycle? **Blocker for subscription-only live AI**.
2. Does the account/model support images and structured content in the Responses contract? Verify dynamically.
3. Which real maps/POI discovery stack balances accuracy, licensing and ease? Choose after offline demo and OAuth spike.
4. Is a Russian Android TTS voice installed on both phones, and what is acceptable quality?
5. Which Flutter packages are current and maintained? Validate when coding; don't assume old dependencies work.
6. Open-source license needs owner's approval; MIT is a reasonable proposal, not automatic user authorization.

## 16. Primary references

- https://developers.openai.com/siwc/token-sharing-open-source
- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://developers.openai.com/siwc/token-sharing-open-source/token-reference

Review docs at implementation time: the service is in preview and its requirements may change.
