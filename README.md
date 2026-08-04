# Compose UI Skill Catalog

A catalog of focused Codex skills for designing, interpreting, implementing, and verifying Compose UI across mobile, web, and desktop applications.

This repository intentionally exposes separate skills instead of one umbrella `compose-ui-agent` entrypoint:

| Skill | Use it when |
| --- | --- |
| `$compose-ui-reference` | A Figma file, screenshot, mockup, or production capture drives the UI. |
| `$compose-ui-designer` | A product brief needs a project-native UI direction and critique before implementation. |
| `$compose-ui-delivery` | An approved screen/state spec is ready for Compose implementation and rendered verification. |

## Install

Each folder under `skills/` is a self-contained installable skill:

- `skills/compose-ui-reference`
- `skills/compose-ui-designer`
- `skills/compose-ui-delivery`

### User-level installation on Windows

Clone this repository, then copy the three skill folders into the Codex user skill directory:

```powershell
$repo = "C:\path\to\compose-ui-agent-skill"
$skillHome = Join-Path $HOME ".agents\skills"

New-Item -ItemType Directory -Force $skillHome | Out-Null
Copy-Item "$repo\skills\compose-ui-reference" "$skillHome\compose-ui-reference" -Recurse -Force
Copy-Item "$repo\skills\compose-ui-designer" "$skillHome\compose-ui-designer" -Recurse -Force
Copy-Item "$repo\skills\compose-ui-delivery" "$skillHome\compose-ui-delivery" -Recurse -Force
```

For project-scoped installation, copy the same folders into the target repository's `.agents/skills/` directory instead.

Restart the Codex session after installing or updating the folders.

## Usage

### Reference-driven implementation

```text
$compose-ui-reference

Implement the checkout screen from this screenshot for the Android target.
Preserve the existing design system and return rendered evidence.
```

For Figma input, `$compose-ui-reference` delegates design extraction, screenshots, assets, and structured interpretation to the official `$figma-implement-design` skill. It does not duplicate Figma MCP extraction instructions. After normalization, it invokes `$compose-ui-delivery`.

### Design from a product brief

```text
$compose-ui-designer

Design a responsive task list for our Compose web app.
Use real product content and show loading, empty, error, and keyboard-focus states.
```

The required sequence is Designer -> Critic -> explicit approval -> `$compose-ui-delivery`. Production UI must not be edited before approval.

### Delivery only

```text
$compose-ui-delivery

Implement this approved screen spec for Compose Desktop.
Verify 1024x768 and 1440x900 window sizes and return screenshots and functional checks.
```

Use this directly when a screen/state spec is already approved.

## Platform support

### Mobile

- Android: deterministic Gradle assemble/install, Activity or deeplink launch, ADB device discovery, screenshot capture, and evidence metadata.
- iOS: Compose Multiplatform guidance using the project's existing Gradle/Xcode workflow. Simulator or device truth requires macOS, Xcode, and a launchable target.
- Checks include device sizes, insets, keyboard behavior, touch reachability, navigation, semantics, and required states.

### Web

- Compose Web, Kotlin/Wasm, and Kotlin/JS browser tasks.
- Uses project-native Gradle run tasks, a configured browser URL, named viewport captures, responsive checks, focus/keyboard behavior, scrolling, routing, and browser regressions.
- Browser truth requires a running browser build and captured target states.

### Desktop

- Compose Desktop and Compose JVM application tasks.
- Uses a project-native Gradle run task, expected window title, named window-size captures, resizing, pointer/hover, keyboard/focus, menus, dialogs, and dense-content checks.
- Desktop truth requires a running application-window capture.

## Delivery configuration

When discovery cannot determine the target unambiguously, copy:

```text
skills/compose-ui-delivery/templates/compose-ui-delivery.yaml
```

into the target project as:

```text
.compose-ui-delivery/compose-ui-delivery.yaml
```

Select one platform combination for the current verification loop:

```yaml
platform:
  kind: "mobile"
  target: "android"
```

Supported combinations are:

- `mobile/android`
- `mobile/ios`
- `web/browser`
- `desktop/jvm`

Always preview build and launch commands with `-DryRun` before execution.

## Requirements

Core catalog validation requires:

- Python
- PowerShell
- Node.js/npm for repository command aliases
- Pillow for image comparison

Target execution additionally requires the project's normal toolchain, such as Android SDK/ADB, a browser runtime, Compose Desktop/JVM, or macOS/Xcode for iOS.

Install Pillow with:

```powershell
python -m pip install Pillow
```

## Verify this repository

```powershell
npm test
npm run verify
```

The verification suite checks direct skill metadata, official Figma delegation, Designer approval gating, platform discovery, safe Gradle task handling, Android regressions, image comparison, local-link containment, config schema, and production placeholders.

## Safety contract

- Discover project conventions before proposing Compose code.
- Reuse existing components, tokens, strings, and assets before adding new ones.
- Ask for impact approval before dependencies, test infrastructure, shared assets, shared components, or design-system primitives change.
- Use rendered evidence for visual claims.
- Return patches and evidence first. Do not commit, push, or open a PR automatically.
