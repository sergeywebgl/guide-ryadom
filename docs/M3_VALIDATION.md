# M3.1 — foreground location measurement

Version 1.3.1+11, 20 October 2026. This is only the location part of M3, not nearby discovery. M2 phone smoke test was confirmed by the owner.

## Implemented

- Экскурсия → Места рядом → Определить местоположение. Opening the app/page does not ask for location.
- Separate pure Dart DeviceLocation port, Android geolocator adapter and controller. No change to demo location, tour engine, evidence or ChatGPT requests.
- COARSE/FINE permissions; approximate access is accepted and labelled. No background location or foreground-service permission/configuration.
- A short-lived subscription stops after the first valid measurement, error, 45-second deadline, cancellation, page disposal or app backgrounding. Inactive alone is ignored because Android permission dialogs can make the activity inactive.
- Reject nonfinite/out-of-range coordinates, negative accuracy, measurements older than 30 seconds or more than 5 seconds in the future. Display device accuracy and measurement time; mark mock Android positions. A snapshot does not track subsequent movement.
- Safe messages for denied/blocked/disabled/timeouts/errors; settings buttons do not automatically restart measurement on return. Late permission results after cancellation are ignored.
- Coordinates are in page memory only, never persisted, logged, copied or sent by this application. Android location services may themselves use network-assisted positioning. No promise of indoor or offline fix availability.

## Automated verification

Tests cover freshness/invalid fixes, permission outcomes, approximate fixes, duplicate taps, cancellation with late permission, timeout, stream failure/early close, background cancellation and 320px layout with 200% text. Existing offline and authentication/story regressions remain in the suite.

Final check and build results are recorded after CI completes. No physical-device M3 tests have been performed by the agent.

## Owner checklist — pending

1. Install the APK, preserving the existing installation if Android permits. Different debug signing between CI builds can require uninstall/reinstall (which clears stored login).
2. Without signing in, open Экскурсия → Места рядом. Verify no permission prompt until tapping Определить местоположение.
3. Grant permission while using the app. Outdoors, verify plausible coordinates, accuracy and time. Never send actual coordinates in a public issue.
4. Tap Обновить измерение. Verify a fresh result; walking alone should not silently update it.
5. In Android app settings switch to approximate permission, repeat and verify the approximate label. On Android versions without that choice, skip this step.
6. Deny permission; verify useful message and offline demo still works. If Android blocks further prompts, open Настройки разрешений and restore access.
7. Disable system location; verify the settings action. Return and explicitly tap to retry.
8. Cancel while waiting; start again, background the app, return. Verify no automatic restart or late coordinates. Leave the page while waiting and verify it stops.
9. If no fix is available, confirm the 45-second timeout. Do not change network configuration just to provoke it.
10. Recheck offline Peterborough controls and the previously working GPT story. Repeat relevant checks on the second phone; no device results are assumed.

Next milestone M3.2: choose/document a licensed nearby-places source and build attributed results with geographic deduplication. No map, real nearby POIs, GPS-generated stories, audio, camera or speculative requests are included here.
