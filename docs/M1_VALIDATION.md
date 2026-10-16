# M1 — official ChatGPT OAuth Android proof of concept

## Status and feasibility

### M1.3 foreground exchange (1.1.3+5)

Build evidence: [successful run 38904887835](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38904887835), code commit `94d66e4e692a35bdf27f4d1ffdaec5303df72414`. Formatting, analysis, 65 tests and Android debug build passed. Artifact: `guide-ryadom-m1-debug`. Physical retry pending.

Owner reports identical `M1.2 / exchange / network / socket / os=7` on home Wi-Fi and mobile data, with no VPN or filtering. The home-network hypothesis is not supported, and replacing the HTTP pool did not resolve the observed failure. Numeric Android resolver code 7 is associated with EAI_NODATA, but the diagnostic does not prove why name lookup failed.

Inspection found that callback arrival immediately triggered token exchange while the system browser could still own the foreground. M1.3 waits for Flutter's `resumed` lifecycle state after callback validation and listener shutdown, before creating the fresh exchange client or sending the code. Return from the browser page to the app within one minute; waiting is cancellable and times out safely. The code is never automatically replayed. No foreground service, battery-exemption request, DNS override, hardcoded IP or certificate bypass was added.

A service regression test failed before this wait was connected and passes afterward. Tests cover no token POST before resume, exactly one after resume, cancellation before resume with no POST, the actual Flutter lifecycle adapter (paused/hidden/inactive/resumed), timeout and listener cleanup. All 65 tests pass locally. This proves corrected sequencing, **not that background restrictions caused this phone's socket error**; physical authentication and inference remain pending.

References: [Flutter lifecycle listener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html), [Android background restrictions](https://developer.android.com/develop/background-work/background-tasks/bg-work-restrictions). Android documents that restricted apps may lose background network access; no such setting has been confirmed on the owner's device.

### M1.2 connection isolation (1.1.2+4)

Build evidence: [successful run 38902996583](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38902996583), code commit `c61fc53408942a1e8d8bee032f9a5c9e99b7f682`. Formatting, analysis, 60 tests and Android debug build passed. Download `guide-ryadom-m1-debug` from this run. Owner device retry pending.

Owner supplied the actual M1.1 diagnostic: `exchange / network / socket`. Callback validation and listener shutdown were therefore reached; no completed token exchange is established. A socket exception alone does not identify DNS, reset, connectivity policy or reuse of an old connection.

The first hypothesis under test is reuse of the pre-browser metadata client's connections after consent/backgrounding. [Dart documents persistent connection caching](https://api.dart.dev/dart-io/HttpClient-class.html). A fault-injection test modeled a socket failure when the same client was used before and after the browser round trip; it failed before the change and passes afterward. This is a synthetic regression, **not reproduction of the owner's actual network condition**.

M1.2 closes that client and creates a fresh client/pool after validating the callback, before sending the code exactly once. Cancellation and final cleanup target the new client. Token endpoints, PKCE, TLS certificate verification and ID checks are unchanged. No automatic retry of authorization codes was added. Diagnostics now also include the numeric socket OS error when available, without its message, address, port or URL, to distinguish remaining network failures. Retry on the phone is required; this is a mitigation for a plausible cause, not a confirmed resolution of the owner's issue.

### M1.1 diagnostic follow-up (1.1.1+3)

Owner observed successful browser consent and the loopback page “Ответ получен. Вернитесь в приложение…”, followed by the app's “Сетевая ошибка. Повторите позже.” without HTTP status. This confirms browser delivery to the listener on that attempt, **not** successful callback parameter validation, token exchange, storage or inference.

A regression test reproduced a diagnostic defect: an internal StateError during exchange was mislabeled as a network outage. M1.1 fixes that classification and adds safe enum-only operation-stage/cause codes, visible in Settings with “Копировать код ошибки”. Socket, TLS, HTTP client, timeout and internal failures are distinguished; JWKS download failures retain their network stage instead of appearing as invalid identity. No exception messages, stack traces, URL/query values, tokens, email or server bodies enter these codes. Cleanup also releases the operation lock if closing a resource fails.

**The owner's underlying sign-in failure is not yet diagnosed or fixed.** Synthetic failures verify the diagnostic mechanism, not the cause on the phone. Retry with the M1.1 APK, confirm the account heading says M1.1, then copy the error code if login fails. Examples such as `M1.1 / exchange / network / socket` are illustrative, not observed phone results. No OAuth checks or TLS verification were weakened, no code exchange is automatically retried and no alternate endpoint was added.

Local checks: formatting, analysis and 58 tests pass. The failing diagnostic regression was observed before the fix and passes afterward. [M1.1 CI run 38901787135](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38901787135) passed formatting, analysis, 58 tests and Android debug build for code commit `e957be17e13469d044a1efa3075fa3d6f68850fd`; download artifact `guide-ryadom-m1-debug` from this run for version 1.1.1+3. Physical login and inference remain pending.

M0 was installed and smoke-tested successfully on a real Android phone **according to the owner**. No additional M0 device tests are claimed.

M1 code implements the documented flow. Android device authorization, callback delivery, secure-storage behavior and a real subscription-funded completed response are **pending owner testing on both phones**. Do not mark M1 technically complete until those checks pass.

Official documentation reviewed on 16 October 2026:

- [OSS overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [Registration and sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Profiles and sessions](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [Token reference](https://developers.openai.com/siwc/token-sharing-open-source/token-reference)
- [Errors and recovery](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery)
- [Public OIDC metadata](https://auth.openai.com/.well-known/openid-configuration)
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore)

The documented redirect is `http://127.0.0.1:<port>/auth/callback`; the listener must exist before browser authorization. No custom-scheme or localhost substitution is documented. The reviewed pages did not establish a categorical Android prohibition, but also did not establish reliable behavior on these two phones. A Dart IPv4 loopback server and Android system browser can implement the stated contract; whether Android keeps the process alive and the browser reaches it is a **device feasibility question**, not a proven capability. No alternative redirect, cookie extraction, embedded WebView, private backend endpoint or impersonated client was added.

If OpenAI rejects the mobile flow, the browser cannot reach loopback, or OS lifecycle prevents reliable completion, record the exact sanitized error, browser/device versions and step. Stop live integration at that decision point. Supported directions for review are keeping the offline app, moving the documented loopback flow to a compatible desktop environment, or separately approving a properly hosted paid-API architecture. Neither a mobile redirect workaround nor a paid fallback is enabled.

## Implemented

- Pure Dart `AuthProvider` boundary; account controller and UI separate from TourEngine. `ENABLE_CHATGPT_AUTH` defaults to true; false builds retain the offline-only interface.
- Dynamic registration starts with `dynamic_agent_client` and the actual application name. Returning accounts use their validated issued client ID. Callback client IDs are checked against the selected registration. Mappings use client ID plus validated subject, never email as identity.
- Per-install UUIDv4 host identifier persisted in Android no-backup storage. Each phone keeps independent credentials and mappings.
- Secure random state, nonce and verifier; PKCE S256; exact loopback URL reused during token exchange; duplicated/incorrect callback parameters and mismatched state rejected. Access-denied callbacks are also state-checked.
- OIDC metadata from the official issuer, trusted issuer JWKS only, RS256 signature validation, issuer/audience/authorized-party/expiry/issued-at/nonce/subject checks. Refresh ID tokens, when returned, are signature and identity checked too. ID tokens are never treated as access tokens.
- Only token-response scopes authorize inference; direct usage and resource invocation are required. Callback scopes are not trusted. Missing permission keeps the signed-in account visible and disables inference.
- AES-256-GCM credential file, Android Keystore non-exported key, atomic writes, no Android backup. Crypto and storage run on a native worker thread. Codes and PKCE values are transient. App diagnostics use fixed safe messages, never raw URLs, tokens or provider error bodies.
- One operation at a time prevents concurrent refresh-token use. Before refresh, a session tombstone is saved; only a complete replacement token set is saved afterward. A crash, failed storage write or ambiguous interrupted refresh requires new sign-in rather than reusing a potentially rotated token. The registration is retained. This intentionally favors correctness over seamless recovery.
- Logout attempts official revocation, then clears local credentials while retaining host and account registration. A failed remote revocation is explicitly reported. A storage failure is an error, never a claim that persistent credentials were deleted; see recovery below.
- Cancellation and three-minute callback timeout, bounded HTTP/stream waits, listener cleanup. Switching apps does not cancel login by itself. Android process death discards an unfinished authorization; retry from the app. No foreground service or background execution guarantee.
- Settings: disconnected/connecting/connected/error, validated account label, available-scope explanation, connect/reconnect/disconnect, account model discovery and a diagnostic result area.
- Model discovery uses the documented `models` array, eligible `visibility: list` entries in server order. No model name is assumed. One explicit button sends the requested Russian cathedral prompt to public `/v1/responses`, with an input array, `stream:true`, `store:false`. No production historical generation.
- SSE handles split UTF-8/network chunks, multiple data lines, deltas and safe errors. Only a valid `response.completed` with completed status and output text marks success. Failed/incomplete/EOF/[DONE] alone never succeeds. Partial text remains visibly unconfirmed.

## Automated evidence

Local toolchain: Flutter 3.47.7 / Dart 3.13.5 on Windows. Tests use synthetic identities, ephemeral test signing keys and mocked HTTP; no owner's account, token or paid key is used.

Checks run: formatting (20 files, no changes), `flutter analyze` (no issues), `flutter test` (**51 passed**). Coverage includes the RFC7636 PKCE vector, secure-value shape/uniqueness, callback origin/state/client/duplicates, denied login, nonce and other signed-claim failures, invalid signature, unusable token responses, failed exchange, cancel/timeout, serialized operations, refresh rotation and failed persistence, scope restrictions, local logout despite failed revocation, independent account state, streamed responses and HTTP failures, missing completion, account UI/logout, 320px/200% text, and original offline regression tests. A real local loopback socket test verifies listener/path behavior on the test host; it is **not an Android browser test**.

Local `flutter build apk --debug` was attempted and stopped with `No Android SDK found`. The existing GitHub Actions workflow completed successfully: [M1 run 38898910026](https://github.com/sergeywebgl/guide-ryadom/actions/runs/38898910026), code commit `bd8cbe777d3e00ecd7e3252ffd7840556178ad63`. Formatting, analysis, all 51 tests, Android debug build (including Kotlin bridge) and artifact upload passed. Download `guide-ryadom-m1-debug` from that run. Compilation does not prove live authorization or Keystore operation on a physical phone.

The successful workflow reports maintenance warnings about older action versions and an upcoming `ubuntu-latest` image migration. These did not fail this build; workflow modernization is a separate maintenance task.

## Owner's installation and acceptance checklist

1. Open [workflow runs](https://github.com/sergeywebgl/guide-ryadom/actions/workflows/flutter.yml). Select the successful M1 run, download `guide-ryadom-m1-debug`, unzip, and install `app-debug.apk` (version 1.1.0+2). This is a debug APK. CI debug signing can differ between runs: if Android rejects an update because signatures differ, uninstall the old debug app first. Uninstalling clears local credentials, mappings and host ID; for an already connected M1 build, disconnect first, or revoke access in ChatGPT settings. Do not uninstall merely because OAuth fails.
2. Record phone model, Android version and system-browser name/version. Launch in airplane mode and check the three-stop offline demo, More, Next, Back and Settings. Sign-in is optional.
3. Enable internet. Open **Настройки → Аккаунт ChatGPT · M1 → Подключить ChatGPT**. The system browser should show the official OpenAI sign-in/consent flow for Guide Ryadom. Choose that phone owner's eligible ChatGPT Plus account. Confirm the plan-sharing permission in the official consent screen. No API key should be requested by the app.
4. After consent, the loopback page says to return to the app. Use Android's app switcher. Check **Подключён**, the expected account label and the model list. If the browser returns without a callback, wait at most three minutes or tap **Отменить**, then retry. Do not copy the callback URL or tokens into chat/logs.
5. Select one of the discovered models (first is selected automatically) and tap **Отправить тестовый запрос**. The prompt is: «Расскажи один интересный и общеизвестный факт о Питерборском соборе в двух предложениях.» Wait for **Ответ завершён · response.completed** and generated text. Partial text, an error, or a closed browser is not success. The fact is not source-validated; this is only a connectivity test.
6. Test cancellation/denied consent; browser Back without consent; switching apps and short backgrounding during login; airplane mode during login and during a request; quota/permission errors if naturally encountered. Never consume quota intentionally just to provoke an error. Confirm no failed request is marked completed and the offline tour still works.
7. Close/reopen the process after successful login. Verify stored identity returns, load models and repeat the explicit request. Later, after the access token expires, check refresh. A failed/interrupted refresh may require sign-in again by design. Do not change the device clock to simulate expiry.
8. Tap **Отключить аккаунт**. Check disconnected state, no old diagnostic text, and sign-in required for GPT. Relaunch and verify credentials do not return. If server revocation was not confirmed, remove this application's access in ChatGPT settings; the app provides a Usage link to copy. If secure storage reports a failure, persistent deletion is not confirmed: revoke remotely and clear this app's Android storage before retrying.
9. Repeat independently on phone two with its owner's account. Verify signing out on one phone leaves the other connected. No credential export or copying between phones.

Report only: device/browser versions, exact step, sanitized visible error, whether completed response appeared, and logout result. Do not send passwords, authorization URLs/codes, access/refresh/ID tokens or full network dumps.

## Acceptance record

| Requirement | Evidence |
| --- | --- |
| Android compilation/APK | Passed in run 38898910026, artifact guide-ryadom-m1-debug |
| Offline demo | M0 owner smoke test confirmed; M1 automated regression passes; M1 device regression pending |
| Browser initiation and loopback result on Android | Owner reached consent and the callback return page on one phone; subsequent sign-in failed; second phone pending |
| Real token/identity/scope validation | Mocks pass; live account pending owner |
| Eligible model and completed streamed GPT response | Mocks pass; live account pending owner |
| Result visible in app, cancellation and logout | Widget/service tests pass; physical device pending owner |
| Two-phone independence and Keystore persistence | Architecture/mocks only; physical devices pending owner |

M2, real GPS, camera, audio, production historical narration and speculative prefetch are not part of this change.
