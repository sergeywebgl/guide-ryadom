# Starting the first Codex task

## Import provenance

The eight original Markdown files were imported unchanged from `guide-ryadom-codex-starter-updated.zip`. The source archive places ROADMAP.md in docs/. The root ROADMAP.md is an added pointer; this guide is also new. No application code is included.

## Scope precedence

Read every planning file as context: AGENTS.md, README.md, docs/PRODUCT.md, docs/DESIGN.md, docs/PREFETCH.md, docs/ROADMAP.md, docs/DECISIONS.md, ROADMAP.md, and codex/CODEX_KICKOFF.md.

Execute only M0 in CODEX_KICKOFF.md. The README's suggestion to test OAuth in parallel is broader than the kickoff: defer that work to a separate M1 task after review. Prefetch is M7, not M0. External service details in the imported design remain planning assumptions to reverify before M1, not proof of Android support.

## Steps

1. Review and merge the documentation PR, then open an up-to-date checkout of this repository in Codex. Alternatively start from the documentation branch before merge.
2. Create a new implementation branch for M0.
3. Send the prompt below. Keep all files in the repository; there is no need to upload them individually.

## Prompt

Read AGENTS.md, README.md, docs/PRODUCT.md, docs/DESIGN.md, docs/PREFETCH.md, docs/ROADMAP.md, docs/DECISIONS.md, ROADMAP.md, codex/START_HERE.md and codex/CODEX_KICKOFF.md in full. Use all documents as context, but implement only the M0 task and acceptance criteria in codex/CODEX_KICKOFF.md. If other planning text suggests broader work, the kickoff bounds this task: no M1 OAuth spike, live AI/API, GPS/maps, camera recognition or prefetch scheduler. Build the deterministic offline Flutter Android demo with the three Peterborough stops and Russian UI. Preserve the documentation. Verify format, analysis and tests where the toolchain is available; report exact blockers and outstanding device checks. Submit a separate implementation PR and stop at M0 for review.
