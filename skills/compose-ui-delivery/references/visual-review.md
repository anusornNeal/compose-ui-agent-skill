# Visual Review

Every visual completion claim must include rendered evidence from the selected platform.

## Verification Ladder

Use the highest deterministic rung available and keep climbing until the result represents the real target:

1. Fixture, preview, or isolated component host
2. Existing screenshot or UI test host
3. Project-native route, deeplink, or entry state
4. Running target application
5. Required interaction path to the state under review

Final acceptance truth is:

- Emulator, simulator, or physical device for mobile
- Real browser at named viewports for web
- Running application window at named sizes for desktop

A lower rung may speed iteration but cannot replace an available final target capture.

## Helper Sequence

1. Discover the project with `scripts/discover-project.ps1`.
2. When discovery is ambiguous, create `.compose-ui-delivery/compose-ui-delivery.yaml` from [the config template](../templates/compose-ui-delivery.yaml) and approve the values before execution.
3. Preview commands with `scripts/build-and-launch.ps1 -DryRun`.
4. Build and launch through the project-native workflow.
5. Capture every required state from the selected platform. Android may use the bundled ADB capture and evidence helpers.
6. When a comparable reference image exists, run `scripts/compare-images.py` and save metrics, diff, and optional blend artifacts.
7. Record the result with [the visual-review template](../templates/visual-review.json).

If a tool or verification rung is unavailable, record the exact failed command and continue only with an explicitly lower-confidence result.

## Required Evidence Per State

- Platform and target
- Device, viewport, or window size
- Reference identifier or an explicit statement that no visual reference exists
- Actual screenshot path
- Diff artifact and metrics when a comparable reference exists
- Visual parity score when applicable
- UX quality score and anti-AI-slop result
- Functional checks
- Fixed issues, remaining issues, and regressions

## Review Method

- Compare hierarchy, spacing, alignment, proportion, typography, component sizing, and state-specific content.
- Use [Visual Parity](rubrics/visual-parity.md) only when a visual reference exists.
- Always use [UX Quality](rubrics/ux-quality.md) and [Anti-AI-Slop](rubrics/anti-ai-slop.md).
- Verify state rendering, content presence, interaction reachability, focus/semantics, responsive behavior, and platform-specific checks.

## Iteration Limits

- Maximum five adaptive iterations per screen/state.
- Stop when the score stalls for two rounds.
- Stop when the same regression repeats for two rounds.
- Escalate unresolved blockers instead of weakening the evidence claim.
