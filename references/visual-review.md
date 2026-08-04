# Visual Review

Every visual completion claim must use this workflow.

## Verification Ladder

Use the highest deterministic rung available for the current project and keep climbing until the result is representative:

1. Fixture or preview
2. Screenshot host
3. Deeplink
4. Activity launch
5. `adb` navigation

The emulator is the final visual source of truth. A lower rung can speed iteration, but the last acceptance check must come from the emulator when emulator validation is available.

## Helper Sequence

Run the bundled helpers from the skill root:

1. Discover: `powershell -File scripts/discover-project.ps1 -ProjectRoot . -OutputPath .compose-ui-agent/discovery.json`.
2. When discovery is ambiguous, create `.compose-ui-agent/compose-ui-agent.yaml` from [the config template](../templates/compose-ui-agent.yaml), resolve the missing values with the user, and use that approved file as the source of truth.
3. Preview: `powershell -File scripts/build-and-launch.ps1 -ProjectRoot . -ConfigPath .compose-ui-agent/compose-ui-agent.yaml -DryRun`.
4. Capture one state: `powershell -File scripts/collect-ui-evidence.ps1 -Serial <adb-serial> -OutputDirectory .compose-ui-agent/evidence -State <state>`.
5. Compare: `python scripts/compare-images.py --reference <reference.png> --actual .compose-ui-agent/evidence/<state>.png --output-json .compose-ui-agent/evidence/<state>-diff.json --diff .compose-ui-agent/evidence/<state>-diff.png`.

If a rung or Android tool is unavailable, record the exact failed command and continue only with a clearly labeled lower-confidence result. Do not claim emulator truth without an emulator capture.

## Required Evidence Per State

For each required or optional state under review, capture:

- Reference path or source identifier
- Actual screenshot path
- Image diff artifact or diff metrics
- Rubric scores
- Functional checks
- Fixed issues
- Remaining issues
- Regressions

Record the result with [templates/visual-review.json](../templates/visual-review.json).

## Review Method

- Compare reference and actual screenshots with an image diff.
- Score visual parity with [rubrics/visual-parity.md](rubrics/visual-parity.md).
- Score UX quality with [rubrics/ux-quality.md](rubrics/ux-quality.md).
- Run [rubrics/anti-ai-slop.md](rubrics/anti-ai-slop.md) as a rejection filter.
- Verify core functional checks such as state rendering, text presence, affordance visibility, and interaction reachability.

## Iteration Limits

- Maximum of five adaptive iterations per screen/state review loop.
- Stop early if the score stalls for two rounds in a row.
- Stop early if the same regression repeats for two rounds.
- Escalate unresolved blockers instead of continuing past the cap.
