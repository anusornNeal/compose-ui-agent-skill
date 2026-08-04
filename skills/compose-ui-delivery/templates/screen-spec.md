# Screen Spec

## Screen

- Name: `ScreenName`
- Route or entry point: `feature/screen`
- Platform: `mobile | web | desktop`
- Target: `android | ios | browser | jvm`
- Intent: `Primary user outcome`

## Constraints

- Project design-system requirements: `Tokens, components, or APIs to preserve`
- Text and typography requirements: `Wrappers, typography, localization rules`
- Asset rules: `Assets to reuse and additions requiring approval`
- Platform integration: `Insets, browser, window, or input constraints`

## Required States

| State | Trigger | Observable UI outcome | Functional outcome |
| --- | --- | --- | --- |
| Default | `Ready state` | `Layout and content` | `Primary task works` |
| Loading | `Data pending` | `Progress treatment` | `Duplicate actions blocked` |
| Error | `Operation failed` | `Message and recovery affordance` | `Recovery works` |

## Optional States

| State | Trigger | Observable UI outcome | Functional outcome |
| --- | --- | --- | --- |
| Empty | `No content` | `Explanation and next action` | `Next action works` |
| Success | `Action completed` | `Confirmation treatment` | `Result is reflected` |

## Responsive and Input Matrix

| Size or profile | Expected reflow | Input and focus checks |
| --- | --- | --- |
| `Named device, viewport, or window` | `Layout behavior` | `Touch, pointer, keyboard, focus` |

## Evidence Requirements

- Reference identifier: `Image, Figma node, or none`
- Actual capture for each required state
- Image diff when a comparable reference exists
- Platform-specific functional checks
