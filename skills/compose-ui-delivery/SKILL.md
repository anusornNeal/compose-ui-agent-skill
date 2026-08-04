---
name: compose-ui-delivery
description: Use when an approved or reference-derived screen/state spec must be implemented as project-native Compose UI and verified on mobile, web, or desktop with rendered evidence.
---

# Compose UI Delivery

Use this skill after a screen/state direction is ready. It owns project discovery, Compose implementation, platform execution, visual review, and patch-first delivery.

## Required Flow

1. Read the screen/state spec and identify exactly one current verification platform: **mobile**, **web**, or **desktop**.
2. Run `scripts/discover-project.ps1` before implementation and inspect the module, source sets, Compose plugins, design system, shared components, typography, strings, assets, state ownership, and existing test patterns.
3. Read [Compose patterns](references/compose-patterns.md) and the matching platform adapter:
   - [Mobile](references/platforms/mobile.md)
   - [Web](references/platforms/web.md)
   - [Desktop](references/platforms/desktop.md)
4. When module, target, variant, launch task, device, viewport, or window behavior is ambiguous, create and review [the delivery config](templates/compose-ui-delivery.yaml). Treat the approved config as the source of truth.
5. Ask for explicit impact approval before changing dependencies, test infrastructure, shared assets, shared components, or design-system primitives.
6. Implement the smallest project-native patch that satisfies the spec.
7. Use dry-run before build/install/launch. Capture evidence from the selected platform and follow [Visual Review](references/visual-review.md).
8. Return the patch, tests, evidence paths, scores, fixed issues, and remaining issues. Stop before commit, push, or PR.

## Platform Truth

- **Mobile**: an emulator, simulator, or physical device capture is final truth for the target actually available. Android has deterministic ADB helpers; iOS verification requires a compatible macOS/Xcode environment.
- **Web**: a running browser build captured at named viewport sizes is final truth.
- **Desktop**: the running application window captured at named window sizes is final truth.

Do not claim platform truth from source code, preview-only output, or a lower verification rung when the real target is available.

## Deterministic Helpers

From this skill directory:

- Discover: `powershell -File scripts/discover-project.ps1 -ProjectRoot <project-root> -OutputPath <project-root>/.compose-ui-delivery/discovery.json`
- Preview commands: `powershell -File scripts/build-and-launch.ps1 -ProjectRoot <project-root> -ConfigPath <project-root>/.compose-ui-delivery/compose-ui-delivery.yaml -DryRun`
- Android capture: `powershell -File scripts/capture-screen.ps1 -Serial <adb-serial> -OutputPath <evidence.png>`
- Android state evidence: `powershell -File scripts/collect-ui-evidence.ps1 -Serial <adb-serial> -OutputDirectory <evidence-dir> -State <state>`
- Image comparison: `python scripts/compare-images.py --reference <reference.png> --actual <actual.png> --output-json <metrics.json> --diff <diff.png> --blend <blend.png>`

## Shared Quality Gates

- [Visual parity](references/rubrics/visual-parity.md) when a visual reference exists
- [UX quality](references/rubrics/ux-quality.md)
- [Anti-AI-slop](references/rubrics/anti-ai-slop.md)
- Required functional checks from the screen/state spec
- Maximum five adaptive visual iterations; stop when the score stalls twice or the same regression repeats twice
