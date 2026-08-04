# Web Adapter

Use this adapter for Compose Web, Kotlin/Wasm, or Kotlin/JS browser delivery.

## Required Flow

1. Confirm the module, browser Gradle task, expected URL, entry route, and required viewport sizes.
2. Preview the Gradle command with `scripts/build-and-launch.ps1 -DryRun`.
3. Start the project-native browser development task as a managed process.
4. Wait for the configured URL and target screen to be ready; do not treat a successful Gradle start as rendered evidence.
5. Capture every required state in a real browser at named viewport sizes.
6. Treat browser captures and functional checks as web truth.

## Verify

- Responsive reflow at every required viewport and breakpoint
- Horizontal overflow, clipping, sticky/fixed regions, and scroll restoration
- Pointer hover, pressed, selected, disabled, and drag behavior when applicable
- Keyboard navigation, visible focus, tab order, shortcuts, and escape behavior
- Browser zoom and text scaling where required
- Loading, empty, error, offline, long-content, and validation states
- Browser console errors and failed network or asset requests introduced by the patch
- Route refresh, deep-link entry, and back/forward behavior when the feature owns navigation

## Capture Rules

Record browser name/version, viewport width and height, device scale factor when relevant, route, state trigger, screenshot, and functional checks. Reference and actual images must use comparable viewport dimensions before pixel comparison.

If browser automation or screenshot tooling is unavailable, record the exact failed command and provide a lower-confidence result. Do not claim browser truth from preview code or a compiler-only check.
