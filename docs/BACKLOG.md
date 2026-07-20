# BabyClapper — Backlog

> **How this is organized.** Open work is grouped **by category** below.
> Each item has a stable ID (survives reorgs), the files it touches, the
> problem with evidence, a suggested fix, a rough effort (S/M/L), and how to
> verify it. This backlog tracks **open work only** — completed items are
> dropped (git history + `CLAUDE.md` are the record of what shipped). The
> working agreement is at the bottom.

## Current state

- Branch `feat/getman-parity-tooling`. All six verification-bar gates are
  green: `fvm flutter analyze`, `fvm dart run custom_lint`, the
  `baby_clapper_lints` fixtures self-test, `fvm dart run
  bloc_tools:bloc lint lib`, `fvm dart format` (clean), `fvm flutter test`
  (18/18).
- The rattle vertical slice is feature-complete: swipe → haptic tick + bead
  sound, shake → haptic burst + rattle sound, both degrading independently
  on a missing capability. Feature-first layered under
  `lib/features/rattle/{domain,data,presentation}` + `lib/core/{di,system}`.
- Tooling parity with the sibling Getman project is done: 7
  `baby_clapper_lints` architecture rules + fixtures, `solid_lints` metric
  gates, `bloc_lint`, CI (analyze / custom_lint / fixtures / bloc_lint /
  format / test, plus gitleaks + OSV-Scanner), a `.githooks/pre-commit`
  hook, `docs/CODEMAP.md` + its coverage test, two `docs/architecture/*.md`
  deep-dives, this backlog, and a lean `CLAUDE.md`.
- No settings UI, no theme layer, no `core/error` hierarchy, and no release
  pipeline exist yet — all deferred (see below).

---

# Open backlog (by category)

## 🎚️ Feedback tuning

### FB1 — On-device calibration of the four rattle constants
- **Files**: `lib/features/rattle/domain/rattle_math.dart`.
- **Problem**: `kVelocityDivisor` (4.0), `kShakeThreshold` (15.0 m/s²),
  `kShakeCooldown` (300ms), and `kSwipeThrottle` (40ms) were chosen
  analytically during the vertical slice and have never been validated
  against a real hand swiping/shaking a real phone. Evidence: every one of
  the four constants' doc comments in `rattle_math.dart` says "Tune this on
  real hardware"; `docs/architecture/rattle-feedback.md`'s tuning-constants
  section repeats "Tune all four on real hardware — they encode device-feel,
  not arbitrary constants — and expect them to move as the app is tested on
  more devices."
- **Fix**: On a physical iOS + Android device, swipe/shake test each
  constant (does a slow swipe feel too intense? does a gentle shake
  false-trigger? does a fast swipe queue perceptibly-delayed feedback?) and
  adjust. Update the doc comments in `rattle_math.dart` and the table in
  `docs/architecture/rattle-feedback.md` with the validated values and the
  reasoning, once chosen.
- **Effort**: M (hardware access + iterative feel-testing, not code
  complexity).
- **Verify**: `test/features/rattle/domain/rattle_math_test.dart` stays
  green after any constant change (it asserts behavior/thresholds, not the
  literal values); manual on-device feel check for the actual product bar.

---

## 🔧 Tooling

### TL1 — `solid_lints` metric thresholds are inherited, not calibrated
- **Files**: `analysis_options.yaml` (the `custom_lint.rules`
  `cyclomatic_complexity` / `number_of_parameters` /
  `function_lines_of_code` block).
- **Problem**: thresholds (`50` / `50` / `1000`) were ported verbatim from
  Getman for cross-project parity, not measured against BabyClapper.
  `analysis_options.yaml`'s own comment records BabyClapper's measured
  maxima across `lib/` + `test/` as ~3 cyclomatic complexity (e.g.
  `SensorsMotionService._onAccel`), ~3 parameters (e.g. `isShakeDue`,
  `RattleBloc`'s constructor), and ~77 function lines (the largest test
  `main()`) — meaning none of the three gates can fire on any plausible
  regression today.
- **Fix**: Tighten to values with real headroom above the measured maxima
  (e.g. something in the 10–15 / 6–8 / 150–200 range) once the codebase has
  grown past the vertical slice, so the gate catches a genuine runaway
  addition instead of being permanently green by construction. Not urgent —
  there's no known violation waiting to be caught — but the current values
  give zero regression protection.
- **Effort**: S.
- **Verify**: `fvm dart run custom_lint` stays clean at the new thresholds
  against the then-current `lib/` + `test/`.

---

## 🧹 Minor cleanup (carried from the vertical-slice review history)

### CL1 — `swipeIntensity` is computed twice per swipe tick
- **Files**: `lib/features/rattle/presentation/bloc/rattle_bloc.dart`
  (`_onSwipeTick`), `lib/features/rattle/domain/rattle_math.dart`
  (`beadPlayback`).
- **Problem**: `_onSwipeTick` calls `swipeIntensity(event.velocity)`
  directly *and* `beadPlayback(event.velocity)`, and `beadPlayback`
  internally recomputes `swipeIntensity` for the same velocity — the same
  divide-and-clamp runs twice per dispatched `SwipeTick`. Harmless today
  (`swipeIntensity` is O(1) arithmetic) but a DRY nit flagged during the
  vertical-slice reviews and never cleaned up.
- **Fix**: Have `beadPlayback` accept a pre-computed intensity parameter (or
  have `_onSwipeTick` derive the bead's rate/volume from the single
  `intensity` value it already holds) so the computation happens once per
  tick.
- **Effort**: S.
- **Verify**: `test/features/rattle/domain/rattle_math_test.dart` and
  `test/features/rattle/presentation/bloc/rattle_bloc_test.dart` stay green
  with unchanged output values (pure refactor, no behavior change).

### CL2 — `SoundService.dispose()` / `MotionService.dispose()` are never called
- **Files**: `lib/features/rattle/domain/sound_service.dart`,
  `lib/features/rattle/data/soundpool_sound_service.dart`,
  `lib/features/rattle/domain/motion_service.dart`,
  `lib/features/rattle/data/sensors_motion_service.dart`,
  `lib/core/di/injection_container.dart`.
- **Problem**: both services declare and implement `dispose()` (sample-pool
  teardown / accelerometer-subscription cancellation), but
  `injection_container.dart` never calls either — documented as deliberate
  in `docs/architecture/app-shell.md` ("`SoundService` and `MotionService`
  are intentionally never disposed from `injection_container.dart`: both are
  app-lifetime singletons that live for the process's whole life"). Correct
  for today's single-screen app, but worth tracking rather than assuming
  it stays true forever — `dispose()` is currently dead code outside tests.
- **Fix**: No action needed while the app has one screen and one DI
  container for its whole lifetime. Revisit if the app grows a lifecycle
  where these services need to be torn down and recreated (e.g. a future
  settings screen that swaps the selected rattle profile and needs a fresh
  `SoundpoolSoundService`).
- **Effort**: S, if ever acted on.
- **Verify**: N/A today — tracked for awareness, not a pending code change.

### CL3 — Hardcoded surface colour awaiting the theme pass
- **Files**: `lib/features/rattle/presentation/screens/rattle_screen.dart`
  (`color: Color(0xFF1B1B2F)`).
- **Problem**: the fullscreen background colour is a raw `Color()` literal,
  not read from a theme extension. `CLAUDE.md`'s UI/styling mandate calls
  for theme-extension-sourced colors once a theme layer exists, but no
  theme layer exists yet (see Deferred, below) — this is the one open
  exception. Not caught by the `avoid_hardcoded_brand_colors` custom lint,
  since that rule only bans the `Colors.black`/`white`/`red` families, not
  an arbitrary `Color()` literal.
- **Fix**: Once theming lands, replace with the equivalent theme-extension
  read (e.g. `context.appPalette.background`).
- **Effort**: S (bundled into the theming work below, not standalone).
- **Verify**: `fvm dart run custom_lint` stays clean; visual check that the
  background renders identically.

---

## 🚫 Deferred / Non-goals

> Recorded so they stop resurfacing. Distinct from a bug — these are
> intentionally out of scope for the vertical slice and the tooling-parity
> pass that followed it.

- **Settings persistence** (`shared_preferences`) — haptic intensity,
  sound on/off, selected rattle. No settings UI or store exists; the app
  ships one fixed rattle profile today.
- **Theming** (`flutter_animate`, `google_fonts`, `lib/core/theme/` +
  `lib/core/ui/widgets/`, the `context.appLayout`/`.appPalette`/`.appShape`/
  `.appTypography` extensions referenced by `CLAUDE.md`'s UI/styling
  mandate) — visual polish, animated feedback, and the themeable-value
  plumbing. See CL3 above for the one hardcoded value currently waiting on
  it.
- **A `core/error/` Failure/Exception hierarchy** — nothing in the codebase
  currently raises or consumes a typed `Failure`; every service degrades by
  catching and logging (see `docs/architecture/rattle-feedback.md`'s
  degrade-path table). Creating the hierarchy now, with no caller, would be
  dead code.
- **Mobile release tooling** (Fastlane, App Store Connect, Play Console) —
  no release pipeline exists yet; this app has never shipped a build to a
  store.
- **Web/desktop targets** — haptics and motion sensors are mobile-only
  capabilities. BabyClapper is iOS/Android only, permanently, not just "not
  yet."
- **Web-safety `_io.dart`/`_stub.dart` conditional imports** — a direct
  consequence of the non-goal above. The `platform_io_outside_io_files`
  custom lint ships dormant/parity-only for exactly this reason (see
  `CLAUDE.md`'s "Build & verification bar").

---

# Working agreement (how to resume)

1. **One concern per commit.** Write a plain-language subject + a body
   explaining what changed and why; end with
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
2. **TDD for bugs**: write a failing test first, then fix.
3. **Green between commits**: `fvm flutter analyze` + `fvm dart run
   custom_lint` + the `baby_clapper_lints` fixtures self-test + `fvm dart
   run bloc_tools:bloc lint lib` all clean, the tree `fvm dart format`-clean,
   and `fvm flutter test` 100% green — the same bar `CLAUDE.md`'s "Build &
   verification bar" requires before calling anything done.
4. **Architecture and styling mandates** live in `CLAUDE.md`'s "Mandatory
   rules" — domain-first, abstract-only BLoC dependencies, DI-only `GetIt`,
   platform plugins wrapped behind a `core`/feature-`data` service,
   independent haptic/audio degradation, and the wiki-sync rule when a
   change alters how a feature is used.
5. **Never tune `rattle_math.dart`'s constants from a desk** — FB1 above
   requires a real device; a "feels right in the simulator" change is not
   validation.
6. `git config core.hooksPath .githooks` makes the pre-commit hook enforce
   the same gates locally that CI enforces remotely.
