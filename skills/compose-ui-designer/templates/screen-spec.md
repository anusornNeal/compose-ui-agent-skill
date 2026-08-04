# Screen Spec

## Product Intent

- Screen: `ScreenName`
- Platform: `mobile | web | desktop`
- Primary user task: `One concrete outcome`
- Real content inputs: `Copy, data, limits, and edge cases`

## Project Language

- Reused components and tokens: `Existing project primitives`
- Typography and strings: `Roles and localization rules`
- Existing motifs to preserve: `Only product-supported motifs`
- Explicitly rejected patterns: `Generic or unsupported patterns`

## Direction

- Hierarchy: `Information order and emphasis`
- Interaction model: `Primary, secondary, recovery actions`
- Density and grouping: `Why the composition fits the task`

## Required States

| State | Trigger | Observable UI and interaction outcome |
| --- | --- | --- |
| Default | `Ready state` | `Real content and actions` |
| Loading | `Data pending` | `Project-native progress behavior` |
| Empty | `No content` | `Explanation and next action` |
| Error | `Operation failed` | `Message and recovery path` |

## Responsive and Input Behavior

- Sizes or breakpoints: `Named viewport, device, or window sizes`
- Touch, pointer, keyboard, focus, resize, and scroll behavior: `Platform expectations`

## Critic Result

- UX quality score: `1-5`
- Anti-AI-slop result: `pass | fail`
- Fixed issues: `Concrete revisions`
- Remaining trade-offs: `Product decisions requiring approval`

## Functional Checks

- `Primary task can be completed`
- `All required states are understandable and recoverable`
- `Responsive and input behavior match the selected platform`
