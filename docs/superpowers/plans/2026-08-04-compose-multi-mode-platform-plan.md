# Compose Multi-Mode Platform Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three directly invokable Compose UI skills and a platform-aware delivery workflow for mobile, web, and desktop.

**Architecture:** Keep reference interpretation, design exploration, and implementation/verification as separate installable skills. The lightweight mode skills produce a normalized screen/state spec and explicitly invoke the shared delivery skill; the delivery package owns platform adapters, deterministic helpers, templates, and visual-review resources.

**Tech Stack:** Codex Agent Skills (`SKILL.md`, `agents/openai.yaml`), Markdown references/templates, PowerShell helpers, Python/Pillow image comparison, Python `unittest`, npm scripts only as DevFlow verification entrypoints.

## Global Constraints

- Do not duplicate official Figma MCP extraction or interpretation instructions.
- Preserve screenshot/image reference support.
- Support Compose mobile, web, and desktop workflows.
- Keep Android/ADB deterministic behavior covered by regression tests.
- Use dry-run before build/install/launch.
- Require explicit approval before dependencies, infrastructure, shared assets, or shared components change.
- Do not commit, push, or open a PR during this execution.

---

### Task 1: Lock the multi-skill package contract with failing tests

**Files:**
- Modify: `tests/test_skill_package.py`
- Modify: `tests/test_discovery.py`
- Modify: `tests/test_validator.py`
- Create: `package.json`

**Interfaces:**
- Produces: expected skill roots `skills/compose-ui-reference`, `skills/compose-ui-designer`, and `skills/compose-ui-delivery`.
- Produces: expected discovery payload fields `source_sets`, `compose_signals`, and `platforms`.
- Produces: DevFlow commands `npm test` and `npm run verify`.

- [ ] **Step 1: Replace package assertions with three-skill expectations**

Assert each package has `SKILL.md` and `agents/openai.yaml`, names are unique, metadata prompts mention the matching `$skill-name`, reference delegates Figma work to `$figma-implement-design`, designer requires approval, and delivery links mobile/web/desktop adapters.

- [ ] **Step 2: Add discovery fixtures for Compose Multiplatform source sets**

Create temporary projects containing representative `androidMain`, `iosMain`, `desktopMain`, `wasmJsMain`, `jsMain`, and `commonMain` folders and assert platform classification.

- [ ] **Step 3: Add validator mutation cases for missing packages and stale metadata**

Copy the repository fixture, remove one skill package or change one `default_prompt`, and assert validation fails with a focused message.

- [ ] **Step 4: Add npm verification entrypoints**

Create a private `package.json` whose `test` script runs `python -m unittest discover -s tests -v` and whose `verify` script runs the full unittest suite followed by the repository PowerShell validator.

- [ ] **Step 5: Run the targeted tests and confirm expected failures**

Run DevFlow `test`. Expected result: failures because the new skill folders and generalized discovery output do not exist yet.

- [ ] **Step 6: Inspect the test diff and leave it uncommitted**

Use `get_git_diff`; verify only tests and verification entrypoints changed.

---

### Task 2: Create directly invokable reference and designer skills

**Files:**
- Create: `skills/compose-ui-reference/SKILL.md`
- Create: `skills/compose-ui-reference/agents/openai.yaml`
- Create: `skills/compose-ui-reference/references/reference-normalization.md`
- Create: `skills/compose-ui-reference/templates/screen-spec.md`
- Create: `skills/compose-ui-designer/SKILL.md`
- Create: `skills/compose-ui-designer/agents/openai.yaml`
- Create: `skills/compose-ui-designer/references/designer-workflow.md`
- Create: `skills/compose-ui-designer/references/rubrics/ux-quality.md`
- Create: `skills/compose-ui-designer/references/rubrics/anti-ai-slop.md`
- Create: `skills/compose-ui-designer/templates/screen-spec.md`

**Interfaces:**
- Consumes: `$figma-implement-design` for Figma inputs.
- Produces: a normalized screen/state spec passed to `$compose-ui-delivery`.

- [ ] **Step 1: Implement `compose-ui-reference` metadata and routing**

Use frontmatter name `compose-ui-reference`. Route Figma inputs to `$figma-implement-design`; route screenshots/images to local normalization; require one screen/state spec; invoke `$compose-ui-delivery` after the spec is ready.

- [ ] **Step 2: Implement screenshot/reference normalization guidance**

Document observable layout, hierarchy, copy, assets, states, responsive constraints, uncertainties, and conflict handling without Figma MCP instructions.

- [ ] **Step 3: Implement `compose-ui-designer` metadata and approval workflow**

Use frontmatter name `compose-ui-designer`. Enforce project discovery, Designer proposal, Critic review, explicit approval, then `$compose-ui-delivery`.

- [ ] **Step 4: Add focused designer rubrics and screen spec template**

Keep UX and anti-AI-slop checks specific enough to reject generic cards, decorative gradients, invented copy, weak hierarchy, fake density, and product-inconsistent motifs.

- [ ] **Step 5: Run package tests**

Run DevFlow `test`. Expected result: mode-skill assertions pass; delivery/discovery assertions remain failing.

- [ ] **Step 6: Inspect the diff and leave it uncommitted**

Confirm no official Figma extraction logic was copied into the reference skill.

---

### Task 3: Create the shared delivery skill and platform adapters

**Files:**
- Create: `skills/compose-ui-delivery/SKILL.md`
- Create: `skills/compose-ui-delivery/agents/openai.yaml`
- Move/adapt: `references/compose-patterns.md` -> `skills/compose-ui-delivery/references/compose-patterns.md`
- Move/adapt: `references/visual-review.md` -> `skills/compose-ui-delivery/references/visual-review.md`
- Create: `skills/compose-ui-delivery/references/platforms/mobile.md`
- Create: `skills/compose-ui-delivery/references/platforms/web.md`
- Create: `skills/compose-ui-delivery/references/platforms/desktop.md`
- Move: `references/rubrics/*.md` -> `skills/compose-ui-delivery/references/rubrics/`
- Move/adapt: `templates/*` -> `skills/compose-ui-delivery/templates/`
- Move/adapt: helper scripts -> `skills/compose-ui-delivery/scripts/`

**Interfaces:**
- Consumes: normalized screen/state spec and selected platform.
- Produces: project-native patch, rendered evidence, functional checks, visual-review JSON, and an evidence summary.

- [ ] **Step 1: Implement delivery entrypoint and platform routing**

Require discovery first, select exactly one platform adapter for the current loop, preserve approval gates, and stop before commit/push/PR.

- [ ] **Step 2: Implement mobile adapter**

Cover Android Gradle variant, Activity/deeplink, ADB device/capture, phone/tablet state checks, keyboard/system insets, and iOS environment-dependent guidance without claiming simulator truth.

- [ ] **Step 3: Implement web adapter**

Cover Compose Web/Kotlin Wasm/JS task discovery, browser URL readiness, named viewport captures, keyboard/focus/scroll checks, responsive breakpoints, and browser-console/network regressions.

- [ ] **Step 4: Implement desktop adapter**

Cover Compose Desktop/JVM run task, application-window readiness, named window-size captures, resize/min-size behavior, mouse/hover/focus/keyboard/menu checks, and environment-dependent window capture.

- [ ] **Step 5: Generalize visual review**

Replace Android-only ladder wording with platform truth: emulator/device for mobile, browser for web, application window for desktop. Keep image diff optional when no reference exists and require evidence for every visual claim.

- [ ] **Step 6: Move helpers/templates into the delivery package**

Update relative links and command examples so installing `compose-ui-delivery` includes every resource it needs.

- [ ] **Step 7: Run package tests**

Run DevFlow `test`. Expected result: skill package tests pass; discovery/config tests may remain failing until Task 4.

- [ ] **Step 8: Inspect the diff and leave it uncommitted**

Confirm mode skills remain lightweight and delivery owns shared resources.

---

### Task 4: Generalize discovery and safe build/launch previews

**Files:**
- Modify: `skills/compose-ui-delivery/scripts/discover-project.ps1`
- Modify: `skills/compose-ui-delivery/scripts/build-and-launch.ps1`
- Modify: `skills/compose-ui-delivery/templates/compose-ui-delivery.yaml`
- Modify: `tests/test_discovery.py`

**Interfaces:**
- `discover-project.ps1` returns JSON keys `modules`, `manifests`, `source_sets`, `compose_signals`, `platforms`, `devices`, `signals`, and `confidence`.
- `build-and-launch.ps1` accepts `platform.kind` and `platform.target` plus platform-specific launch keys.

- [ ] **Step 1: Add source-set and Compose plugin discovery**

Detect source-set directory names and search Gradle build files for Compose Multiplatform/Android Compose signals. Derive sorted unique platform values.

- [ ] **Step 2: Preserve Android discovery output**

Keep manifests, variants, ADB availability, and connected device reporting so existing Android fixtures remain valid.

- [ ] **Step 3: Generalize delivery config**

Add `platform.kind`, `platform.target`, `launch.task`, `launch.url`, and `launch.window_title`; retain Android `launch.mode`, `launch.target`, and `launch.deeplink`.

- [ ] **Step 4: Add safe web/desktop dry-run generation**

For web/browser and desktop/jvm, validate a Gradle task token and print the Gradle run command. Do not execute browser/window capture from this helper. Keep Android build/install/ADB launch behavior unchanged.

- [ ] **Step 5: Reject unsupported combinations and unsafe task values**

Reject invalid platform kinds/targets, missing platform-specific keys, whitespace/shell operators in Gradle task tokens, and invalid acceptance values.

- [ ] **Step 6: Run discovery and dry-run tests**

Run DevFlow `test`. Expected result: all discovery/build tests pass.

- [ ] **Step 7: Inspect the diff and leave it uncommitted**

Confirm no arbitrary shell command execution was introduced.

---

### Task 5: Rewrite repository validation and documentation

**Files:**
- Modify: `scripts/validate-skill.ps1`
- Modify: `README.md`
- Remove: root `SKILL.md`, root `agents/`, old root `references/`, old root `templates/`, and old root delivery helper copies after migration.
- Modify: `tests/test_validator.py`

**Interfaces:**
- Validator command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill.ps1 -RepoRoot .`.
- README installation paths match the three `skills/<name>` directories.

- [ ] **Step 1: Validate each installable skill independently**

Require frontmatter name/description, matching metadata default prompt, local links contained inside the skill root, and no production placeholders.

- [ ] **Step 2: Validate delivery resources and config schema**

Require platform references, rubrics, scripts, templates, valid platform kind/target, valid acceptance ranges, and valid visual-review JSON shape.

- [ ] **Step 3: Update mutation tests**

Cover missing skill package, mismatched metadata prompt, broken/escaping links, invalid platform config, malformed YAML, invalid visual-review nested values, and placeholders.

- [ ] **Step 4: Write repository installation and usage documentation**

Document installing all three directories, direct invocation examples, official Figma composition, mobile/web/desktop routing, requirements, and verification commands.

- [ ] **Step 5: Remove the old umbrella package only after new tests pass**

Delete root skill resources that would expose the stale `$compose-ui-agent-skill` entrypoint or duplicate delivery resources.

- [ ] **Step 6: Run the repository validator**

Run DevFlow `verify`. Expected result: tests and validation pass.

- [ ] **Step 7: Inspect the diff and leave it uncommitted**

Confirm README and package paths match actual files.

---

### Task 6: Final verification, self-review, and DevFlow closeout

**Files:**
- Review all changed files.
- Update: DevFlow task `composeuiagentskill-0001` checklist/status.

**Interfaces:**
- Produces: clean verification evidence and a review-ready uncommitted diff.

- [ ] **Step 1: Run full tests**

Run `npm test` through DevFlow. Expected: all tests pass.

- [ ] **Step 2: Run full verification**

Run `npm run verify` through DevFlow. Expected: tests and repository validation pass.

- [ ] **Step 3: Run standalone image tests when still present**

Run the delivery package's `scripts/test_compare_images.py` through an available verification entrypoint or ensure it is included in the unittest suite.

- [ ] **Step 4: Inspect Git status and full diff**

Verify only intended repository files changed and no generated evidence/cache files are present.

- [ ] **Step 5: Self-review against acceptance criteria**

Check direct skill names, official Figma delegation, Designer approval gate, all three platform adapters, Android regression behavior, validation coverage, README commands, and no commit/push.

- [ ] **Step 6: Toggle completed checklist items and move the task to `ready-for-review`**

Do not move to `done` because the user has not approved or requested a commit.

- [ ] **Step 7: Present the diff summary and branch limitation**

State that DevFlow's current MCP surface cannot create/switch a local branch, so the desired branch is recorded on the card but the working tree remains on `main`; provide the exact branch command the user can run before committing.