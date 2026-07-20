# Getman Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring BabyClapper to parity with Getman's engineering system — feature-first layering, the same lint/static-analysis stack, the same PR checks, and the same "Claude-friendly" documentation architecture.

**Architecture:** Six sequential tasks. First relocate code into proper feature layers, then build the lint plugin, then wire the analysis stack into the app (which forces file headers), then CI, then the navigation docs, then slim CLAUDE.md. Each task ends green on the verification bar available at that point.

**Tech Stack:** Flutter 3.44.4 via fvm; `very_good_analysis`, `custom_lint` + a local `baby_clapper_lints` plugin package, `solid_lints` metric gates, `bloc_lint` via `bloc_tools`; GitHub Actions.

## Source of truth — READ THE REAL FILES

Getman is at `/home/thiago/code/Getman`. Reference branch **`origin/master`**, NOT checked out (its working tree is on an unrelated feature branch).

**Never check out, modify, commit to, or otherwise disturb that repo.** Read only:
```bash
git -C /home/thiago/code/Getman show origin/master:<path>
git -C /home/thiago/code/Getman ls-tree -r --name-only origin/master -- <dir>
```

This is a **fidelity port**: read Getman's actual files and port them, adapting only what this plan says to adapt. Do not work from summaries or reconstruct from memory. This is why tasks below cite source paths instead of embedding thousands of transcribed lines — the source repo is the authority, and transcription into this plan would only add a layer where fidelity can drift.

## Global Constraints

- Every command via `fvm` (`fvm flutter …` / `fvm dart …`), never bare `flutter`/`dart`. Flutter is pinned to `3.44.4` in `.fvmrc`.
- Platforms: **iOS + Android only.** No web/desktop targets; never add web-safety `_io`/`_stub` conditional imports.
- Imports are `package:baby_clapper/...` everywhere; no relative imports.
- BLoCs stay Flutter-decoupled: `package:bloc/bloc.dart`, `dart:developer` `log(...)`, never `debugPrint`/`print` in a bloc.
- Non-bloc layers use `debugPrint` for plain traces but **prefer `dart:developer` `log(..., error:, stackTrace:)` when reporting a caught failure** (`debugPrint` is String-only and would discard the error and stack).
- Platform plugins (`vibration`, `soundpool`, `audio_session`, `sensors_plus`, `wakelock_plus`) are imported ONLY inside their one adapter file.
- GetIt / `sl` referenced ONLY in `lib/core/di/injection_container.dart` and `lib/main.dart`.
- Haptics and audio degrade **independently**; a missing capability is never a crash.
- Lines ≤ 80 cols; `fvm dart format .` before every commit.
- **No runtime behaviour changes anywhere in this plan.** It is tooling, structure, and documentation only. The 17 existing tests must stay green throughout.

---

### Task 1: Feature-first restructure

**Files:**
- Move: `lib/core/haptics/haptic_service.dart` → `lib/features/rattle/domain/haptic_service.dart`
- Move: `lib/core/audio/sound_service.dart` → `lib/features/rattle/domain/sound_service.dart`
- Move: `lib/core/motion/motion_service.dart` → `lib/features/rattle/domain/motion_service.dart`
- Move: `lib/core/rattle_math.dart` → `lib/features/rattle/domain/rattle_math.dart`
- Move: `lib/core/haptics/vibration_haptic_service.dart` → `lib/features/rattle/data/vibration_haptic_service.dart`
- Move: `lib/core/audio/soundpool_sound_service.dart` → `lib/features/rattle/data/soundpool_sound_service.dart`
- Move: `lib/core/motion/sensors_motion_service.dart` → `lib/features/rattle/data/sensors_motion_service.dart`
- Keep: `lib/core/di/injection_container.dart`, `lib/core/system/immersive_mode.dart`, `lib/main.dart`
- Modify (imports only): all files above + `lib/features/rattle/presentation/bloc/rattle_bloc.dart`, `lib/features/rattle/presentation/screens/rattle_screen.dart`
- Move tests to mirror: `test/core/rattle_math_test.dart` → `test/features/rattle/domain/rattle_math_test.dart`
- Modify (imports only): `test/features/rattle/presentation/bloc/rattle_bloc_test.dart`, `test/widget_test.dart`

**Interfaces:** No public API changes — class names, method signatures, and behaviour are all unchanged. Only file locations and import URIs change.

- [ ] **Step 1: Move the files with `git mv`** (preserves history)

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p lib/features/rattle/domain lib/features/rattle/data test/features/rattle/domain
git mv lib/core/haptics/haptic_service.dart        lib/features/rattle/domain/
git mv lib/core/audio/sound_service.dart           lib/features/rattle/domain/
git mv lib/core/motion/motion_service.dart         lib/features/rattle/domain/
git mv lib/core/rattle_math.dart                   lib/features/rattle/domain/
git mv lib/core/haptics/vibration_haptic_service.dart lib/features/rattle/data/
git mv lib/core/audio/soundpool_sound_service.dart    lib/features/rattle/data/
git mv lib/core/motion/sensors_motion_service.dart    lib/features/rattle/data/
git mv test/core/rattle_math_test.dart             test/features/rattle/domain/
rmdir lib/core/haptics lib/core/audio lib/core/motion test/core 2>/dev/null || true
```

- [ ] **Step 2: Update every import URI**

Rewrite these `package:baby_clapper/...` URIs across `lib/` and `test/`:

| Old | New |
|---|---|
| `core/haptics/haptic_service.dart` | `features/rattle/domain/haptic_service.dart` |
| `core/audio/sound_service.dart` | `features/rattle/domain/sound_service.dart` |
| `core/motion/motion_service.dart` | `features/rattle/domain/motion_service.dart` |
| `core/rattle_math.dart` | `features/rattle/domain/rattle_math.dart` |
| `core/haptics/vibration_haptic_service.dart` | `features/rattle/data/vibration_haptic_service.dart` |
| `core/audio/soundpool_sound_service.dart` | `features/rattle/data/soundpool_sound_service.dart` |
| `core/motion/sensors_motion_service.dart` | `features/rattle/data/sensors_motion_service.dart` |

Find every occurrence first so none is missed:
```bash
grep -rn "package:baby_clapper/core/\(haptics\|audio\|motion\|rattle_math\)" lib test
```
`directives_ordering` is enforced — after rewriting, imports in each file must still be alphabetically ordered, so re-sort where the new URI changes position.

- [ ] **Step 3: Verify the layering rules hold**

Run and confirm each returns nothing (or only allowed hits):
```bash
# core/ must not import features/ — EXCEPT injection_container.dart (DI knows concretes)
grep -rn "package:baby_clapper/features/" lib/core/ | grep -v injection_container.dart
# the bloc must not import the data layer
grep -rn "package:baby_clapper/features/rattle/data/" lib/features/rattle/presentation/
# domain must import no plugins
grep -rnE "package:(vibration|soundpool|audio_session|sensors_plus|wakelock_plus)/" lib/features/rattle/domain/
```
Expected: all three produce **no output**.

- [ ] **Step 4: Format, analyze, test**

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```
Expected: format clean, **No issues found!**, **17/17 tests passed**.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Move rattle services into feature domain/data layers"
```

---

### Task 2: The `baby_clapper_lints` package + fixtures

**Files:**
- Create: `tools/baby_clapper_lints/pubspec.yaml`
- Create: `tools/baby_clapper_lints/analysis_options.yaml`
- Create: `tools/baby_clapper_lints/lib/baby_clapper_lints.dart`
- Create: `tools/baby_clapper_lints/example/pubspec.yaml`
- Create: `tools/baby_clapper_lints/example/analysis_options.yaml`
- Create: fixture files under `tools/baby_clapper_lints/example/lib/`

**Source to port (read these):**
```
tools/getman_lints/pubspec.yaml
tools/getman_lints/analysis_options.yaml
tools/getman_lints/lib/getman_lints.dart
tools/getman_lints/example/pubspec.yaml
tools/getman_lints/example/analysis_options.yaml
tools/getman_lints/example/lib/         (all fixture files)
```

**Interfaces:**
- Produces: package `baby_clapper_lints` exposing `PluginBase createPlugin()` registering exactly 7 rules: `avoid_get_it_in_widgets`, `avoid_hardcoded_brand_colors`, `domain_no_infrastructure_imports`, `bloc_depends_on_abstractions`, `platform_io_outside_io_files`, `equatable_props_complete`, `file_header_required`.

- [ ] **Step 1: Port the package skeleton**

Port `pubspec.yaml` (rename to `baby_clapper_lints`, `publish_to: none`, deps `analyzer` + `custom_lint_builder`) and the package-local `analysis_options.yaml` (which silences the `deprecated_member_use` warnings from `custom_lint_core` 0.8.x). Keep Getman's version constraints unless they fail to resolve.

- [ ] **Step 2: Port the 7 rules**

Port `getman_lints.dart` → `baby_clapper_lints.dart`, preserving its structure: the `createPlugin()` entry point, the `PluginBase` subclass listing all rules, the `_posix()` path-normalisation helper, and each rule as a `const` `DartLintRule` with a `static const LintCode _code` and a `run()` registering AST visitors.

Adaptations (ONLY these):

| Rule | Change |
|---|---|
| `domain_no_infrastructure_imports` | Banned imports become: `dart:io`, `dart:ui`, `package:flutter/`, `package:vibration/`, `package:soundpool/`, `package:audio_session/`, `package:sensors_plus/`, `package:wakelock_plus/`, and any `package:baby_clapper/…` path containing `/data/`. |
| `bloc_depends_on_abstractions` | Banned imports become: `package:vibration/`, `package:soundpool/`, `package:audio_session/`, `package:sensors_plus/`, `package:wakelock_plus/`, and any `package:baby_clapper/…` path containing `/data/`. |
| `avoid_get_it_in_widgets` | Self-package URI check becomes `package:baby_clapper/` / `/core/di/injection_container.dart`. |
| others | No change beyond the package rename. |

`platform_io_outside_io_files` is ported **verbatim** for parity. Add a `//` comment above it recording that it is currently **dormant** — BabyClapper has no `dart:io` usage and no web target — and that it does **not** reintroduce a web-stub requirement (the project is mobile-only by mandate).

- [ ] **Step 3: Port the fixtures — including one for every rule**

Port the `example/` package (its own `pubspec.yaml` with a path dep on `../`, and an `analysis_options.yaml` containing just `analyzer: plugins: [custom_lint]`).

Port each fixture file, adapting banned imports to BabyClapper's package list. Keep Getman's positive/negative pairing discipline (e.g. a `platform_ok_io.dart` that must NOT flag alongside `platform_bad_fixture.dart` that must).

**Getman ships no fixture for `avoid_get_it_in_widgets` — a gap versus its own "every rule ships a fixture" mandate. You MUST add one here.** Note that rule needs a *resolved* element (it inspects `node.element`), unlike the import-URI rules, so the fixture must import something that actually resolves — construct it so the rule genuinely fires.

- [ ] **Step 4: Run the fixtures self-test**

```bash
cd tools/baby_clapper_lints/example && fvm dart pub get && fvm dart run custom_lint
```
Expected: **No issues found!** — meaning every `// expect_lint:` fired as expected and nothing unexpected fired. If a rule you expect doesn't fire, the fixture or the rule is wrong; fix it now, this is the rules' only test.

- [ ] **Step 5: Commit**

```bash
git add tools/
git commit -m "Add baby_clapper_lints custom_lint package with fixtures"
```

---

### Task 3: Wire the analysis stack into the app (+ file headers)

**Files:**
- Modify: `analysis_options.yaml`
- Modify: `pubspec.yaml` (dev_dependencies)
- Modify: every hand-written `lib/**/*.dart` file (add `//` headers)

**Source to port:** `analysis_options.yaml` and the analysis dev_dependencies block of `pubspec.yaml` on Getman `origin/master`.

**Interfaces:** Consumes the `baby_clapper_lints` package from Task 2 (path dep `tools/baby_clapper_lints`).

> Headers and the `file_header_required` rule land in the SAME task deliberately: enabling the rule without headers makes `custom_lint` red, and adding headers without the rule lets the convention rot. They are one deliverable.

- [ ] **Step 1: Add the dev dependencies**

```bash
fvm flutter pub add dev:custom_lint dev:solid_lints dev:bloc_lint dev:bloc_tools
```
Then add the path dependency by hand in `pubspec.yaml` under `dev_dependencies:`:
```yaml
  baby_clapper_lints:
    path: tools/baby_clapper_lints
```
Run `fvm flutter pub get`. If a version fails to resolve on Dart 3.12, take the newest compatible and note it in your report.

- [ ] **Step 2: Port `analysis_options.yaml`**

Mirror Getman's structure: the VGA include; `analyzer.exclude` (generated files + `tools/**`); `analyzer.plugins: [custom_lint]`; `analyzer.errors: close_sinks: warning`; the pinned `linter.rules` block; the `bloc:` rules block; and the opt-in `custom_lint:` block (`enable_all_lint_rules: false`) listing all 7 `baby_clapper_lints` rules plus the 3 `solid_lints` metric gates.

Port the metric thresholds **verbatim** (`cyclomatic_complexity: 50`, `number_of_parameters: 50`, `function_lines_of_code: 1000`) and carry over Getman's YAML warning comment that each `max_*` key must be a **sibling** of the rule name at the same indentation, never nested (nesting silently reverts to solid_lints' default).

Additionally, measure BabyClapper's real numbers and record them in a comment beside the thresholds, e.g.:
```yaml
    # Ported 1:1 from Getman. NOTE: BabyClapper's measured maxima are far
    # lower (max FLOC ~<N>, complexity ~<N>, params ~<N>), so these gates
    # cannot currently fire — they are inherited for cross-project parity,
    # not calibrated regression gates. Tighten when convenient.
```
Fill `<N>` with the values you actually observe (temporarily lower a threshold until it trips to find the real maximum, then restore it).

- [ ] **Step 3: Add a `//` header to every hand-written `lib/**.dart` file**

Tier the content (Getman's convention):
- **Tier 1** (simple entities/widgets/utils): one sentence.
- **Tier 2** (services, adapters): purpose + key collaborators + where it's wired.
- **Tier 3** (blocs, engines, cross-cutting): Tier 2 + file-local invariants/gotchas.

Use prose `//` (NOT `///` — that trips `dangling_library_doc_comments`). Front-load searchable concept words a task prompt would use. Carry existing file-local invariants into the headers (e.g. `rattle_bloc.dart`'s constructor-wiring rationale, `rattle_screen.dart`'s per-pointer throttle, `soundpool_sound_service.dart`'s set-volume-before-play requirement).

- [ ] **Step 4: Run the full analysis stack and fix what it surfaces**

```bash
fvm dart format .
fvm flutter analyze
fvm dart run custom_lint
fvm dart run bloc_tools:bloc lint lib < /dev/null
( cd tools/baby_clapper_lints/example && fvm dart run custom_lint )
fvm flutter test
```
All must be clean / 17-17. Fix any real violations the new rules surface. If a violation is a deliberate exception, suppress it with a per-line `// ignore: <rule>` plus a one-line reason — never by weakening a rule. (Remember `equatable_props_complete` anchors to the class name, so its `// ignore:` goes directly above the class declaration.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Wire custom_lint, solid_lints and bloc_lint; add file headers"
```

---

### Task 4: CI, PR checks, hooks, coverage

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/ci-comment.yml`, `.github/workflows/pr_agent.yml`
- Create: `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.githooks/pre-commit` (executable)
- Create: `tool/coverage.sh` (executable)

**Source to port:** the same-named files on Getman `origin/master` (`.github/workflows/ci.yml`, `ci-comment.yml`, `pr_agent.yml`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `.githooks/pre-commit`, `tool/coverage.sh`).

**Do NOT port:** `pages.yml`, `release.yml`, and the `build-web` job inside `ci.yml` — BabyClapper has no web or desktop targets and these would fail on every run.

- [ ] **Step 1: Port `ci.yml`**

Keep: the pinned `FLUTTER_VERSION: '3.44.4'`, `permissions: contents: read`, the `concurrency` block, `subosito/flutter-action` with caching, the `checks` job's `continue-on-error` + `| tee <name>.log` per gate, the PR-comment builder (markdown table of ✅/❌, filtered lcov coverage percentage, collapsible failing-step logs), the artifact upload, and **the final gating step that fails the job if any gate failed**. Keep the `secrets` (gitleaks) and `osv-scan` jobs.

Adapt:
- Drop the `build_runner` codegen step and its `git diff --quiet` drift check (BabyClapper has no codegen).
- Drop the `build-web` job entirely.
- Rename `getman_lints` → `baby_clapper_lints` in the fixtures step.
- Update the lcov exclude list in the coverage awk to BabyClapper's files (`*.g.dart`, `lib/main.dart`; drop Getman-only names like `hive_registrar.g.dart`, `update_gate_io.dart`, `dio_adapter_config_io.dart`).
- Use the **standalone** `google/osv-scanner-action`, NOT the reusable workflow — Getman moved off the reusable workflow because its hard-declared `security-events: write` breaks fork PRs under a `contents: read` caller. Preserve Getman's explanatory comment.
- Keep action pins (SHA + version comment) exactly as Getman has them.

- [ ] **Step 2: Port `ci-comment.yml` and `pr_agent.yml`**

`ci-comment.yml`: port as-is (the `workflow_run` trusted-context artifact handoff that lets fork PRs get a comment). Change the sticky-comment `header:` to a BabyClapper-specific value such as `babyclapper-ci-summary`.

`pr_agent.yml`: port as-is. Add a header comment stating it requires a `GEMINI_API_KEY` repo secret and is inert until the owner provisions one.

- [ ] **Step 3: Port `dependabot.yml` and `PULL_REQUEST_TEMPLATE.md`**

`dependabot.yml`: port unchanged (pub + github-actions, weekly, each grouped into one PR).

`PULL_REQUEST_TEMPLATE.md`: port, then drop the Hive-codegen and theme-authoring checklist items, and rename the lints package. Keep the verification checklist mirroring the done-bar, and the wiki-sync + CLAUDE.md-update reminders.

- [ ] **Step 4: Port `.githooks/pre-commit` and `tool/coverage.sh`**

`pre-commit`: port the full ordered stack — repo-root `cd`, fvm detection, then `dart format --set-exit-if-changed lib test tools` → `flutter analyze` → `dart run custom_lint` → fixtures self-test → `bloc_lint` → optional local gitleaks — with the red `fail()` helper and the `--no-verify` bypass hint. Rename the fixtures path.

`coverage.sh`: port; keep the generic lcov excludes (`*.g.dart`, `lib/main.dart`), drop the Getman-only filenames, keep the per-directory + overall awk summary and the HTML output path.

Make both executable:
```bash
chmod +x .githooks/pre-commit tool/coverage.sh
```

- [ ] **Step 5: Validate**

```bash
# YAML parses
python3 -c "import yaml,glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')+['.github/dependabot.yml']]; print('YAML OK')"
# the hook actually runs the gates (this exercises the real stack)
git config core.hooksPath .githooks
bash .githooks/pre-commit && echo "HOOK PASSED"
```
Expected: `YAML OK` and `HOOK PASSED`. Do not attempt to run the GitHub workflows locally.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add CI, PR checks, dependabot, pre-commit hook and coverage script"
```

---

### Task 5: CODEMAP, its coverage test, and architecture docs

**Files:**
- Create: `docs/CODEMAP.md`
- Create: `test/docs/codemap_coverage_test.dart`
- Create: `docs/architecture/app-shell.md`, `docs/architecture/rattle-feedback.md`

**Source to port:** `docs/CODEMAP.md`, `test/docs/codemap_coverage_test.dart`, and any `docs/architecture/*.md` on Getman `origin/master` (for structure/tone — the content is necessarily BabyClapper's own).

- [ ] **Step 1: Write `docs/CODEMAP.md`**

Three sections, matching Getman's shape:
1. **Directory map** — a table (`Path | Purpose | Key files`) covering every `lib/` directory, split into a root/core block and one block per feature.
2. **Where is…?** — an alphabetical `Concept | File(s)` lookup table covering every concept a task prompt might name (swipe velocity, shake detection, throttle, bead sound, vibration amplitude, immersive mode, wakelock, DI, degradation/guard, audio session, tuning constants, …).
3. **Cross-cutting flows** — numbered ordered chains of `file — role`. At minimum: (1) swipe → feedback, (2) shake → feedback, (3) app boot.

Open the file with a one-line statement of its purpose ("Start here to find anything…").

- [ ] **Step 2: Port the CODEMAP coverage test**

Port Getman's `test/docs/codemap_coverage_test.dart`: walk every directory under `lib/` that contains hand-written (non-`.g.dart`) Dart files and assert its literal path string appears in `docs/CODEMAP.md`, failing with an "add these directories" list.

- [ ] **Step 3: Write the architecture docs**

`docs/architecture/app-shell.md` — boot sequence, DI wiring and per-service init isolation, immersive mode + wakelock lifecycle, logging convention.
`docs/architecture/rattle-feedback.md` — the gesture surface (per-pointer tracking + 40 ms throttle), `RattleBloc` (including why the shake subscription is wired in the constructor), the three services and their degrade paths, the feedback math and the four tuning constants, and the audio-session decision (silent switch respected, mixes with other audio).

Each doc opens with the standard one-line blockquote backlink:
```
> Deep-dive for <area>. Loaded on demand — see the routing table in
> CLAUDE.md. For "where is X" lookups use docs/CODEMAP.md.
```

- [ ] **Step 4: Verify**

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```
Expected: clean, and **18/18** (the new CODEMAP coverage test brings the count to 18). Confirm the new test genuinely fails when it should — temporarily delete a directory row from CODEMAP.md, re-run, see it fail, then restore.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add CODEMAP, its coverage test, and architecture docs"
```

---

### Task 6: Slim CLAUDE.md + BACKLOG

**Files:**
- Modify: `CLAUDE.md`
- Create: `docs/BACKLOG.md`

**Source to port:** `CLAUDE.md` and `docs/BACKLOG.md` on Getman `origin/master` (for structure — content is BabyClapper's own).

- [ ] **Step 1: Restructure `CLAUDE.md` into a lean core**

Target Getman's section shape:
```
# BabyClapper — Project Documentation & Mandates
## Tech stack                    (compressed table: package | role | load-bearing note)
## Navigation                    (CODEMAP pointer + "Touching… / Read first" routing table)
## Project structure (feature-first + clean architecture)
## Mandatory rules               (Architecture / UI-styling / Conventions / Design for Claude)
## Build & verification bar
## Global gotchas                (repo-wide only)
```

- Open with the self-describing line: this file is the **lean core** — mandates + a routing table; deep-dive knowledge lives in `docs/architecture/*.md` and in each file's `//` header; keep it that way.
- Move the current §3 architecture deep-dive OUT into the Task 5 architecture docs. Do not duplicate content across tiers.
- Add the routing table with rows for: boot/DI/lifecycle → `docs/architecture/app-shell.md`; gestures/haptics/audio/motion → `docs/architecture/rattle-feedback.md`; finding anything → `docs/CODEMAP.md`; open work → `docs/BACKLOG.md`.
- Add the standing **"Design for Claude"** mandate: the three-tier knowledge placement rule (file → header, cross-file → architecture doc, universal → CLAUDE.md), header every new file, name for grep-ability, and never grow CLAUDE.md inline — route new deep-dives to `docs/architecture/` plus a routing-table row.
- Update the project-structure section to the real post-Task-1 tree (services in `features/rattle/{domain,data}`), and **remove the `core/error/` claim** — no such code exists.
- **Delete the ⚠️ "current state" note in the build section** — the tooling it disclaimed is now real.
- **Fix the OSV claim**: it runs via the standalone `osv-scanner-action`, not a reusable workflow.
- Update the lint-rules list to the 7 rules actually shipped, marking `platform_io_outside_io_files` as dormant/parity-only.
- Note that `pr_agent.yml` needs a `GEMINI_API_KEY` secret.

- [ ] **Step 2: Write `docs/BACKLOG.md`**

Port Getman's format: a **Current state** snapshot; open items grouped by category with stable IDs, each carrying **Files / Problem (with evidence) / Fix / Effort (S/M/L) / Verify**; a **Deferred / Non-goals** section; and a **Working agreement (how to resume)** at the bottom.

Seed with the real outstanding work:
- **On-device tuning** of `kVelocityDivisor` (4.0), `kShakeThreshold` (15.0), `kShakeCooldown` (300 ms), `kSwipeThrottle` (40 ms) — never validated on hardware.
- **solid_lints thresholds are inherited, not calibrated** — currently unfireable; tighten to BabyClapper's measured maxima.
- Deferred: settings persistence (`shared_preferences`), theming (`flutter_animate`, `google_fonts`, theme extensions), a `core/error` Failure hierarchy, mobile release tooling.
- Minor findings carried from the vertical-slice reviews (see `.superpowers/sdd/progress.md` if still present, else the review history): `beadPlayback` DRY nit; `SoundService.dispose()`/`MotionService.dispose()` never called; hardcoded surface colour awaiting the theme pass.
- Non-goals: web/desktop targets; web-safety `_io`/`_stub` conditional imports.

- [ ] **Step 3: Verify the whole bar**

```bash
fvm dart format .
fvm flutter analyze
fvm dart run custom_lint
fvm dart run bloc_tools:bloc lint lib < /dev/null
( cd tools/baby_clapper_lints/example && fvm dart run custom_lint )
fvm flutter test
```
All clean, 18/18. Then re-read CLAUDE.md end-to-end and confirm **every command it names actually runs** and every structural claim matches the real tree.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Slim CLAUDE.md to a lean core; add BACKLOG"
```

---

## Notes for the implementer

- **Fidelity first.** Read Getman's real files. Where this plan says "port", reproduce structure, comments, and action pins — don't paraphrase.
- **The reference repo is read-only.** Never `git checkout`, commit, or modify anything under `/home/thiago/code/Getman`.
- **No behaviour changes.** If a task tempts you to change runtime behaviour, stop and report it instead.
- **Suppress, don't weaken.** If a newly-enabled lint flags a deliberate exception, use a per-line `// ignore:` with a reason; never loosen a rule or threshold to make code pass.
