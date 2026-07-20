# BabyClapper — Project Documentation & Mandates

BabyClapper is a tactile, sensory Flutter app that behaves like a digital
rattle. Swiping a finger across the screen produces the *sensation of
movement* through differentiated haptic feedback, and shaking the device
triggers both vibration and sound, like a real rattle.

This CLAUDE.md is the **lean core** — mandates + a routing table, nothing
more. Deep-dive knowledge lives in `docs/architecture/*.md` (one per
subsystem) and in each file's own `//` header. Keep it that way (see
**Design for Claude** below).

## Tech stack

Flutter SDK is pinned via `.fvmrc` — **always invoke as `fvm flutter …` /
`fvm dart …`, never plain `flutter`/`dart`.** Platform is **iOS + Android
only** — haptics and motion sensors are mobile-only capabilities, so there
is no web/desktop target and no web-safety stub (`_io`/`_stub`) convention.
The app runs **fullscreen, edge-to-edge** (immersive-sticky system UI +
`wakelock_plus`, re-asserted on `AppLifecycleState.resumed`). State uses
`flutter_bloc` with strict UI/business-logic separation; every state/event
is `Equatable`. The swipe gesture surface is the built-in `Listener` — no
gesture package.

| Package | Role | Load-bearing note |
|---|---|---|
| `flutter_bloc` / `bloc` | State management | Strict UI/logic split; `Equatable` everywhere (`equatable_props_complete` lint) |
| `get_it` | DI | Only in `lib/core/di/` + `main.dart` — never widgets/blocs (`avoid_get_it_in_widgets` lint) |
| `vibration` | Haptics | Amplitude/duration-controlled patterns; checks `hasVibrator()`/`hasAmplitudeControl()` once at init; falls back to a fixed-duration buzz when there's no amplitude control |
| `soundpool` | SFX playback | Low-latency concurrent sample playback (bead + rattle `.wav`); volume is set *before* `play()` (attack-transient invariant — see rattle-feedback.md) |
| `audio_session` | Audio focus | `ambient` category on iOS respects the silent switch and mixes with other audio; Android deliberately never calls `setActive` (no focus ever requested) |
| `sensors_plus` | Motion | `userAccelerometerEventStream()` (gravity already removed) drives shake detection |
| `wakelock_plus` | Screen-on | Enabled while foregrounded via `ImmersiveMode`, released on `paused`/`hidden` |
| `equatable` | Immutability | Every state/event `Equatable`, every entity would get `copyWith` |

Settings persistence, theming, and a `core/error` Failure hierarchy are
deferred — not dependencies yet. See `docs/BACKLOG.md`'s Deferred section.

## Navigation

**Finding anything: start at [`docs/CODEMAP.md`](docs/CODEMAP.md)** — the
master "where is X?" index (directory map + concept lookup + cross-cutting
flows). Every `lib/` file also opens with a `//` header; read it for
file-level detail.

**Read-before-editing routing table** — before touching an area, read its
doc:

| Touching… | Read first |
|---|---|
| Boot, DI, immersive mode/wakelock lifecycle, logging convention | [docs/architecture/app-shell.md](docs/architecture/app-shell.md) |
| Gesture surface, `RattleBloc`, haptic/sound/motion services, feedback math | [docs/architecture/rattle-feedback.md](docs/architecture/rattle-feedback.md) |
| Finding anything | [docs/CODEMAP.md](docs/CODEMAP.md) |
| Open work / backlog | [docs/BACKLOG.md](docs/BACKLOG.md) |

The user-facing feature wiki is
<https://github.com/ThiagoCortez81/BabyClapper/wiki> (separate
`BabyClapper.wiki.git` repo) — keep it in sync (see mandates below).

## Project structure (feature-first + clean architecture)

```
lib/
  core/
    di/              # GetIt bootstrap (injection_container.dart)
    system/          # ImmersiveMode — fullscreen SystemChrome + wakelock_plus lifecycle
  features/
    rattle/
      domain/        # Abstract service contracts (Haptic/Sound/MotionService) +
                      # rattle_math.dart (pure feedback math) — zero Flutter/plugin imports
      data/          # Plugin adapters implementing the domain contracts
                      # (vibration / soundpool+audio_session / sensors_plus)
      presentation/
        bloc/        # RattleBloc + RattleEvent + RattleState
        screens/     # RattleScreen — fullscreen edge-to-edge gesture surface
  main.dart          # Bootstrap: immersive mode, DI init, MaterialApp + BlocProvider<RattleBloc>
```

The app is essentially **one feature** (`rattle`) sitting over two `core/`
services (`di`, `system`). As it grows, add sibling features under
`lib/features/` following the same `domain`/`data`/`presentation` split.

## Mandatory rules

**Architecture**
- **Domain first**: new features start with an entity + abstract
  service/repository + use case. No `data/`, no widgets yet.
- **Domain layer is pure Dart** (+ `equatable`): zero imports from Flutter,
  `dart:ui`/`dart:io`, a platform plugin package (`vibration`, `soundpool`,
  `sensors_plus`, `audio_session`, `wakelock_plus`), or a sibling `data/` —
  enforced by `domain_no_infrastructure_imports`.
- **BLoCs depend on abstract service types only** — never a concrete
  `...Impl` or a plugin package directly — enforced by
  `bloc_depends_on_abstractions`.
- **DI stays in DI**: widgets/blocs reach services via `BlocProvider` or
  constructor injection — never `sl<T>()` from a widget — enforced by
  `avoid_get_it_in_widgets`.
- **Immutability**: `Equatable` on every state/event (`equatable_props_complete`
  lint); `copyWith` on every entity.
- **Every platform plugin is wrapped behind a core service.** `vibration` /
  `soundpool` / `sensors_plus` / `audio_session` / `wakelock_plus` are
  imported only inside their feature `data/` service (or `core/system/` for
  wakelock) — widgets and blocs never touch a plugin API directly, so
  behavior stays unit-testable with fakes.
- **Haptics and audio degrade independently.** Check capability first
  (`hasVibrator()`, sample-load success) and no-op gracefully; a missing
  capability is never a crash, and one channel failing must never block the
  other (`RattleBloc._guard`, `injection_container.dart`'s `_initSafely`).
- **Rate-limit feedback.** A fast swipe or continuous shake must not queue
  thousands of vibrations/samples — coalesce to a realistic feedback
  cadence (`kSwipeThrottle`, `kShakeCooldown` in `rattle_math.dart`).

**UI / styling**
- **Theme adherence — policy, not yet infrastructure.** Once a theme layer
  exists, sizing/colors/weights/shapes route through theme extensions
  (`context.appLayout`/`.appPalette`/`.appShape`/`.appTypography`-style) —
  never hardcoded in widgets. That layer is deferred (see `docs/BACKLOG.md`
  "Deferred / Non-goals"); until it lands, don't invent new one-off magic
  numbers where an existing constant would do.
- **No hardcoded brand colors**: `Colors.black`/`white`/`red` families are
  banned outside `lib/core/theme/` — enforced today by the
  `avoid_hardcoded_brand_colors` custom lint, active even though that
  directory doesn't exist yet (its exemption is simply unused until
  theming lands).
- **Atomic design**: reusable widgets go in `lib/core/ui/widgets/` once
  cross-feature reuse exists; feature-specific widgets stay in the feature.

**Conventions**
- **`package:baby_clapper/…` imports everywhere** — no relative imports
  (enforced by `always_use_package_imports` + `directives_ordering`).
- **Logging**: `print` is banned (`avoid_print`). **BLoCs use
  `dart:developer`'s `log(msg, name: '<BlocName>')`** — never `debugPrint`
  (importing `package:flutter/foundation.dart` into a bloc trips bloc_lint's
  `avoid_flutter_imports`; blocs stay Flutter-decoupled). Non-bloc layers use
  `debugPrint` for quick unstructured traces, but prefer the same
  `dart:developer` `log(..., error:, stackTrace:)` when reporting a caught
  failure — `debugPrint` only takes a `String` and would drop the error
  object and stack trace.
- **Surgical edits**: don't restructure unrelated code. One concern per
  change.
- **Keep the wiki in sync**: any change that adds or alters how a feature is
  *used* — a new feature, a new/renamed setting, a changed gesture or
  haptic/sound pattern, a renamed UI label, changed defaults or limits —
  must be reflected in the GitHub wiki as part of the same work, not
  deferred. The wiki is the separate `BabyClapper.wiki.git` repo: clone
  `https://github.com/ThiagoCortez81/BabyClapper.wiki.git`, edit the
  relevant `*.md` page (nav in `_Sidebar.md`, add a page there if you create
  one), commit + push (default branch `master`); it serves at
  <https://github.com/ThiagoCortez81/BabyClapper/wiki>. Keep wording
  accurate to the code (verbatim UI labels). Purely internal refactors with
  no behavior/usage change don't need a wiki edit.

- **Design for Claude.** This codebase is written and maintained by Claude.
  When designing new code: (a) name files and symbols with the words a task
  prompt would use — grep-ability is a design constraint; (b) every new
  hand-written `lib/` file opens with a `//` header per the tier rules
  (lint: `file_header_required`); (c) keep CLAUDE.md lean — new deep-dive
  documentation goes in `docs/architecture/` and gets a routing-table row,
  never inline here; (d) put knowledge at the right layer: file-specific →
  that file's header, cross-file → the architecture doc, universal → here.
  New `lib/` directories and new user-facing concepts get a
  `docs/CODEMAP.md` entry (the coverage test enforces directories).

## Build & verification bar

```
fvm flutter analyze                                           # very_good_analysis — 0 issues
fvm dart run custom_lint                                      # baby_clapper_lints (7 rules) + solid_lints metrics
( cd tools/baby_clapper_lints/example && fvm dart run custom_lint ) # baby_clapper_lints fixtures self-test
fvm dart run bloc_tools:bloc lint lib                         # bloc_lint (stdin closed in CI: < /dev/null)
fvm dart format lib test tools                                # formatter — the commit hook enforces it
fvm flutter test                                              # all tests must be green
fvm flutter run                                               # run on the attached iOS/Android device or emulator
bash tool/coverage.sh                                         # unit/widget coverage report (coverage/html/index.html)
```

Work is **not done** until **all four independent static-analysis passes**
report zero issues — `fvm flutter analyze` (very_good_analysis, incl.
`close_sinks` + `discarded_futures`), `fvm dart run custom_lint` (the seven
baby_clapper_lints architecture rules + three `solid_lints` metric gates),
the baby_clapper_lints fixtures self-test, and
`fvm dart run bloc_tools:bloc lint lib` — **and** the tree is
`dart format`-clean **and** `fvm flutter test` is 100% green. These are
separate processes; a clean `flutter analyze` does **not** imply the others
are clean. The `.githooks/pre-commit` hook runs the first five automatically
(enable once per clone: `git config core.hooksPath .githooks`; emergency
bypass only via `--no-verify`).

**CI adds, beyond the local hook:** gitleaks (secret scan on the PR's
commits) and OSV-Scanner (dependency-vulnerability scan of `pubspec.lock`,
run via the **standalone `google/osv-scanner-action`**, not a reusable
workflow — the reusable workflow hard-declares `security-events: write`,
which a `contents: read` caller can't satisfy and which would also break on
fork PRs); Dependabot sends automated PRs for outdated pub + GitHub Actions
dependencies. **`pr_agent.yml`** (Qodo PR-Agent, backed by Gemini) needs a
repo secret `GEMINI_API_KEY` — until it's provisioned the workflow runs but
its review step fails auth quietly; nothing else depends on it.

The seven `tools/baby_clapper_lints/` rules: `avoid_get_it_in_widgets`,
`avoid_hardcoded_brand_colors`, `domain_no_infrastructure_imports`,
`bloc_depends_on_abstractions`, `platform_io_outside_io_files` (**dormant /
parity-only** — BabyClapper has no `dart:io` usage and no web target, so
this never fires; it's ported verbatim from the sibling Getman project for
cross-project parity and does NOT reintroduce a web-stub (`_io.dart`/
`_stub.dart`) requirement), `equatable_props_complete`, `file_header_required`
(every hand-written `lib/` file must open with a `//` header). Adding a rule
takes two steps, not one: register it in the plugin **and** add its name to
the `custom_lint.rules` allowlist in `analysis_options.yaml` (custom_lint
runs opt-in, `enable_all_lint_rules: false`) — plus ship a
`// expect_lint:` fixture in `tools/baby_clapper_lints/example/lib/` (the
fixtures self-test, which covers all seven, is part of the gate). Suppress a
justified exception with a per-line `// ignore: <rule>` + a one-line reason
(note: `equatable_props_complete` is anchored to the class name, so the
`// ignore:` must sit directly above the class declaration, not above a
field).

The three `solid_lints` metrics are permissive regression-gate baselines,
not style targets — `cyclomatic_complexity: 50`, `number_of_parameters: 50`,
`function_lines_of_code: 1000` — inherited from Getman for cross-project
parity. BabyClapper's measured maxima are far below them (~3 / ~3 / ~77
across `lib/` + `test/`), so these gates cannot currently fire; see
`docs/BACKLOG.md` to tighten them.

`close_sinks` (unmatched stream-sink `close()`/`dispose()` calls) and
`discarded_futures` (fire-and-forget `Future`s not explicitly `unawaited` or
handled) are enabled on top of the `very_good_analysis` baseline in
`analysis_options.yaml` and enforced by `flutter analyze`.

## Global gotchas

Only repo-wide ones live here; area-specific gotchas are in the
architecture docs, file-specific ones in each file's `//` header.

- **`print` is banned everywhere** (`avoid_print`); BLoCs log via
  `dart:developer`'s `log(...)`, never `debugPrint` (see "Conventions"
  above for why).
- **No web/desktop target, ever** — don't add `_io`/`_stub` conditional-import
  scaffolding; `platform_io_outside_io_files` stays dormant on purpose (see
  `docs/BACKLOG.md` non-goals).
- **The four feedback-tuning constants in `rattle_math.dart`
  (`kVelocityDivisor`, `kShakeThreshold`, `kShakeCooldown`,
  `kSwipeThrottle`) have never been validated on real hardware** — treat
  them as provisional (see `docs/BACKLOG.md`).
- **`solid_lints`'s three metric gates can't currently fire** — thresholds
  are inherited from Getman, not calibrated to BabyClapper's much smaller
  measured maxima; don't rely on them to catch a regression today.
