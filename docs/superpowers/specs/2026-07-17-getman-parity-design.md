# Getman Parity — Tooling, Structure & Claude-Friendliness — Design

**Date:** 2026-07-17
**Status:** Approved (design), pending implementation plan
**Goal:** Bring BabyClapper to parity with the Getman project's engineering system: feature-first layering, the same PR checks, the same lint/static-analysis stack, and the same "Claude-friendly" documentation architecture.

## Source of truth

Getman lives at `/home/thiago/code/Getman`. The reference branch is **`origin/master`**, which is NOT checked out there (its working tree is on an unrelated feature branch). **Never check out, modify, or otherwise disturb that repo.** Read it with:

```
git -C /home/thiago/code/Getman show origin/master:<path>
git -C /home/thiago/code/Getman ls-tree -r --name-only origin/master -- <dir>
```

Implementers MUST read the real Getman files rather than working from second-hand summaries — this is a fidelity port.

## Owner decisions (locked)

1. **Literal 1:1 port** of Getman's structure wherever it can work, rather than a scaled-down adaptation.
2. **Include the AI PR reviewer** (`pr_agent.yml`, Qodo pr-agent backed by Gemini). The owner will provision the `GEMINI_API_KEY` repo secret; the workflow is inert until they do.
3. **Scaffold all three feature layers now** (`domain/`, `data/`, `presentation/`).
4. **Skip `build-web`, `pages.yml`, `release.yml` entirely** — they target web/desktop platforms BabyClapper does not have and would fail on every run.

Both repos are public, so gitleaks' free tier and unlimited Actions minutes apply.

## Scope

### A. Feature-first restructure

BabyClapper's CLAUDE.md §2 currently contradicts itself: it lists the three services under `lib/core/{haptics,audio,motion}/` **and** describes `features/rattle/domain/` as holding "abstract services" with `features/rattle/data/` holding "service impls". The implementation followed the `core/` reading, leaving `features/rattle/` with only `presentation/`.

**Resolution — follow the feature-first reading:**

```
lib/
  core/
    di/injection_container.dart      # GetIt bootstrap (only place besides main.dart)
    system/immersive_mode.dart       # fullscreen + wakelock (cross-cutting)
  features/
    rattle/
      domain/                        # pure Dart: entities + abstract services + math
        haptic_service.dart          # abstract
        sound_service.dart           # abstract
        motion_service.dart          # abstract
        rattle_math.dart             # pure feedback math (moved from lib/core/)
      data/                          # plugin adapters (impls of the domain abstractions)
        vibration_haptic_service.dart
        soundpool_sound_service.dart
        sensors_motion_service.dart
      presentation/
        bloc/  screens/
  main.dart
```

Rationale: only the `rattle` feature consumes these services, so under feature-first they belong to it. `core/` keeps genuinely cross-cutting concerns. This gives `domain/` and `data/` real content rather than empty placeholder folders.

`core/error/` is deliberately NOT created: CLAUDE.md §2 lists a `Failure`/`Exception` hierarchy, but nothing in the codebase raises or consumes one (services degrade by catching and logging). Creating it now would be dead code. The CLAUDE.md rewrite must drop the claim rather than the code being written to satisfy the doc.

Dependency directions this establishes (all correct for clean architecture, and worth stating so they aren't "fixed" later):
- `data/` → `domain/` (impls depend on abstractions) — allowed.
- `presentation/` (bloc) → `domain/` only, never `data/` — enforced by `bloc_depends_on_abstractions`.
- `core/di/` → `features/rattle/data/` — allowed and expected; a DI bootstrap necessarily knows the concrete implementations (Getman's `injection_container.dart` does the same).
- `core/` → `features/` is otherwise forbidden.

Note the layering rule this enforces: `core/` must not import from `features/`. Moving `rattle_math.dart` into the feature's `domain/` is only valid because its consumers (`RattleBloc`, `SensorsMotionService`) both end up inside the feature.

CLAUDE.md §2 must be rewritten to match, removing the contradiction.

### B. Lint & static analysis (port from Getman)

**`tools/baby_clapper_lints/`** — a `custom_lint_builder` plugin package (`publish_to: none`, deps `analyzer` + `custom_lint_builder`), consumed by the root app as a path dev-dependency. Port Getman's `getman_lints.dart` structure including its `_posix()` path-normalisation helper and per-rule `DartLintRule` + `LintCode` + AST-visitor shape.

All **7 rules** ported (1:1), with banned-package lists adapted to BabyClapper:

| Rule | Adaptation for BabyClapper |
|---|---|
| `avoid_get_it_in_widgets` | as-is (scope: outside `lib/core/di/` + `lib/main.dart`) |
| `avoid_hardcoded_brand_colors` | as-is (scope: outside `lib/core/theme/`) |
| `domain_no_infrastructure_imports` | ban `package:vibration/`, `package:soundpool/`, `package:sensors_plus/`, `package:audio_session/`, `package:wakelock_plus/` instead of dio/hive; self-package becomes `package:baby_clapper/` |
| `bloc_depends_on_abstractions` | same package swap |
| `equatable_props_complete` | as-is |
| `platform_io_outside_io_files` | ported for parity, but **dormant** — BabyClapper has no `dart:io` usage and no web target. Must be documented as NOT reintroducing a web-stub requirement (that would contradict the mobile-only mandate). |
| `file_header_required` | as-is; requires headers on every hand-written `lib/**.dart` file (see §D) |

**`tools/baby_clapper_lints/example/`** — fixtures package with `// expect_lint:` assertions. Getman ships **no fixture for `avoid_get_it_in_widgets`**, violating its own "every rule ships a fixture" mandate. **BabyClapper must ship a fixture for all 7 rules**, closing that gap.

**Root `analysis_options.yaml`** — mirror Getman's: VGA include; `analyzer.exclude` (generated + `tools/**`); `analyzer.plugins: [custom_lint]`; `errors: close_sinks: warning`; the pinned `linter.rules` block; the `bloc:` rules block (for `bloc_lint`); and the opt-in `custom_lint:` block listing the 7 rules plus 3 `solid_lints` metric gates.

**solid_lints thresholds:** port Getman's values verbatim (`cyclomatic_complexity: 50`, `number_of_parameters: 50`, `function_lines_of_code: 1000`) as decided, **but add a comment recording BabyClapper's measured baseline** next to them. Getman documents these numbers as driven by a ~937-line test `main()` that does not exist here; without the note a reader cannot tell the gate is currently unfireable, and tightening later becomes guesswork. Also carry Getman's YAML warning: each `max_*` key must be a **sibling** of the rule name at the same indentation, never nested — nesting silently reverts to the default.

**Dev-dependencies:** `custom_lint`, `solid_lints`, `bloc_lint`, `bloc_tools`, `baby_clapper_lints` (path), alongside the existing `very_good_analysis`.

**`tool/coverage.sh`** — port; replace Getman-specific lcov excludes (`hive_registrar.g.dart`, `update_gate_io.dart`, `dio_adapter_config_io.dart`) with BabyClapper's equivalents, keeping the generic `*.g.dart` / `lib/main.dart` excludes.

### C. PR checks / CI (port from Getman)

- **`.github/workflows/ci.yml`** — the `checks` job (pinned `FLUTTER_VERSION`, `subosito/flutter-action`, `continue-on-error` per gate with `| tee` logs, the PR-comment builder with filtered lcov coverage, artifact upload, and the final gating step that fails if any gate failed), plus the `secrets` (gitleaks) and `osv-scan` jobs. **Omit the `build_runner`/codegen step** (no codegen in BabyClapper) and **omit `build-web`**. Use the **standalone OSV action**, not the reusable workflow — Getman moved off the reusable workflow because its hard-declared `security-events: write` breaks fork PRs under a `contents: read` caller.
- **`.github/workflows/ci-comment.yml`** — the fork-safe `workflow_run` artifact handoff + sticky comment; change the sticky `header` to a BabyClapper-specific value.
- **`.github/workflows/pr_agent.yml`** — ported as-is. Requires the owner to add a `GEMINI_API_KEY` secret; document that.
- **`.github/dependabot.yml`** — port unchanged (pub + github-actions, weekly, grouped).
- **`.github/PULL_REQUEST_TEMPLATE.md`** — port; drop Hive-codegen and theme-authoring items, keep the analysis done-bar checklist and the wiki-sync / CLAUDE.md-update reminders.
- **`.githooks/pre-commit`** — port the full ordered stack (format → analyze → custom_lint → fixtures self-test → bloc_lint → optional local gitleaks), with the fvm detection and `--no-verify` bypass hint. Enabled via `git config core.hooksPath .githooks`.

### D. Claude-friendliness (port Getman's PR #60 model)

Adopt the **three-tier knowledge placement rule**: file-specific knowledge → that file's own `//` header; cross-file → `docs/architecture/<area>.md`; universal/repo-wide → CLAUDE.md.

1. **`//` header on every hand-written `lib/**.dart` file**, tiered by complexity (Tier 1 one sentence; Tier 2 purpose + collaborators + wiring; Tier 3 + file-local invariants/gotchas). Prose `//`, not `///`. Front-load searchable concept words. Enforced by `file_header_required`.
2. **`docs/CODEMAP.md`** — three sections: directory map (table), "Where is…?" alphabetical concept lookup, and numbered cross-cutting flows. At minimum the two core flows: *swipe → feedback* and *shake → feedback*.
3. **`test/docs/codemap_coverage_test.dart`** — port Getman's self-defending test: every `lib/` directory containing hand-written Dart must appear in CODEMAP.md.
4. **`docs/architecture/*.md`** — one per subsystem, each opening with the one-line "loaded on demand — see the routing table in CLAUDE.md; for where-is-X use docs/CODEMAP.md" backlink. BabyClapper's subsystems: `app-shell.md` (boot, DI, immersive/lifecycle, error model) and `rattle-feedback.md` (gesture surface → bloc → haptics/audio/motion, the feedback math, degradation rules).
5. **CLAUDE.md slimmed to a lean core** — identity, compressed tech-stack table, a **Navigation section** with the "Touching… / Read first" routing table pointing at CODEMAP + the architecture docs, mandatory rules, the build/verification bar, and a short *global-only* gotchas list. The current §3 architecture deep-dive moves out into `docs/architecture/`. Add the standing **"Design for Claude"** mandate so future work keeps obeying the convention. Delete the ⚠️ "current state" note in §4 once the tooling is real, and fix the stale claim that OSV runs via a reusable workflow.
6. **`docs/BACKLOG.md`** — Getman's format: a *Current state* snapshot, items grouped by category with stable IDs carrying **Files / Problem (with evidence) / Fix / Effort / Verify**, a *Deferred / Non-goals* section, and a *Working agreement (how to resume)* at the bottom. Seed it with the real outstanding work: on-device tuning of the four constants, deferred settings/persistence, deferred theming, and the carried Minor findings from the vertical-slice reviews.
7. **`GEMINI.md` symlink** — already present; verify it survives.

## Verification bar (after this work, all must be clean)

```
fvm flutter analyze
fvm dart run custom_lint
( cd tools/baby_clapper_lints/example && fvm dart run custom_lint )
fvm dart run bloc_tools:bloc lint lib
fvm dart format --output=none --set-exit-if-changed lib test tools
fvm flutter test
```

Existing behaviour must not regress: the 17 existing tests stay green, and no runtime behaviour changes in this work — it is tooling, structure, and documentation only.

## Out of scope

- `build-web` job, `pages.yml`, `release.yml` (no web/desktop targets).
- Mobile release tooling (Fastlane / App Store Connect / Play Console) — a separate future effort.
- Settings persistence, theming, `flutter_animate` visuals — still deferred from the vertical slice.
- On-device tuning of the rattle constants — requires hardware.

## Success criteria

- All six verification-bar commands pass.
- `git config core.hooksPath .githooks` makes the hook enforce the same gates locally.
- CI is green on a PR, posts a single sticky summary comment, and no workflow fails due to a missing platform target.
- Every `lib/**.dart` file has a `//` header; `file_header_required` and the CODEMAP coverage test both pass and would fail if the convention decayed.
- CLAUDE.md contains no claim about tooling that does not exist.
