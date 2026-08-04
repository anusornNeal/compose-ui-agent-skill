# Mobile Adapter

Use this adapter for Compose UI delivered to Android or iOS targets.

## Android

1. Confirm module, variant, package/activity or deeplink, device serial, and entry state.
2. Preview build/install/launch commands with `scripts/build-and-launch.ps1 -DryRun`.
3. Build and install with the project Gradle wrapper.
4. Launch through the configured Activity or deeplink.
5. Capture each required state from the emulator or physical device with the bundled ADB evidence helpers.
6. Treat that device capture as Android visual truth.

Verify:

- Phone and tablet or other required device sizes
- Status/navigation bar insets and edge-to-edge behavior
- Keyboard appearance, IME actions, focus movement, and obscured content
- Touch target size, gestures, back behavior, rotation when supported, and accessibility semantics
- Loading, empty, error, disabled, selected, and success states

## iOS

Compose Multiplatform iOS delivery requires the project's existing Gradle/Xcode workflow and a compatible macOS/Xcode environment.

- Discover `iosMain` and project-native simulator/device tasks.
- Keep UIKit/SwiftUI hosting and Apple platform integration in platform source sets.
- Capture required states from the actual simulator or device when available.
- Do not claim iOS simulator truth when Xcode, the simulator, or the target app cannot be launched.

Verify safe areas, keyboard avoidance, navigation behavior, Dynamic Type or project text scaling, pointer behavior on iPad when applicable, and platform-consistent accessibility.

## Evidence

Record target OS, device profile, dimensions, density or scale, state trigger, actual screenshot, functional checks, and any unavailable platform tooling. Image diff is required when a reference image exists at a comparable size.
