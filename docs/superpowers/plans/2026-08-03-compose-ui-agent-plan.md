# Compose UI Agent Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Codex skill that makes Android Compose UI work reference-aware, design-system-aware, and evidence-driven.

**Architecture:** Keep the skill entrypoint under the repository root and progressively disclose mode-specific guidance through `references/`. Put deterministic machine work in `scripts/`, and keep project-specific values in a generated `compose-ui-agent.yaml` template. Scripts never silently mutate production code or infrastructure.

**Tech Stack:** Markdown skill resources, PowerShell 7+/Windows PowerShell-compatible scripts, Python 3, Pillow for image comparison, Android Gradle wrapper, adb.

## Global Constraints

- Use two modes: Reference Mode and Designer Mode, sharing one visual-verification engine.
- Inspect the project design system and local Text/Typography conventions before writing Compose.
- Auto-discover first; generate config when the launch target or build choice is ambiguous.
- The emulator is the final visual source of truth.
- Require image diff, visual rubric, and functional checks before declaring visual work complete.
- Stop the visual loop after five iterations or when improvement stalls for two rounds.
- Ask before adding dependencies, test infrastructure, new assets, or changing shared components.
- Never commit, push, or create a PR without explicit user approval.

### Task 1: Skill package and workflow guidance

**Files:**
- Create: `SKILL.md`
- Create: `agents/openai.yaml`
- Create: `references/reference-mode.md`
- Create: `references/designer-mode.md`
- Create: `references/visual-review.md`
- Create: `references/compose-patterns.md`
- Create: `templates/compose-ui-agent.yaml`
- Create: `templates/screen-spec.md`
- Create: `templates/visual-review.json`
- Create: `references/rubrics/visual-parity.md`
- Create: `references/rubrics/ux-quality.md`
- Create: `references/rubrics/anti-ai-slop.md`

**Interfaces:**
- `SKILL.md` routes a user request to a mode and links each reference directly.
- `compose-ui-agent.yaml` supplies explicit `project`, `device_profiles`, `launch`, `capture`, and `acceptance` keys.
- `screen-spec.md` represents one screen and its required/optional states.
- `visual-review.json` records per-state evidence, scores, issues, regressions, and iteration number.

- [ ] Write failing content checks for required frontmatter, references, and template keys.
- [ ] Run the checks and confirm they fail before files exist.
- [ ] Write the smallest complete skill package and metadata.
- [ ] Run the checks and confirm they pass.

### Task 2: Project discovery and Android execution helpers

**Files:**
- Create: `scripts/discover-project.ps1`
- Create: `scripts/build-and-launch.ps1`
- Create: `scripts/capture-screen.ps1`
- Create: `scripts/collect-ui-evidence.ps1`

**Interfaces:**
- `discover-project.ps1 -ProjectRoot <path> [-OutputPath <path>]` emits JSON with Gradle wrapper, Android modules, manifests, variants, devices, and confidence.
- `build-and-launch.ps1 -ProjectRoot <path> -ConfigPath <path> [-DryRun]` executes only configured Gradle/install/launch steps; `-DryRun` prints commands without mutation.
- `capture-screen.ps1 -Serial <adb serial> -OutputPath <png>` captures one PNG through `adb exec-out screencap -p`.
- `collect-ui-evidence.ps1 -Serial <adb serial> -OutputDirectory <path> -State <name>` writes screenshot plus timestamp/device metadata.

- [ ] Write failing smoke tests for discovery on a temporary minimal Android-like tree and for dry-run command generation.
- [ ] Run the tests and record the failures.
- [ ] Implement deterministic discovery, dry-run, capture, and evidence collection.
- [ ] Run the focused tests and verify expected JSON/output.

### Task 3: Image comparison and evidence validation

**Files:**
- Create: `scripts/compare-images.py`
- Create: `scripts/test_compare_images.py`
- Create: `scripts/validate-skill.ps1`

**Interfaces:**
- `compare-images.py --reference <png> --actual <png> --output-json <json> [--diff <png>] [--blend <png>]` returns non-zero for invalid input, otherwise writes `width`, `height`, `mean_absolute_error`, `changed_pixel_ratio`, and `structural_similarity_estimate`.
- `validate-skill.ps1 -SkillRoot <path>` checks frontmatter, metadata, direct references, templates, and script syntax without building an Android app.

- [ ] Write failing image-comparison tests for identical, changed, and dimension-mismatch images.
- [ ] Run the tests to verify the red state.
- [ ] Implement comparison with explicit Pillow dependency/error text and deterministic JSON.
- [ ] Run Python tests, PowerShell syntax checks, and the skill validator.

### Task 4: Final review boundary

**Files:**
- Modify: `README.md` only if a concise repository pointer is needed after validation.

- [ ] Inspect `git diff`, untracked files, and generated artifacts.
- [ ] Run the complete repository validation command set.
- [ ] Report changed files and distinguish verified local helpers from unverified Android emulator behavior.
- [ ] Stop before commit/push and wait for explicit approval.
