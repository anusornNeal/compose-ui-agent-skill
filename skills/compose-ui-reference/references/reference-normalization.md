# Reference Normalization

Use this workflow for screenshots, mockups, production captures, and other image references that are not already normalized by the official Figma implementation skill.

## Record Observable Facts

- Canvas or viewport size and likely target platform
- Content hierarchy and reading order
- Alignment, spacing rhythm, proportions, stacking, and scroll boundaries
- Visible typography roles, line wrapping, truncation, and emphasis
- Colors, surfaces, borders, elevation, imagery, and icons
- Interactive affordances and visible enabled, disabled, selected, focused, hover, loading, empty, error, and success states
- System chrome, safe areas, keyboard overlap, browser viewport, or desktop window constraints

## Separate Facts From Inference

Mark details as:

- **Observed**: directly visible in the reference
- **Project-resolved**: determined from existing components or design tokens
- **Assumed**: necessary but not visible; keep assumptions minimal and explicit
- **Blocked**: materially ambiguous and unsafe to invent

## Conflict Rules

- Preserve project-wide accessibility, interaction, typography, color-token, and reusable-component contracts.
- Match reference-specific layout and state content when those contracts do not conflict.
- Document intentional deviations instead of silently changing shared foundations.
- Reuse existing assets before requesting or proposing new assets.

## Output

Complete one screen/state spec with exact required states, optional states, responsive sizes, copy, assets, interactions, functional checks, and reference identifiers. Pass that artifact to `$compose-ui-delivery`.
