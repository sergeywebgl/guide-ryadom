# RFC 001 — Speculative Narrative Prefetch and Tour Graph

**Status:** Approved as architectural direction, not part of M0. Implement in a later milestone after live AI, navigation, and narrative-state behavior have been validated. **Owner:** Guide Ryadom. **Date:** 2026-10-15.

## Motivation and user experience

Tour narration typically lasts tens of seconds, while an AI request may take seconds to begin or complete. Use that listening/reading time to generate the likely next actions in the background. At the moment the user taps **Подробнее**, **Идём дальше**, or **Удиви меня**, display an already generated, fact-checked response when it remains valid. Avoid unnecessary waiting, but **do not block the current story on speculative work**.

This is *application-level response precomputation*, **not** OpenAI automatic prompt caching. Prompt caching (if available) may reduce model work on identical input prefixes; it does not make a new branch's answer instantly available to the user.

## Separate route and narrative graphs

- **Tour graph**: geographic POI nodes and walkable transitions. The next POI may change based on location, route conditions, user preference, accessibility, or skipping. A routing provider, not the language model, is authoritative for paths and walking time.
- **Narrative graph**: each node is a story segment grounded in an identified POI and known evidence. Edges represent user actions such as `tellMore`, `surpriseMe`, `nextStop`. Some transitions point to nodes for the next POI in the tour graph.
- Do **not** mistake a pre-generated story for a user-visible or user-heard story. Narrated claim IDs/segments change only when content is actually displayed or played according to a clearly defined consumption policy.

Example:

```text
POI 1: Cathedral                 Route graph: Cathedral --> Catherine tomb --> Mary site
  intro (currently playing)
    ├── tellMore  --> Cathedral/extra history    [prefetch priority 1]
    ├── nextStop  --> Catherine tomb/intro       [prefetch priority 1 if next POI fixed]
    └── surpriseMe --> Cathedral/unusual detail  [prefetch priority 2]

On chosen edge: render its cached node immediately; enqueue its new likely successors.
```

## Key interfaces (illustrative pure Dart contracts)

```dart
enum PrefetchStatus { absent, queued, generating, ready, stale, failed }

enum NarrativeAction { tellMore, nextStop, surpriseMe }

class NarrativeNodeKey {
  final String poiId;
  final String segmentKind;   // intro / detail / surprise
  final String contextHash;   // canonical fingerprint of generation inputs
  // Immutable equality and stable serialization.
}

abstract interface class NarrativeCache {
  Future<PreparedNarrative?> get(NarrativeNodeKey key);
  Future<void> put(NarrativeNodeKey key, PreparedNarrative value);
  Future<void> invalidateWhere(bool Function(NarrativeNodeKey) predicate);
}

abstract interface class PrefetchScheduler {
  void schedule(List<PrefetchCandidate> candidates);
  void reprioritize(TourSnapshot snapshot);
  void cancelObsolete(TourSnapshot snapshot);
}
```

`PreparedNarrative` contains: spoken/display text, canonical POI id, segment kind, verified `usedClaimIds`, references to *validated* evidence IDs and URLs, generation timestamp, `sourceRevision`, `promptVersion`, model identifier, status, and an optional locale/voice audio asset path. Cache **only after** semantic validation and source/claim checks. Store the exact context fingerprint that was used, never mutate cached content in place. A failed or incomplete streamed response must never be treated as `ready`.

## Stable cache key and validity

`contextHash = hash(canonical JSON {poi ID, story action, source/evidence revision, already-narrated claim IDs, tour choices, selected interests, language, length, prompt version, model identifier, and any story-specific context})`.

- Avoid precise GPS coordinates in a story cache key when the canonical POI id is sufficient; store only the minimum relevant location context. Do not reuse cached stories across identities unless inputs are equivalent and permission/licensing permit it.
- Account-specific limits and privacy: cached content and narration state are scoped to the current local account/session. Never share OAuth credentials; user data must not leak between accounts or profiles.
- `nextStop` nodes additionally depend on the chosen destination POI and the current planned route revision. Before presenting, verify the next POI is still selected, reachable as planned, and context matches; reroute when necessary.
- Invalidate or mark stale on preference/language change, altered evidence, changed destination/route, materially changed narration history, source revocation, app content revision, or changed photo identification. Evidence-based factual content may be cached longer; routing and ETA information must be recomputed as needed.
- Give records a size bound and TTL appropriate to data stability. Do not claim that AI-generated facts are verified merely because they are cached.
- For a photo-triggered identification, never pre-capture or pre-upload images. Cache photo-specific results only after explicit user consent and only if local storage is enabled; default is ephemeral.

## Scheduling policy and budget

Start with **depth 1** (immediate neighbors), not a fully expanded tree. After the visible segment starts:

1. Highest: `tellMore` for the current POI (likely to be used without a location change).
2. Highest when deterministic: introductory segment for the selected `nextStop` POI.
3. Lower: `surpriseMe` (only if unused verified claims exist).
4. Do not prefetch nonselected branches of future stops or model-generated image explanations for photos that have not been taken.

The two highest priorities may be reversed based on actual tap frequencies and whether the next stop is known. Hard-cap speculative concurrency (initially 1 active speculative request per account), queue length (e.g. 3 candidates), and generated tokens/requests per stop. If the subscription quota is constrained, connectivity is weak, battery is low, data saver is active, or user has paused the tour, suspend prefetch. Do not make paid API calls speculatively when a budget cap is reached. Collect aggregate local counters for discarded branches and approximate resource usage; no analytics upload by default.

Do not cancel a nearly finished speculative task without reason, but invalidate it before promotion if the user changed context. Prefer deduplication/single-flight: if user taps an action currently being generated, **join the in-flight request** and stream progress rather than starting a duplicate. If `ready`, transition without network. If `stale` or `failed`, fall back to ordinary generation with a non-blocking loader or cached offline explanation.

## Interaction and state correctness

Critical invariant: generation is NOT consumption. The current displayed narrative is committed only by a user action and the corresponding state transition. Prepared branches may contain new claims but must not modify global `heardClaimIds` until chosen. When a branch is chosen, commit its claims atomically with the navigation transition; enforce exactly-once `Next` under double taps/retries. If the user tapped `tellMore` and its content is being generated, show a loading/streaming state rather than old text disguised as the answer.

Keep background tasks independent of screen lifecycle where supported by app/runtime policy, but don't overpromise background execution once Android suspends the process. Persist only complete validated content; restore cache and graph snapshot after process death. Avoid recording travel history beyond already agreed minimal POI visit IDs.

## Audio prewarming

For on-device Android TTS, text is the first prefetch target. An optional subsequent optimization synthesizes speech locally when conditions allow and reuses the audio asset; validate language/voice availability, lifecycle, disk usage, and audio focus. Do not assume that TTS audio can always be pre-rendered on all devices. Avoid speculative OpenAI-hosted TTS costs in the personal subscription path.

## Telemetry, tests, acceptance (local only)

Record per transition: request source (`cacheHit`, `joinedInFlight`, `newRequest`, `offlineFallback`), tap-to-first-content, tap-to-first-audio where measurable, prefetch success/failure, wasted branches, cache eviction, number of speculative requests, quota/network errors. No raw geolocation, photos, identities, tokens or prompts in logs.

Tests:
- Cache key changes when source revision, preferences, route next POI, narrated claims or prompt version changes.
- `tellMore` never replays intro claims; unused prefetched branches never mark their claims as narrated.
- Rapid multiple Next taps do not skip multiple POIs.
- A ready, validated node renders without any network call.
- User tap joins one queued/in-flight request without duplicate provider invocation.
- Stale next POI from reroute isn't shown, even if prefetch completed.
- Cancellation, auth expiry, source invalidation, process death, quota, and offline fallback preserve a coherent route.
- Cache does not expose user-specific content between independent profiles.

**Performance targets to measure, not promise:** a validated cache hit switches the text view locally (aim <=150 ms on target phone); >70% of eligible `tellMore` / deterministic `nextStop` actions hit a valid completed cache in long-form tours, after enough uninterrupted listening time. Establish a baseline before setting limits on total speculative-request waste and battery/data consumption.

## Implementation plan

- **M0**: Tour actions and deterministic graph semantics; no network prefetch.
- **M2**: AI response contract emits complete, verified cacheable narrative segments and exposes cancellation / async state; preserve prepared vs consumed separation.
- **After core MVP**: implement `NarrativeCache` and scheduler with fake provider / artificial latency, integration tests and cache metrics; enable behind a feature flag.
- **Later**: production candidate scoring by user behavior, optional local TTS audio prewarming, cross-session reusable content subject to evidence freshness and privacy.

No additional server is required for this on-device approach. Commercial paid-API deployments can reuse this scheduler with a strict per-user cost budget and server-enforced rate limiting.
