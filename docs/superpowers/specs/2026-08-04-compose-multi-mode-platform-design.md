# Compose Multi-Mode Platform Skill Design

## Goal

Turn the repository from one Android-only umbrella skill into a small catalog of directly invokable Compose UI skills that compose cleanly with OpenAI's official Figma workflow and support mobile, web, and desktop delivery.

## Skill boundaries

### `compose-ui-reference`

Use when a concrete visual reference drives implementation.

- For Figma input, invoke the official `$figma-implement-design` skill for design extraction, screenshots, assets, and design-context interpretation.
- For screenshot or image input, normalize the visible layout, content, states, constraints, and unresolved details locally.
- Produce one implementation-ready screen/state spec.
- Delegate project-native implementation and rendered verification to `$compose-ui-delivery`.
- Do not duplicate Figma MCP instructions or asset extraction behavior.

### `compose-ui-designer`

Use when the user provides a product brief without a fixed reference.

- Discover existing product conventions before proposing a direction.
- Run Designer -> Critic -> explicit user approval.
- Reject generic AI UI patterns using the bundled UX and anti-AI-slop rubrics.
- Produce an approved screen/state spec.
- Delegate implementation and rendered verification to `$compose-ui-delivery`.

### `compose-ui-delivery`

Use when a reference-derived or designer-approved screen/state spec is ready for implementation.

- Discover the Compose project, source sets, design system, shared components, typography, strings, and target platforms.
- Select exactly one adapter for the current verification loop: mobile, web, or desktop.
- Implement the smallest project-native patch.
- Build, launch, capture rendered evidence, run functional checks, compare images when a reference exists, and record a visual-review result.
- Preserve patch-first delivery, dry-run before launch, impact approval for cross-cutting changes, and no automatic commit/push/PR.

## Repository structure

```text
skills/
  compose-ui-reference/
    SKILL.md
    agents/openai.yaml
    references/reference-normalization.md
    templates/screen-spec.md
  compose-ui-designer/
    SKILL.md
    agents/openai.yaml
    references/designer-workflow.md
    references/rubrics/ux-quality.md
    references/rubrics/anti-ai-slop.md
    templates/screen-spec.md
  compose-ui-delivery/
    SKILL.md
    agents/openai.yaml
    references/compose-patterns.md
    references/visual-review.md
    references/platforms/mobile.md
    references/platforms/web.md
    references/platforms/desktop.md
    references/rubrics/visual-parity.md
    references/rubrics/ux-quality.md
    references/rubrics/anti-ai-slop.md
    scripts/discover-project.ps1
    scripts/build-and-launch.ps1
    scripts/capture-screen.ps1
    scripts/collect-ui-evidence.ps1
    scripts/compare-images.py
    scripts/test_compare_images.py
    templates/compose-ui-delivery.yaml
    templates/screen-spec.md
    templates/visual-review.json
scripts/validate-skill.ps1
tests/
README.md
package.json
```

Each installable skill keeps all local Markdown links inside its own root. Mode skills compose the delivery skill by explicit skill invocation rather than filesystem links.

## Platform contract

The delivery config uses:

```yaml
platform:
  kind: "mobile"
  target: "android"
```

Allowed combinations:

- `mobile/android`: deterministic Gradle assemble/install plus ADB activity or deeplink launch and ADB screenshot capture.
- `mobile/ios`: Compose Multiplatform iOS guidance using project-native Xcode/Gradle tasks; simulator capture is environment-dependent and must not be claimed when unavailable.
- `web/browser`: Compose Web, Kotlin/Wasm, or Kotlin/JS browser task; use browser screenshot evidence at named viewport sizes.
- `desktop/jvm`: Compose Desktop/JVM task; use application-window screenshot evidence at named window sizes.

`build-and-launch.ps1` remains deterministic for Android and supports safe dry-run command generation for web and desktop Gradle tasks. iOS remains guidance-first because execution requires macOS/Xcode.

## Discovery contract

`discover-project.ps1` returns:

- Gradle wrapper and settings signals.
- Included modules and manifests.
- Source-set signals for `androidMain`, `iosMain`, `desktopMain`, `jvmMain`, `wasmJsMain`, `jsMain`, and `commonMain`.
- Compose plugin/build-file signals.
- Detected platform targets: `mobile`, `web`, `desktop`.
- ADB availability and connected Android devices when available.
- Confidence based on general Compose/Gradle signals instead of Android-only assumptions.

## Validation and tests

Repository validation must:

- Require all three skill packages and their metadata.
- Enforce unique frontmatter names and matching `$skill-name` default prompts.
- Reject broken local links and links escaping each skill root.
- Require platform references and delivery resources.
- Validate the generalized delivery config and visual-review template.
- Reject production placeholders.

Tests cover:

- Package structure and direct invocation metadata.
- Figma delegation without duplicated MCP extraction instructions.
- Designer approval gate.
- Mobile/web/desktop adapter references.
- Android, multiplatform source-set, web, and desktop discovery fixtures.
- Android and generic Gradle-task dry-run behavior.
- Image comparison regressions and validator mutations.

## Safety

- No automatic commits, pushes, or PRs.
- No application sample or runtime dependency is added.
- No Figma MCP behavior is reimplemented.
- No claim of emulator, browser, simulator, or desktop-window truth without captured evidence from that target.
- Infrastructure, dependency, shared-component, and shared-asset changes still require explicit impact approval.