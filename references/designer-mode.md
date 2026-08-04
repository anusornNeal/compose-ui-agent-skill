# Designer Mode

Use Designer Mode when the user wants a new Compose UI direction from a brief rather than a fixed visual reference.

## Required Sequence

1. Discover the project structure, design system, shared components, custom `Text` wrappers, `Typography`, and local string-resource conventions.
2. Normalize the brief into one screen/state spec with constraints, required states, and optional states.
3. **Designer** proposes a screen-local direction that fits the project design system.
4. **Critic** reviews the proposal against [anti-ai-slop.md](rubrics/anti-ai-slop.md), [ux-quality.md](rubrics/ux-quality.md), and the discovered project conventions.
5. Present the proposal and critique summary to the user.
6. Wait for explicit user approval.
7. **Implementer** creates the patch only after approval.
8. Run [visual-review.md](visual-review.md) and score it with the shared rubrics.

## Hard Rules

- Designer -> Critic -> user approval -> Implementer is mandatory.
- No production UI edits before user approval.
- Anti-AI-slop checks are required before presenting a design direction.
- Reuse existing components and assets before proposing new ones.
- Do not change infrastructure, dependencies, assets, or shared components without explicit impact approval.
- Do not commit, push, or open a PR automatically.
