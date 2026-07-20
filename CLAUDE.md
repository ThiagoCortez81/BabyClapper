# BabyClapper — Project Documentation & Mandates

BabyClapper is a tactile, sensory Flutter app that behaves like a digital rattle. Swiping a finger across the screen produces the *sensation of movement* through differentiated haptic feedback — each gesture vibrates differently depending on the action — and moving or shaking the device triggers both vibration and sound, like a real rattle.

> **Open work:** a prioritized, verified backlog of remaining tasks lives in
> [`docs/BACKLOG.md`](docs/BACKLOG.md) (file paths + evidence + suggested fix +
> a working agreement per item). Start there to pick up where the last session
> left off.

> **User-facing docs:** the feature wiki is published at
> <https://github.com/ThiagoCortez81/BabyClapper/wiki> (source: the separate
> `BabyClapper.wiki.git` repo). It must be kept in sync with the app — see the
> **Keep the wiki in sync** mandate in §6 Workflow.

---

## 1. Tech Stack

- **Flutter SDK**: pinned via `.fvmrc` — always invoke as `fvm flutter ...`, never plain `flutter`.
- **Platform**: **iOS + Android only.** Haptics and motion sensors are mobile-only capabilities — there are no web or desktop targets, so we do **not** ship web-safety stubs or conditional (`_io`/`_stub`) imports. Anything touching the platform can assume a real device.
- **Display**: **fullscreen, edge-to-edge.** The app runs immersive — `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` is set at startup (system bars hidden, swiped-in bars auto-hide) — and `wakelock_plus` keeps the screen awake while the rattle is in use. Re-assert the immersive mode on resume (`AppLifecycleState.resumed`) since the OS can restore the bars.
- **State**: `flutter_bloc` (strict UI/business-logic separation). All states and events are `Equatable`.
- **DI**: `get_it` (see `lib/core/di/injection_container.dart`). `GetIt` is referenced only from `main.dart` and DI setup — **never from widgets**.
- **Haptics**: `vibration` — custom vibration **patterns, duration, and amplitude** (this is what makes each gesture *feel* different). Fall back to Flutter's built-in `HapticFeedback` (`lightImpact` / `selectionClick`) for quick canned taps where a full pattern is overkill. Always check `Vibration.hasVibrator()` / `hasAmplitudeControl()` and degrade gracefully.
- **Sound (SFX)**: `soundpool` — low-latency, **concurrent** playback of short samples (rattle beads reacting instantly to motion). `audioplayers` is the fallback for any streaming/looping need.
- **Audio focus**: `audio_session` — configure a playback session so the rattle ducks/coexists with other audio and respects the ringer/silent switch as intended.
- **Motion**: `sensors_plus` — the accelerometer/user-accelerometer stream detects movement and scales vibration + sound **intensity** to how hard the device is moved.
- **Shake**: `shake` — discrete "shaken!" trigger built on top of the raw accelerometer stream, for the rattle's headline gesture.
- **Gestures**: built-in `Listener` / `GestureDetector` — raw pointer-move deltas and velocity drive the swipe "sensation of movement." No package.
- **Visual feedback**: `flutter_animate` — the screen reacts visually to swipes and shakes to reinforce the movement sensation.
- **Settings persistence**: `shared_preferences` — tiny key-value for user preferences (haptic intensity, sound on/off, selected rattle). No structured/relational data, so no Hive.
- **Reactive helpers**: `collection` (for `firstWhereOrNull`, `ListEquality`, etc.).
- **Style**: `google_fonts`.
- **Static analysis** (four independent passes — all part of the done-bar, see §4): `very_good_analysis` (strict lint baseline, via `fvm flutter analyze`; also enforces `close_sinks` + `discarded_futures`); `custom_lint` running the project-local architecture rules in `tools/baby_clapper_lints/` plus the `solid_lints` metric gates (via `fvm dart run custom_lint`); the `baby_clapper_lints` fixtures self-test (`cd tools/baby_clapper_lints/example && fvm dart run custom_lint`); and `bloc_lint` (the bloc team's rules, via `fvm dart run bloc_tools:bloc lint lib`). All four are gated by the `.githooks/pre-commit` hook (+ `dart format`). CI additionally runs OSV-Scanner (dependency vulnerability scan) and Dependabot (automated dependency update PRs).

---

## 2. Project Structure (Feature-First + Clean Architecture)

```
lib/
  core/
    di/              # GetIt bootstrap (injection_container.dart)
    error/           # Failure / Exception hierarchy
    haptics/         # HapticService — vibration patterns (vibration pkg) + HapticFeedback fallback
    audio/           # SoundService — soundpool sample pool + audio_session config
    motion/          # MotionService — sensors_plus accelerometer stream + shake detection
    system/          # ImmersiveMode (fullscreen) + wakelock lifecycle
    settings/        # SettingsStore over shared_preferences (intensity, sound on/off, selected rattle)
    theme/           # ThemeData + palette/typography extensions
    ui/widgets/      # Cross-feature widget atoms
    utils/
  features/
    rattle/
      domain/        # Entities (RattleProfile, GestureEvent) + abstract services + use cases (pure Dart)
      data/          # Service impls (haptic / audio / motion plugin adapters)
      presentation/  # RattleBloc (event/state) + the fullscreen rattle screen + gesture surface
  main.dart          # Bootstrap: immersive mode, DI init, MultiBlocProvider, MaterialApp
```

The app is essentially **one feature** (`rattle`) sitting over a few core services. As it grows, add sibling features under `lib/features/` following the same `domain` / `data` / `presentation` split.

Mandatory rules:
- **Domain layer has zero imports from `data/` or Flutter UI.** Only pure Dart + `equatable`.
- **BLoCs depend on abstract service/repository types**, never on concrete `...Impl`s or plugin packages (`vibration` / `soundpool` / `sensors_plus`) directly.
- **Generic, reusable atoms** go in `lib/core/ui/widgets/`. Feature-specific widgets stay inside that feature.
- **Platform plugins are wrapped behind a core service** (`HapticService` / `SoundService` / `MotionService`) — widgets and blocs never touch a plugin API directly, so behavior stays unit-testable with fakes.

---

## 3. Architecture Deep-Dive (proposed — grow as built)

> BabyClapper has no implementation yet; this is the **intended** shape. Update each subsection as the real code lands.

### 3.1 Boot sequence (`main.dart` + `injection_container.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. **Enter fullscreen** — `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` (lock preferred orientation if the design calls for it).
3. `di.init()` — read `SettingsStore` (`shared_preferences`) synchronously, then register `HapticService`, `SoundService`, `MotionService`, and `RattleBloc`.
4. **Warm the audio pool** — `SoundService` preloads the rattle samples into `soundpool` and configures `audio_session` *before* first play; a cold sample load would swallow the first shake's sound.
5. **Acquire wakelock** (`wakelock_plus`) so the screen stays on while the app is foregrounded.
6. `runApp` with a `MultiBlocProvider` exposing `RattleBloc`. Re-assert immersive mode on `AppLifecycleState.resumed` (the OS can restore the system bars).

### 3.2 Rattle feature (the whole app)
- `RattleBloc` holds the active `RattleProfile` (which vibration pattern + sample set) plus the reduced settings (intensity, sound on/off).
- **Gesture surface**: a full-screen `Listener` / `GestureDetector` turns pointer-move deltas + velocity into `GestureEvent`s. Swipe speed and direction pick the vibration pattern, the sample, and the playback rate — this is the "sensation of movement."
- **Motion**: `MotionService` streams accelerometer magnitude; a shake (via the `shake` package, or a magnitude threshold) fires a discrete `RattleShaken` event, while sustained movement scales intensity continuously.
- On each event `RattleBloc` calls `HapticService.play(pattern, amplitude)` **and** `SoundService.play(sample, rate/volume)`. Haptics and audio fire together but **independently** — one degrading (no vibrator, silent switch) must never block the other.
- Everything is **rate-limited** so a fast swipe doesn't queue thousands of vibrations/samples — coalesce to the device's realistic feedback cadence.

### 3.3 Core services (plugin adapters)
- **`HapticService`** (`core/haptics/`) wraps the `vibration` package: checks `hasVibrator()` / `hasAmplitudeControl()` once at init, exposes `play(pattern)` / `playAmplitude(intensity)`, and no-ops gracefully when unsupported. `HapticFeedback` is the canned fallback.
- **`SoundService`** (`core/audio/`) owns the `soundpool` instance + loaded sample ids, configures `audio_session`, and exposes `play(sample, {rate, volume})` with concurrent voices. Disposes the pool on teardown.
- **`MotionService`** (`core/motion/`) exposes a broadcast `Stream` of motion intensity plus a shake-event stream off `sensors_plus`; all subscriptions are cancelled on `close()` (`close_sinks` lint).
- **Plugin APIs never leak past these services** — blocs and widgets depend on the abstract service types, so they're testable with fakes.

### 3.4 Settings
- `SettingsStore` over `shared_preferences`: `hapticIntensity` (0–1), `soundEnabled` (bool), `selectedRattle` (id). Loaded synchronously at boot, written immediately on change. No async `LoadSettings` event.

### 3.5 Error model
- `core/error/` keeps the `Failure` / `Exception` hierarchy. Service adapters catch plugin/platform errors and surface typed `Failure`s; a missing capability (no vibrator, audio-focus denied) is a **graceful-degrade** path, never a crash.

### 3.6 Fullscreen / lifecycle
- Immersive mode (`immersiveSticky`) is set at boot and **re-asserted on resume**. Wakelock is enabled while foregrounded, released on pause. The gesture surface fills the screen **edge-to-edge** — no `SafeArea` insets stealing swipe area; draw under the cutouts.

---

## 4. Build & Test Commands

> **⚠️ Current state (as of the rattle vertical slice):** only `fvm flutter analyze`,
> `fvm dart format`, and `fvm flutter test` are runnable today. The `custom_lint` /
> `baby_clapper_lints` fixtures / `bloc_lint` / `tool/coverage.sh` / `.githooks` /
> CI entries below describe the **intended** tooling — that infrastructure has not
> been scaffolded yet (deliberately deferred; see the vertical-slice spec). Don't be
> surprised when those commands fail with "package not found"; wire them up in the
> lint-infra pass, then delete this note.

```
fvm flutter analyze                                           # very_good_analysis — must be 0 issues
fvm dart run custom_lint                                      # BabyClapper architecture rules (tools/baby_clapper_lints) + solid_lints metrics
( cd tools/baby_clapper_lints/example && fvm dart run custom_lint ) # baby_clapper_lints fixtures self-test (verifies rule regressions)
fvm dart run bloc_tools:bloc lint lib                         # bloc_lint (run against lib; stdin closed in CI)
fvm dart format lib test tools                                # formatter — the commit hook enforces it
fvm flutter test                                              # all tests must be green
fvm flutter run                                              # run on the attached iOS/Android device or emulator
bash tool/coverage.sh                                         # unit/widget coverage report (coverage/html/index.html)
```

Verification bar (the `.githooks/pre-commit` hook runs the first five automatically — enable once per clone with `git config core.hooksPath .githooks`): **all of `fvm flutter analyze`, `fvm dart run custom_lint` (the project architecture rules + solid_lints metric gates), the `baby_clapper_lints` fixtures self-test, and `fvm dart run bloc_tools:bloc lint lib` report no issues, the tree is `dart format`-clean, AND `fvm flutter test` is 100% green** before reporting work done. The analysis passes are independent — a clean `flutter analyze` does NOT imply custom_lint/bloc_lint/fixtures are clean (they run as separate processes).

**CI-enforced supply-chain checks (not local):** OSV-Scanner scans `pubspec.lock` for known vulnerabilities on every push/PR (via the `osv-scan` reusable workflow); Dependabot sends automated PRs for outdated pub + GitHub Actions dependencies. These run automatically in CI and do not require a local command.

---

## 5. Gotchas & Conventions (read before editing)

> Project-specific gotchas will accumulate here as BabyClapper is built. The conventions below already bind.

- **Debug logs**: `print` is disallowed (`avoid_print`). **BLoCs use `dart:developer`'s `log(msg, name: '<BlocName>')`** — never `debugPrint` (importing `package:flutter/foundation.dart` into a bloc trips bloc_lint's `avoid_flutter_imports`; blocs stay Flutter-decoupled). Non-bloc layers (use cases, services, widgets) use `debugPrint` for plain traces, but **should prefer `dart:developer`'s `log(..., error:, stackTrace:)` when reporting a caught failure** — `debugPrint` takes only a `String`, so using it there would throw away the error object and stack trace. Degrade paths in the core services and DI bootstrap follow this.
- **Imports are `package:baby_clapper/...` everywhere** (enforced by `always_use_package_imports` + `directives_ordering`). No relative imports.
- **Every platform plugin is wrapped behind a core service.** `vibration` / `soundpool` / `sensors_plus` / `wakelock_plus` are imported only inside their `core/` service (`HapticService` / `SoundService` / `MotionService` / the immersive-mode helper). Widgets and blocs call the service, never the plugin — this keeps the app testable with fakes and the degrade path in one place.
- **Haptics and audio degrade independently.** Check capability first (`hasVibrator()`, audio focus) and no-op gracefully; a missing capability is never a crash, and one channel failing must not block the other.
- **Rate-limit feedback.** A fast swipe or continuous shake must not queue thousands of vibrations/samples — coalesce to a realistic feedback cadence.

---

## 6. Development Mandates

### Architectural
- **Domain first**: new features start with entity + abstract repository + use case. No `data/`, no widgets yet.
- **Dependency inversion**: BLoCs depend on abstract types only.
- **Immutability**: `Equatable` on every state/event; `copyWith` on every entity.
- **GetIt stays in DI**: widgets reach services via `BlocProvider`, `RepositoryProvider`, or constructor injection. Never `sl<T>()` from a widget.

### UI / Styling
- **Theme adherence**: read sizing/colors/weights/shapes through `context.appLayout`, `context.appPalette`, `context.appShape`, `context.appTypography`, `context.appDecoration`. No hardcoded font sizes, font weights, colors, radii, or paddings in widgets — if a value isn't in an extension, add a field to that extension rather than hardcoding.
- **Atomic design**: reusable widgets → `lib/core/ui/widgets/`.

### Workflow
- **Verify before claiming done**: a feature is NOT done until the full static-analysis stack is clean **and** tests are green. Run, and confirm zero issues from, **all** of: `fvm flutter analyze` (very_good_analysis), `fvm dart run custom_lint` (BabyClapper architecture rules), and `fvm dart run bloc_tools:bloc lint lib` (bloc_lint), and the baby_clapper_lints fixtures self-test (`cd tools/baby_clapper_lints/example && fvm dart run custom_lint`) — plus `fvm dart format` cleanliness and `fvm flutter test`. These are separate passes; never assume a clean `flutter analyze` covers custom_lint or bloc_lint. The `.githooks/pre-commit` hook enforces the analysis + format gate on every commit (`git config core.hooksPath .githooks` to enable per clone; bypass only via `--no-verify`).
- **New custom_lint rules go in `tools/baby_clapper_lints/`**: it is its own package (`custom_lint_builder` plugin) excluded from the app analyzer. Every new rule **must ship a `// expect_lint:` fixture** in `tools/baby_clapper_lints/example/lib/` — the fixtures self-test is part of the pre-commit hook and CI gate so rule regressions are caught immediately. Run `( cd tools/baby_clapper_lints/example && fvm dart run custom_lint )` to verify fixtures locally. Suppress a justified exception with a per-line `// ignore: <rule>` + a one-line reason (note: `equatable_props_complete` is anchored to the class name, so the `// ignore:` must be directly above the class declaration, not above a field).

  The full set of rules **planned** for `tools/baby_clapper_lints/` (not yet
  scaffolded — see the ⚠️ current-state note in §4; the gates listed in this
  section become binding once that package exists):
  - `avoid_get_it_in_widgets` — no `sl`/`GetIt` outside `lib/core/di/` + `main.dart`.
  - `avoid_hardcoded_brand_colors` — no `Colors.black/white/red` outside `lib/core/theme/`.
  - `domain_no_infrastructure_imports` — files under `*/domain/` must not import `package:flutter/`, `dart:ui`, `dart:io`, `package:vibration/`, `package:soundpool/`, `package:sensors_plus/`, or any sibling `data/` path. Keeps the domain layer pure Dart.
  - `bloc_depends_on_abstractions` — BLoC files (matched by `*_bloc.dart` / `*_cubit.dart`) must not import concrete data-layer packages (`package:vibration/`, `package:soundpool/`, `package:sensors_plus/`, or project `*/data/*.dart` paths). BLoCs depend on abstract service/repository types only.
  - `equatable_props_complete` — classes that **directly** `extends Equatable` or `with EquatableMixin` must include all declared instance fields in `props`; missing fields cause silent equality bugs. (Indirect subclasses are not checked; only the class that directly extends/mixins Equatable is.)

  **`solid_lints` metrics** (regression-gate baselines, not style targets): `cyclomatic_complexity: 50`, `number_of_parameters: 50`, `function_lines_of_code: 1000`. These are intentionally permissive — they catch new runaway additions, not pre-existing complexity. Note: the `function_lines_of_code` threshold appears inflated in practice because the standalone `custom_lint` runner reads `analysis_options.yaml` at the package root (which includes the test directory); large test files count toward FLOC. Refactor existing functions below these limits opportunistically, but do not let new code exceed them.

  **`very_good_analysis` extras now on**: `close_sinks` (unmatched stream-sink `close()` calls) and `discarded_futures` (fire-and-forget `Future` values not explicitly unawaited or handled) — both are enabled in `analysis_options.yaml` and enforced by `flutter analyze`.

  **DCM (unused-code/files) is a planned follow-up** — DCM's free tier currently requires a license key; it will be wired into CI after DCM relicenses to MIT on 2026-07-16. Do not wire it before that date.
- **Surgical edits**: don't restructure unrelated code. One concern per change.
- **Keep the wiki in sync**: any change that adds or alters how a feature is *used* — a new feature, a new/renamed setting, a changed gesture or haptic/sound pattern, a renamed UI label, changed defaults or limits — must be reflected in the GitHub wiki as part of the same work, not deferred. The wiki is the separate `BabyClapper.wiki.git` repo: clone `https://github.com/ThiagoCortez81/BabyClapper.wiki.git`, edit the relevant `*.md` page (one per feature; nav lives in `_Sidebar.md`, and add a page there if you create one), then commit + push (default branch `master`); it serves at <https://github.com/ThiagoCortez81/BabyClapper/wiki>. Keep wording accurate to the code (verbatim UI labels). Purely internal refactors with no behavior/usage change don't need a wiki edit. (One-time setup only: a brand-new wiki's `.wiki.git` 404s on clone/push until its first page is created in the web UI — no API exists for that; ours is already initialized.)
