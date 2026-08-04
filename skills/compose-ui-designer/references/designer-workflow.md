# Designer Workflow

## Designer Pass

Define:

- The primary user task and the one dominant visual hierarchy
- Information order, density, grouping, and progressive disclosure
- Reused project components, tokens, typography, strings, and assets
- Required loading, empty, error, disabled, selected, focused, hover, and success states
- Mobile reachability, web responsiveness, or desktop resizing and input behavior
- The smallest memorable product-specific choice; avoid a collection of decorative ideas

## Critic Pass

Reject or revise when:

- The direction could belong to any product after changing the logo
- Cards, gradients, pills, badges, oversized headings, illustrations, or glass effects appear without task value
- Hierarchy depends on decoration rather than content priority
- Copy is invented, repetitive, vague, or placeholder-like
- Real state density, long text, errors, keyboard/focus, resizing, or small screens were ignored
- Existing project patterns were replaced without a documented reason and approval path

## Approval Package

Present:

- Screen intent and hierarchy
- Component and token reuse
- Required states and responsive behavior
- Critic findings that were fixed
- Remaining trade-offs or blocked decisions
- A complete screen/state spec ready for `$compose-ui-delivery`
