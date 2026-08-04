# Screen Spec

## Screen

- Name: `ScreenName`
- Route or entry point: `feature/screen`
- Intent: `Primary user outcome for this screen`

## Constraints

- Project design-system requirements: `List the tokens, components, or APIs that must be preserved`
- Text and typography requirements: `List custom Text wrappers, Typography, and string-resource constraints`
- Asset rules: `List required reused assets or state that no new assets are allowed`

## Required States

| State | Trigger | Required UI outcome | Notes |
| --- | --- | --- | --- |
| Default | `Initial ready state` | `Describe the expected layout and content` | `Reference wins for screen-local details` |
| Loading | `Data pending` | `Describe loading treatment` | `Use existing product pattern` |
| Error | `Load or submit failure` | `Describe error content and recovery affordance` | `Keep copy grounded in product language` |

## Optional States

| State | Trigger | Expected UI outcome | Notes |
| --- | --- | --- | --- |
| Empty | `No content available` | `Describe empty state treatment` | `Include only when applicable` |
| Success | `Completed action` | `Describe confirmation treatment` | `Include only when applicable` |

## Functional Checks

- `Primary action is visible and reachable`
- `State-specific text is present`
- `Interactive elements use the expected component semantics`
