# Desktop Adapter

Use this adapter for Compose Desktop or another Compose JVM application window.

## Required Flow

1. Confirm the module, Gradle run task, expected window title, entry state, and required window sizes.
2. Preview the Gradle command with `scripts/build-and-launch.ps1 -DryRun`.
3. Start the application as a managed process and wait for the expected window.
4. Drive the application to each required state using the least brittle available fixture, route, test host, or interaction path.
5. Capture the application window at named sizes.
6. Treat those window captures and functional checks as desktop truth.

## Verify

- Initial size, minimum size, resize behavior, and layout reflow
- Window chrome, title, menus, dialogs, popups, tooltips, and context menus
- Pointer hover, pressed, drag, scroll wheel, and right-click behavior where applicable
- Keyboard navigation, accelerators, shortcuts, visible focus, escape, enter, and tab order
- Long content, dense data, text scaling, high-density displays, and multi-monitor scale changes when required
- Loading, empty, error, disabled, selected, and success states
- Window close, background/foreground, and restoration behavior owned by the feature

## Capture Rules

Record operating system, scale factor, window width and height, window title, state trigger, screenshot, and functional checks. Capture the application window rather than an unrelated full desktop whenever deterministic window capture is available.

If window discovery or capture tooling is unavailable, record the exact failure and label the result lower confidence. Do not claim desktop-window truth from a Compose preview or successful compilation alone.
