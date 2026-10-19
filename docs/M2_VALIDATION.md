# M2.0 — first evidence-backed story

Version 1.2.0+10. Authorized by the owner on 19 October 2026 after tentative M1 success. This is the first M2 implementation, not physical-device acceptance.

## Implemented

- Tour screen opens **История с GPT · Питерборский собор**. The offline demo remains independent.
- One curated stop, seven claim IDs and two locally maintained source URLs. Three nonoverlapping fact groups: construction/introduction, transition from abbey to cathedral/More, ceiling and vaulting/Surprise.
- `NarrativeProviderV1` separates narration from OAuth and TourEngine. The existing authenticated Responses transport handles custom prompts, cancellation, refresh, errors and completed streaming. No paid API key or backend.
- Explicit per-tap requests only. A Russian prompt includes the versioned selected evidence and already consumed IDs, requests JSON with text/claimIds/sourceIds, and forbids unsupported elaboration. No preview-specific structured-output parameter is assumed.
- Incremental character progress is shown during streaming; raw JSON and unchecked partial prose are not shown as a story. After valid completion, the application validates structure, nonempty bounded text, exact selected claim/source sets, duplicates and embedded HTTP URLs. Source buttons always use local catalog URLs, never generated URLs.
- Only successfully validated displayed stories consume claims. Errors and cancellations leave history unchanged. Repeated taps are serialized. Account changes clear history; closing the screen cancels its request and discards its local history. No persistent story cache or prefetch.
- Detailed structural transport diagnostics remain available, without prompts, generated text or secrets.

## Evidence review

Reviewed 19 October 2026; Russian fact paraphrases are original and intentionally short.

| Claim | Source and supporting location |
| --- | --- |
| fire: fire in 1116 | [Cathedral history](https://peterborough-cathedral.org.uk/about/history/), timeline 1116 |
| building: construction begins in 1118 | Same timeline entry |
| consecration: church consecrated in 1238 | Same timeline, 1238 |
| dissolution: abbey dissolved in 1539 | Same timeline, 1539 |
| cathedral: cathedral and bishop established in 1541 | Same timeline, 1541 |
| ceiling: painted wooden nave ceiling | [National Churches Trust](https://www.nationalchurchestrust.org/church/peterborough-cathedral), interior highlights; cathedral history also describes wooden ceiling |
| vaulting: fan vaulting in the new building | National Churches Trust, interior highlights |

The source's inconsistent early foundation dates are not included. No legends or invented quotations are in this evidence packet.

## What validation does not prove

Checking IDs and structure does **not** prove every sentence is entailed by the evidence. The model can still introduce unsupported phrasing or repeat a fact in prose despite correct IDs. The UI states this and exposes the original facts for comparison. Manual quality review remains required; do not describe generated prose as automatically fact-verified. Invalid JSON fails visibly without an automatic quota-consuming retry. Stories are shorter than the eventual production targets because this evidence packet is deliberately small.

## Automated verification

Local formatting, analysis and **103 tests** passed. [GitHub Actions run 39336901614](https://github.com/sergeywebgl/guide-ryadom/actions/runs/39336901614), code `e7420294c762e46b3332275524a2885e49c15d7a`, also passed formatting, analysis, all 103 tests and Android debug build. Artifact: `guide-ryadom-m2-debug`, version 1.2.0+10. M2 device and narration-quality checks remain pending.

Local formatting, Flutter analysis and tests are run; build evidence is recorded below after CI. Tests cover claim/source validation, unknown and duplicate IDs, malformed version/text/URLs, cancellation with late response, repeated taps, failure/retry, novel follow-up, account cleanup, UI/source actions and 320px/200% layout. Existing OAuth, SSE and offline tests remain. No live request or physical-device test was performed by the agent.

## Owner checklist

1. Install the M2 APK. If Android rejects debug signing, follow the uninstall/revoke caveat in M1_VALIDATION.md; uninstall clears local credentials.
2. If needed, connect ChatGPT in Settings. Open **Экскурсия → История с GPT · Питерборский собор**. Load available models and select one.
3. Tap **Начать рассказ** once. Wait for a story card; check it uses the three construction facts and no invented details. Expand **Факты для сверки**, copy a source link and compare.
4. Tap **Подробнее**, then **Удиви меня**. Each is a separate use of plan quota. Check distinct facts, readable Russian and source links. After all groups, buttons disable with an exhaustion message.
5. Cancel a request or interrupt network. Existing stories must remain and the failed request must not consume its facts; retry only deliberately. On failure copy **Диагностика рассказа → Копировать отчёт рассказа**.
6. Return to the offline tour and use it without network. Reopening the AI page intentionally starts a fresh history. Confirm this limited lifecycle is acceptable before adding persistence.

Pending: actual model JSON compliance, historical faithfulness/quality, cancellation on Android, second-account testing. No GPS, camera, audio, prefetch or M3 work is included.
