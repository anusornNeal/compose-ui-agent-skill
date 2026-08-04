# Compose UI Agent Skill Design

## Goal

Create a reusable Codex skill for Android Jetpack Compose UI work that supports both reference-driven implementation and UX/UI design from a brief, with evidence from deterministic screenshots and emulator validation before delivery.

## Approved decisions

- Use two modes: Reference Mode and Designer Mode, sharing one visual-verification engine.
- Normalize Figma, screenshots, and product briefs into a screen/state-oriented working spec.
- Inspect the project design system and local Text/Typography conventions before writing Compose; reuse existing components before introducing new ones.
- Auto-discover the Android project first and generate a config when module, variant, device, or launch behavior is ambiguous. The generated config becomes the source of truth.
- Use a hybrid verification ladder: deterministic fixture/preview, screenshot host, existing deeplink, Activity launch, then adb navigation.
- Treat the emulator as the final visual source of truth. Require image diff, visual rubric, and functional checks.
- Model selection remains the user's choice; the skill does not dynamically route or escalate models.
- Run at most five visual iterations; stop when the score does not improve twice, a regression repeats, or the cap is reached.
- Use an impact-analysis approval gate before changing dependencies, test infrastructure, assets, or shared components.
- Deliver a patch and evidence report first. Never commit, push, or create a PR without explicit user approval.

## V1 scope

The repository will contain the skill entrypoint, two mode workflows, a visual-review workflow, concise rubrics, config/spec templates, and cross-platform-friendly PowerShell/Python helpers for discovery, build/launch, screenshot capture, evidence collection, and image comparison.

The helpers must be safe by default: discovery and dry-run do not mutate the project; build/launch and capture require explicit paths/config; image comparison emits machine-readable JSON and optional diff artifacts. Android-specific verification remains environment-dependent and must be reported as such when SDK, emulator, adb, or project infrastructure is unavailable.

## Non-goals

- Do not add an Android sample app or project dependencies to this repository.
- Do not promise pixel-perfect equality or automatic model routing.
- Do not generate branded assets from screenshots or silently change shared design-system defaults.
