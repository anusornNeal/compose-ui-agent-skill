# Compose Patterns

Resolve styling and component choices in this priority order:

1. Feature-local convention
2. Project Design System
3. Shared component pattern
4. Global majority pattern
5. Material 3 default
6. Inline styling fallback

## Resolver

Before implementation, inspect:

- Custom `Text` wrappers and their parameter contracts
- Project `Typography`
- Font family conventions
- Color token conventions
- Line-height conventions
- Letter-spacing conventions
- String-resource conventions

Then apply the highest-priority matching pattern. Inline styling is allowed only when no stronger convention exists for the screen requirement.

## Reuse Rules

- Prefer feature-local components when the screen already has an established pattern.
- Prefer project tokens over ad-hoc values.
- Prefer shared components over cloning layout behavior.
- Prefer Material 3 defaults over custom inline styling when the project has no stronger convention.

## Escalation Rules

- Ask for impact approval before modifying shared components or introducing new design-system primitives.
- Document any intentional deviation from a higher-priority pattern.
