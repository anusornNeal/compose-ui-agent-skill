# Screen Spec

## Screen

- Name: `ScreenName`
- Route or entry point: `feature/screen`
- Platform: `mobile | web | desktop`
- Intent: `Primary user outcome`
- Reference source: `Figma node, image path, or capture identifier`

## Project Constraints

- Design-system contracts: `Existing tokens and components to preserve`
- Typography and string rules: `Wrappers, typography roles, localization rules`
- Asset rules: `Existing assets to reuse and additions requiring approval`

## Required States

| State | Trigger | Observable UI outcome | Reference evidence |
| --- | --- | --- | --- |
| Default | `Ready state` | `Layout, content, interactions` | `Source identifier` |
| Loading | `Data pending` | `Project-native loading treatment` | `Source or project pattern` |
| Error | `Operation failed` | `Message and recovery affordance` | `Source or project pattern` |

## Optional States

| State | Trigger | Observable UI outcome | Reference evidence |
| --- | --- | --- | --- |
| Empty | `No content` | `Empty treatment` | `Source or project pattern` |
| Success | `Action completed` | `Confirmation treatment` | `Source or project pattern` |

## Responsive Constraints

- Sizes or breakpoints: `Named viewport, device, or window sizes`
- Reflow and scroll behavior: `Expected adaptation`

## Functional Checks

- `Primary action is visible and reachable`
- `State-specific content is present`
- `Focus, semantics, and interaction behavior match the platform`
