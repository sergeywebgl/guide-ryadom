# Engineering decisions & open questions

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
