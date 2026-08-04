# Reference Mode

Use Reference Mode when the user supplies Figma, screenshots, or another concrete UI reference.

## Required Flow

1. Discover the project structure, design system, shared components, custom `Text` wrappers, `Typography`, and local string-resource conventions.
2. Normalize the input into one screen/state spec.
3. Resolve Compose patterns through [compose-patterns.md](compose-patterns.md).
4. Reuse existing assets and components before proposing new ones.
5. Implement the smallest screen-local patch that satisfies the spec.
6. Run [visual-review.md](visual-review.md) and score it with the shared rubrics.

## Decision Rules

- Reference layout wins for screen-local details such as spacing, alignment, proportions, stacking, and state-specific content.
- Project design-system contracts win for global behavior such as typography tokens, colors, interaction semantics, accessibility, motion, and reusable component APIs.
- If a reference conflicts with a design-system contract, preserve the global contract and document the conflict.
- Asset reuse happens before proposing new icons, illustrations, or imagery.

## Guardrails

- Do not change infrastructure, dependencies, assets, or shared components without explicit impact approval.
- Do not claim parity from a code read alone; visual claims require visual-review evidence.
- Do not commit, push, or open a PR automatically.
