---
name: compose-ui-designer
description: Use when a Compose mobile, web, or desktop UI needs a new project-native design direction from a product brief rather than a fixed visual reference.
---

# Compose UI Designer

Use this skill to turn a product brief into an approved Compose screen/state direction before implementation.

## Mandatory Sequence

1. Discover the project structure, target platform, design system, shared components, typography, strings, assets, and adjacent feature patterns.
2. Normalize the brief into [the screen spec](templates/screen-spec.md) with real content, required states, responsive constraints, and functional checks.
3. **Designer** proposes one focused direction that fits the product and explains hierarchy, interaction model, density, component reuse, and platform adaptation.
4. **Critic** reviews it using [the designer workflow](references/designer-workflow.md), [UX quality](references/rubrics/ux-quality.md), and [anti-AI-slop](references/rubrics/anti-ai-slop.md).
5. Revise until the proposal passes the critic or clearly reports unresolved product decisions.
6. Present the direction and critique summary for explicit user approval.
7. Only after explicit user approval, invoke `$compose-ui-delivery` with the approved spec and selected platform.

## Hard Rules

- Designer -> Critic -> explicit user approval -> `$compose-ui-delivery` is mandatory.
- Do not edit production UI before approval.
- Reuse existing components and assets before proposing new primitives.
- Do not invent product language, decorative motifs, gradients, cards, badges, or illustrations without product intent.
- Ask for impact approval before dependencies, infrastructure, shared components, or shared assets change.
- Do not commit, push, or open a PR automatically.
