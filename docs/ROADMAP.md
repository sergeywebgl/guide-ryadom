# Roadmap and acceptance criteria

Use short Codex tasks/PRs, each independently reviewable. A milestone is only done after its acceptance criteria are demonstrated.

## M0 — Executable UI and isolated domain (first Codex task)

- Scaffold Flutter stable Android project, package/module boundaries consistent with design.
- Russian-first Material 3 phone interface with Demo Tour, Route, Settings tabs.
- Bundled deterministic Peterborough tour with 3 stops; story, detail, 'Next', 'Surprise me' (curated in fixture), sources, voice action (mock or actual platform TTS depending available SDK).
- Implement `TourAction` and in-memory `TourEngine`, mock AI/location/photo providers, no network calls.
- Demonstrate proper state: stopping at 3rd stop, start over explicitly rather than silently looping; skipping/returning; user-controlled playback; loading/errors.
- Widget tests verify next/more/route/settings, text scaling; pure Dart tests verify tour progression and no repetition.
- README commands, repo formatting, analysis; Android manifest includes only permissions actually required by implemented functionality.
- **Deliverable:** screenshots and runnable app or explicit SDK environment limitation, tests green where SDK available.

## M1 — Android ChatGPT plan OAuth feasibility spike (separate PR)

- Implement documented OIDC/PKCE and loopback listener behind a feature flag and public `AuthProvider` interface. Validate state, nonce, issuer/JWKS/audience, granted scopes, dynamic issued client ID, stable host ID.
- System browser flow on physical Android phone, actual callback handling across app switching/return; no WebView or undocumented redirect workaround.
- Secure storage and serialized rotating refresh token flow; revoke/logout, error recovery.
- After successful auth call models listing; issue **one** real streaming Responses request using allowed fields and report success/error. Verify `response.completed` event.
- Repeat independently on a second phone/account; note this requires each owner's participation and consent (Codex cannot access their accounts).
- **Gate:** if loopback scheme is impossible or unsupported on Android, pause SIWC integration, keep M0 demo functional, document options and request decision rather than using hacks or paid API automatically.

## M2 — First real historical story

- Versioned `AiProvider` + SIWC Responses SSE parser, cancellation, quota/auth/network handling.
- Curated Peterborough sources + evidence/claim IDs; model requests use verified facts, return structured segments and original valid source references.
- 'Tell me more' receives prior claim IDs and must add novel content; 'Surprise me' only from unused verified facts.
- End-to-end manual comparison of demo vs real AI story, quality feedback.
- **Done:** user can sign in, choose one curated stop, get a grounded streaming story and progress to a distinct follow-up.

## M3 — Location and discovery

- Foreground GPS permission/accuracy; nearby results via pluggable adapter.
- Geographic deduplication; explicit error/offline behavior; local cache and source attribution.
- No geolocation without permission; never misrepresent mock position.
- **Done:** test on an actual UK street, identify several real nearby POIs and show uncertainty appropriately.

## M4 — Camera identification

- User-initiated camera/gallery import; image downsizing and EXIF minimization; consent, cancellation, secure temporary handling.
- Candidate identification using image+location+POI context; uncertainty UI; historical explanation with evidence; no fabricated source URLs.
- **Done:** indoor objects and near-identical adjacent buildings yield either verified selection or explicit ambiguity.

## M5 — Spoken guided walk

- Russian Android TTS, audio focus, pause/resume/interruption handling, test with screen locked on actual phones.
- Walking route adapter and next-stop planning with real pedestrian directions, cache and ETA only from route engine.
- **Done:** scripted >60-minute device walk with no critical navigation, playback, state or privacy bugs.

## M6 — Reliability, UX polish and glasses-readiness

- Offline-first caches, robust process death, accessibility/localization, battery tests, crash/quality feedback (opt in).
- Input/output interfaces for hands-free wearables; investigate currently supported Meta/Android XR devices separately.
- **Done:** repeatable ~2-hour unfamiliar-city field trial on two users' phones; collect failures and measurable quality reviews.

## M7 — Speculative graph prefetch (post-core-MVP performance milestone)

- The domain state from earlier milestones distinguishes **prepared** narrative nodes from **consumed** narrative history. Implement `NarrativeCache` and `PrefetchScheduler` following [PREFETCH.md](PREFETCH.md).
- While intro is displayed/playing, asynchronously prepare `tellMore` and deterministic `nextStop` at depth 1; queue `surpriseMe` only when quota/budget allows.
- Deduplicate concurrent requests, support cancellation/reprioritization, validate cache keys after location/route/preferences change, never fabricate facts.
- Bounded cache/TTL and per-account quota-safe speculative request budget; measurable cache-hit ratio, wasted generations, tap-to-content latency, quota impact.
- Unit and integration tests for cache hit without network, join-in-flight, stale routing result, repeated taps, narration memory, account isolation, offline and process death.
- **Done:** on two Android devices, frequently used precomputed transitions happen without waiting for AI; valid cache-hit transitions aim for <150 ms in local UI. All claims and geo routing remain correct even when prefetch is disabled. Feature flag allows side-by-side comparison.

## Commercialization (out of scope)

- Decision based on real retention, engagement, factual quality, operating cost; backend for paid API key storage, compliance/licensing/privacy, billing and distribution as separate future design.
