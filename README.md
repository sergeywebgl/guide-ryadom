# Гид рядом / Guide Ryadom

A voice-first, location-aware AI walking-tour guide. **Personal open-source prototype** for two separate Android devices, each using its owner's ChatGPT Plus account, subject to account eligibility and current Sign in with ChatGPT restrictions.

**Status:** product and engineering specification, **not yet a compiled Flutter application**. The first Codex task will create it.

## Product promise

Walk around an unfamiliar city; the guide discovers relevant historical places, tells engaging and **source-grounded** stories, explains photographed objects, remembers what it has already said, and offers one-tap actions: **Next stop**, **Tell me more**, **What's this?**, **Surprise me**, **Pause / Listen**.

- Russian-first experience; English later.
- Phone-first, spoken narration with Android TTS.
- No chatbot as the main UI; chat may be an optional expert mode in the future.
- Location/photo permissions are opt-in and contextual.
- Architecture isolates UI, tour engine, content sourcing, AI, maps and device capabilities, so AR glasses can be integrated later.

## Start here

1. Read [PRODUCT.md](docs/PRODUCT.md).
2. Read [DESIGN.md](docs/DESIGN.md), especially the **OAuth feasibility gate**.
3. Read [AGENTS.md](AGENTS.md) (instructions for coding agents).
4. Follow [ROADMAP.md](docs/ROADMAP.md). For future fast next-action responses, see [PREFETCH.md](docs/PREFETCH.md).
5. Paste [CODEX_KICKOFF.md](codex/CODEX_KICKOFF.md) into **Codex** with this repository selected.

## First deliverable

Build a runnable Android Flutter app in **offline demo mode** with the Peterborough Cathedral example and responsive Russian UI. In parallel document and test whether the official Sign in with ChatGPT OAuth loopback callback works on Android. Do **not** pretend subscription inference is working until it is tested on a physical device.

## Technology proposal

Flutter/Dart; clean-ish layered architecture; Riverpod or comparably testable state management; local app storage; Android Text-to-Speech; native platform adapters only where necessary. No backend required for initial prototype. `TourEngine` and `AiProvider` remain replaceable.

## External docs

- [SIWC OSS overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [OAuth registration & sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Models & inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [Codex with GitHub](https://help.openai.com/en/articles/11390924)

**Security:** Never commit user photos, location traces, access/refresh tokens, OAuth codes, client-generated host secrets or `.env` values. Use mocks and sanitized logs.
