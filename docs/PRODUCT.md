# Product Requirements — Guide Ryadom

Version 0.1 · 15 October 2026 · Owner: personal/family project

## Vision

An engaging human-like historical guide without chat-first interaction. The app guides real-world walks and responds to observed places/objects, not simply listing Wikipedia snippets. It should be as comfortable to use with headphones and a locked screen as when looking at the map.

## Initial target audience & platform

Two adults, two Android phones, each authenticating **their own** eligible ChatGPT Plus subscription. Initial language Russian. UK historical towns and museums; start with Peterborough Cathedral and surrounding area as a reproducible demo. A commercial release is not in scope.

## Design principles

1. **One-tap interaction** with obvious, large thumb-accessible buttons.
2. **Storytelling before chronology**: begin with a compelling fact, then give concise, historically accurate context.
3. **Evidence before confidence**: separate documented fact, interpretation, local legend, and uncertainty; expose sources.
4. **Respect attention**: quiet by default; no automatic narration for every passing building; opt-in nearby alerts.
5. **Incremental detail**: 'Tell me more' advances the story, never repeats its opening.
6. **Recover from the real world**: GPS drift, weak signal, no internet, screen locked, camera denial, interruptions, low battery.
7. **Private by default**: explicit permissions; no background photo capture; no unnecessary location history.

## Modes

### Free Walk
- On entering app, show current approximate area and nearby interesting POIs.
- A selected POI has a short headline, approximate distance, and one-tap story.
- Suggest the next stop after a story, not immediately whenever location changes.

### Planned Walk
- Duration presets: 30 / 60 / 120 min; walking pace and interests.
- POI selection and walkable route calculated by a routing adapter, with checkpoints and ability to skip / reorder.
- Route can be paused, restarted, or resumed from a persisted checkpoint.

### Camera Explore
- User explicitly chooses 'What's this?' and takes/selects a photo.
- Combine image evidence, approximate location, candidate POIs, available signage/metadata.
- If ambiguity remains, say so or present candidate choices; never confidently identify the wrong building.
- Photos are not retained by default after processing. User must opt in for saved photos.

## Primary tour screen

At top: location, tour label, lightweight step counter / progress. Main object card: title, compelling intro, picture if licensed, reliable citations accessible via 'Sources'. Story text in large readable Russian; prominent **Listen/Pause**.

Primary action **Идём дальше →**. Secondary: **Подробнее**, **📷 Что это?**, **Удиви меня**. Bottom navigation: **Экскурсия**, **Маршрут**, **Настройки**. Avoid modal stacks for simple navigation. Show offline/demo badges explicitly when applicable.

## Responsiveness principle: prepared next actions

While the user reads or listens to a current segment, the app should **opportunistically prepare nearby user-action branches**, especially **Подробнее** and the next known stop. Tapping a prepared branch should produce content immediately, without making a new blocking AI call. Prefetch is optional, budget-limited, and never interferes with the current audio/text or location accuracy. Cached responses must be grounded and context-valid; if stale/missing, show a clear loading state. See [PREFETCH.md](PREFETCH.md). Implementation follows the stable core MVP, but the state model must support it from the start.

## Narrative specification

- Opening story: typically 70–140 Russian words or ~35–70 seconds spoken, adjustable.
- 'Tell me more': ~100–220 *new* words; reference story state and focus on one detail.
- 'Surprise me': a different surprising **verified** fact; no invented drama or invented direct quotes.
- 'Look here': a concrete visual feature, only if actually supported by evidence or clearly marked suggestion.
- Facts have source URLs and claims; 'legend' labelled as legend.
- Use everyday language, memorable people / conflict / consequences / details; no repetitive 'welcome to...' introductions.

## UX states

Ready; permission request; loading/discovering; reading; speaking; paused; no POIs; offline with cached stories; permission denied; approximate/uncertain location; uncertain photo identification; ChatGPT OAuth not connected; OAuth denied/expired; subscription quota reached; network/API error with retry; not supported on device.

## User journeys

1. **First use**: launch -> choose demo or connect ChatGPT -> see Peterborough demo -> listen -> detail -> next -> route.
2. **Outdoor**: grant foreground location -> see nearby POIs -> choose -> story -> listen -> next -> navigate.
3. **Museum**: photograph a label/object -> show identification + confidence/candidates -> learn details -> resume previous tour.
4. **Interrupted walk**: close app during story -> reopen -> return to same POI and last completed segment; do not duplicate narration.
5. **Second device**: spouse installs on own phone, has completely independent login and preferences; no shared credential files.
6. **No account/no network**: demo works fully and offers reconnect later; no dead-end screen.

## Preferences

Interests (history/people, unusual stories, architecture, folklore); narration length; language; voice/TTS speech rate; reduced motion/accessibility; auto suggestions opt-in; background location is off in MVP.

## Non-goals MVP

Commercial billing; own server; real-time multiuser tours; social sharing; public user accounts; training own model; full offline LLM; continuous camera stream; always-on microphone; exact AR world anchoring; publishing to Play Store before privacy/permissions review.

## Quality bar

- No critical crash in scripted 2-hour walk test; robust app restart and connectivity change.
- 'Tell me more' and 'Surprise me' do not substantially repeat last segment.
- Model never fabricates citations; visible citations correspond to retrieved/curated sources.
- Low confidence object detection must not pretend certainty.
- Demo can be run reproducibly without external accounts/services.
- Every main action has accessibility label; text scaling and portrait small screens work.
- Device permissions and outbound photo upload require user action.

## Later AR / wearables

Same `TourEngine` and story memory on the phone. Output adapters: phone UI, audio-only glasses, display-enabled glasses. Input adapters: screen buttons, push-to-talk, glasses camera frames, future gestures. Avoid dependence on a particular Meta API until compatibility is validated. Do not assume precise spatial AR capabilities on audio/camera glasses.
