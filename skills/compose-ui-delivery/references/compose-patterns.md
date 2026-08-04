# Compose Patterns

Resolve implementation choices in this order:

1. Feature-local convention
2. Project design system
3. Shared component pattern
4. Shared Compose Multiplatform source-set pattern
5. Platform-specific project pattern
6. Material default
7. Screen-local inline fallback

## Inspect Before Implementation

- Custom `Text` wrappers and parameter contracts
- `MaterialTheme`, typography, font family, line height, and letter spacing
- Color, shape, elevation, spacing, and motion tokens
- String, localization, and plural-resource conventions
- Shared components and feature-local composables
- State ownership, navigation, lifecycle, and event patterns
- `commonMain` versus platform source-set boundaries
- Existing previews, fixtures, UI tests, browser tests, or desktop test hosts

## Reuse and Source-Set Rules

- Prefer feature-local behavior when the feature already has an established pattern.
- Prefer project tokens and shared components over ad-hoc styling.
- Put genuinely shared UI in `commonMain` only when its API and behavior are platform-neutral.
- Keep platform integration, system chrome, browser APIs, window APIs, and platform-only interactions in the matching source set.
- Do not force Android assumptions into web or desktop implementations.
- Inline values are allowed only when no stronger project convention satisfies the approved spec.

## Impact Approval

Ask before modifying shared components, design-system primitives, dependencies, build configuration, test infrastructure, or shared assets. Document intentional deviations from higher-priority project patterns.
