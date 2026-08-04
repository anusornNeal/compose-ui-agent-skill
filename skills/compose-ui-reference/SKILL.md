---
name: compose-ui-reference
description: Use when a Compose UI task has a Figma, screenshot, mockup, production capture, or other concrete visual reference that must be normalized before project-native implementation.
---

# Compose UI Reference

Use this skill to turn a concrete visual reference into one implementation-ready screen/state spec.

## Input Routing

- **Figma**: invoke `$figma-implement-design` first. Treat its design context, screenshot, assets, and component mapping as the normalized source. Do not duplicate Figma extraction calls in this skill.
- **Screenshot, mockup, or production capture**: follow [reference normalization](references/reference-normalization.md).
- **Mixed input**: use Figma as the structured source and other images as supplemental state or regression evidence.

## Required Flow

1. Identify the target screen, state, platform, and reference source.
2. Inspect the existing project design system, shared UI, typography, strings, and feature-local patterns before proposing code.
3. Normalize the request into [the screen spec](templates/screen-spec.md), including required states, responsive constraints, assets, copy, interactions, and unresolved conflicts.
4. Prefer project contracts for global tokens, accessibility, interaction semantics, motion, and reusable APIs. Prefer the reference for screen-local composition, spacing, proportions, and state content.
5. Reuse existing components and assets before proposing additions.
6. Invoke `$compose-ui-delivery` with the completed spec, selected platform, and reference evidence.

## Guardrails

- Do not claim parity from code inspection alone.
- Do not invent missing product copy or branded assets.
- Ask for impact approval before dependencies, infrastructure, shared components, or shared assets change.
- Return a patch and evidence summary. Do not commit, push, or open a PR automatically.
