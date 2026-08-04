---
name: compose-ui-agent-skill
description: Use when Android Jetpack Compose UI work needs reference-driven implementation or design exploration with design-system discovery, visual evidence, and approval-gated shared changes.
---

# Compose UI Agent Skill

Use this skill for Android Jetpack Compose UI tasks that must match a reference or turn a product brief into an approved UI direction without automatic commits, pushes, or PRs.

## Core Rules

- Start by discovering the project, module, design system, shared components, custom `Text` wrappers, `Typography`, and local string-resource conventions before proposing UI code.
- Run [scripts/discover-project.ps1](scripts/discover-project.ps1) before implementation. If module, variant, device, or launch behavior is ambiguous, generate and review a config from [templates/compose-ui-agent.yaml](templates/compose-ui-agent.yaml); treat the approved config as the source of truth.
- Normalize every Figma file, screenshot, or written brief into one screen/state spec before implementation.
- Use patch-first delivery. Produce code patches and evidence. Do not auto-commit, push, or open a PR.
- Ask for explicit impact approval before changing test infrastructure, dependencies, assets, shared components, or other cross-cutting UI foundations.
- Reuse existing assets and components before proposing new ones.
- Use the shared visual-review workflow for every visual claim.

## Mode Routing

Choose one mode after discovery and spec normalization:

- **Reference Mode**: use when the user provides Figma, screenshots, or another visual reference that should drive the screen.
  See [references/reference-mode.md](references/reference-mode.md)
- **Designer Mode**: use when the user provides a product brief or asks for new UI direction rather than a fixed reference.
  See [references/designer-mode.md](references/designer-mode.md)

Both modes must follow:

- [references/compose-patterns.md](references/compose-patterns.md)
- [references/visual-review.md](references/visual-review.md)
- [references/rubrics/visual-parity.md](references/rubrics/visual-parity.md)
- [references/rubrics/ux-quality.md](references/rubrics/ux-quality.md)
- [references/rubrics/anti-ai-slop.md](references/rubrics/anti-ai-slop.md)

## Working Artifacts

- Config template: [templates/compose-ui-agent.yaml](templates/compose-ui-agent.yaml)
- Screen/state spec: [templates/screen-spec.md](templates/screen-spec.md)
- Visual review record: [templates/visual-review.json](templates/visual-review.json)
- UI metadata: [agents/openai.yaml](agents/openai.yaml)

## Deterministic Helpers

- Discover Android project signals: `powershell -File scripts/discover-project.ps1 -ProjectRoot . -OutputPath .compose-ui-agent/discovery.json`
- Preview build/install/launch commands: `powershell -File scripts/build-and-launch.ps1 -ProjectRoot . -ConfigPath .compose-ui-agent/compose-ui-agent.yaml -DryRun`
- Capture emulator evidence: `powershell -File scripts/capture-screen.ps1 -Serial <adb-serial> -OutputPath .compose-ui-agent/evidence/loaded.png`
- Record state metadata: `powershell -File scripts/collect-ui-evidence.ps1 -Serial <adb-serial> -OutputDirectory .compose-ui-agent/evidence -State loaded`
- Compare reference and actual images: `python scripts/compare-images.py --reference reference.png --actual actual.png --output-json .compose-ui-agent/evidence/loaded.json --diff .compose-ui-agent/evidence/loaded-diff.png --blend .compose-ui-agent/evidence/loaded-blend.png`

Use `-DryRun` before build/install/launch. Do not add dependencies or mutate project infrastructure to make a helper work without an approval gate.

## Delivery Contract

1. Discover project and design-system constraints.
2. Normalize the request into a single-screen state spec.
3. Route to Reference Mode or Designer Mode.
4. Get impact approval before any infrastructure, asset, or shared-component change.
5. Implement only after the mode workflow allows it.
6. Run the shared visual-review workflow with evidence per state.
7. Return the patch and evidence summary. Stop before commit, push, or PR.
