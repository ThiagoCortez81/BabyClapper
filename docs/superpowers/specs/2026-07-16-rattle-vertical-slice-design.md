# BabyClapper — Rattle Vertical Slice (Scaffold) — Design

**Date:** 2026-07-16
**Status:** Approved (design), pending implementation plan
**Scope:** First vertical slice — scaffold the Flutter project and make one real rattle behavior work end-to-end.

## Goal

Stand up the BabyClapper Flutter project over the existing `CLAUDE.md` mandates and deliver a **feel-it-working** slice: a fullscreen surface where dragging a finger buzzes and plays a bead sound (scaled to swipe speed), and physically shaking the device fires a rattle burst (vibration pattern + sound). Haptics and audio are real (not stubbed).

Non-goal: a polished product. This proves the architecture (§3 of `CLAUDE.md`) boots fullscreen with real haptic/audio/motion feedback, and gives a base to grow features on.

## Target & tooling

- **Platforms:** iOS + Android only (per `CLAUDE.md` §1). No web/desktop targets, no web-safety stubs.
- **Flutter:** `3.44.4`, pinned via `.fvmrc`; always invoked as `fvm flutter ...`.
- **Display:** fullscreen immersive (`immersiveSticky`), screen kept awake while foregrounded.

## Project creation

```
fvm flutter create --platforms=ios,android --project-name baby_clapper --org com.thiagocortez .
```

- Bundle id: `com.thiagocortez.baby_clapper` (org is a chosen default; changeable).
- The clean-architecture structure is layered over the generated project; the default counter app is removed.

## Structure (matches CLAUDE.md §3)

```
lib/
  core/
    di/injection_container.dart      # get_it wiring (services + bloc)
    system/immersive_mode.dart       # setEnabledSystemUIMode(immersiveSticky) + wakelock;
                                      #   re-assert on AppLifecycleState.resumed
    haptics/
      haptic_service.dart            # abstract: init(), tick(intensity), burst()
      vibration_haptic_service.dart  # impl over `vibration`; checks hasVibrator/hasAmplitudeControl
    audio/
      sound_service.dart             # abstract: init(), playBead({rate, volume}), playRattle()
      soundpool_sound_service.dart   # impl over `soundpool` + `audio_session`; preloads samples
    motion/
      motion_service.dart            # abstract: Stream<void> shakes, dispose()
      sensors_motion_service.dart    # impl over `sensors_plus`; gravity-removed magnitude + debounced
                                      #   threshold (from rattle_math); cancels subscriptions on dispose
    rattle_math.dart                 # PURE functions (unit-tested): velocity->intensity/rate, shake test
  features/rattle/presentation/
    bloc/
      rattle_bloc.dart
      rattle_event.dart              # RattleInitialized, SwipeTick(velocity), RattleShaken
      rattle_state.dart              # ready + capability flags (Equatable)
    screens/
      rattle_screen.dart             # fullscreen Listener/GestureDetector; throttles pointer moves
  main.dart                          # WidgetsFlutterBinding -> immersive -> di.init -> runApp(MultiBlocProvider)
assets/
  sounds/
    bead.wav                         # generated placeholder: short filtered-noise click
    rattle.wav                       # generated placeholder: burst of beads
```

## Behavior

### Swipe (drag)
1. `rattle_screen.dart` wraps the fullscreen surface in a `Listener` capturing `PointerMove` events.
2. Pointer moves are **throttled** to ~40 ms ticks at the widget layer (so the bloc is never flooded); each tick computes instantaneous velocity (px/ms) from the delta and elapsed time.
3. The widget dispatches `SwipeTick(velocity)` to `RattleBloc`.
4. `RattleBloc` maps velocity → haptic intensity + sound rate/volume via **pure functions in `rattle_math.dart`**, then calls `haptic.tick(intensity)` and `sound.playBead(rate, volume)`.
5. Result: a faster drag produces stronger, denser bead ticks; a slow drag, gentle sparse ones.

### Shake
1. `MotionService` subscribes to `sensors_plus` accelerometer events, computes gravity-removed magnitude.
2. Magnitude crossing a **debounced threshold** — the test and debounce window are pure functions in `rattle_math.dart` — emits on the `shakes` stream. (No separate shake-detection package; one mechanism, unit-tested.)
3. `RattleBloc` (subscribed on init) receives it as `RattleShaken` → `haptic.burst()` (multi-pulse pattern) + `sound.playRattle()`.

### Degradation rules
- Haptics and audio fire **independently**; one failing/unavailable must never block the other.
- Capability checks up front: `hasVibrator()`, `hasAmplitudeControl()`, audio-focus acquisition. Missing capability → graceful no-op, never a crash.

## Boot sequence (`main.dart` + `di.init()`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Enter immersive fullscreen (`ImmersiveMode.enable()`), acquire wakelock.
3. `di.init()` — construct + register `HapticService`, `SoundService`, `MotionService`, `RattleBloc`; each service's `init()` is awaited (audio pool preloaded, capabilities probed) before first frame.
4. `runApp` with a `MultiBlocProvider` exposing `RattleBloc` (dispatches `RattleInitialized`).
5. An app-lifecycle observer re-asserts immersive mode on `resumed`.

## Dependencies

Runtime: `flutter_bloc`, `equatable`, `get_it`, `vibration`, `soundpool`, `audio_session`, `sensors_plus`, `wakelock_plus`. (`shake` is intentionally omitted — shake detection is our own tested threshold over `sensors_plus`; revisit the package only if the hand-rolled detector proves inadequate.)
Dev: `flutter_test`, `bloc_test`, `very_good_analysis`.

Platform config:
- **Android:** add `<uses-permission android:name="android.permission.VIBRATE"/>` to `AndroidManifest.xml`.
- **iOS:** configure the audio session for playback; no extra permission needed for accelerometer or haptics.

## Placeholder sound assets

Two short royalty-free `.wav` files are **generated locally by a script** (filtered white-noise click for `bead.wav`, a short multi-click burst for `rattle.wav`) and committed under `assets/sounds/`, registered in `pubspec.yaml`. They are placeholders to be swapped for real recordings later.

## Testing

- **`rattle_math.dart`** — fully unit-tested pure functions: velocity→intensity/rate curve (bounds, clamping, monotonicity) and the shake threshold/debounce test.
- **`RattleBloc`** — `bloc_test` with fake `HapticService` / `SoundService` / `MotionService`:
  - `RattleShaken` → `haptic.burst()` + `sound.playRattle()` called once.
  - `SwipeTick(v)` → `haptic.tick` + `sound.playBead` called with mapped args.
  - graceful path when a fake reports "unavailable".
- Platform service impls are thin adapters over plugins — **not** unit-tested (no meaningful logic beyond delegation).
- `analysis_options.yaml` uses `very_good_analysis`; `fvm flutter analyze` + `fvm flutter test` must be green.

## Out of scope (deferred to later passes)

- **Lint/CI infra:** `tools/baby_clapper_lints` custom rules, `.githooks/pre-commit`, `.github` CI workflows, `bloc_lint`, `solid_lints`. Only `analysis_options.yaml` (`very_good_analysis`) is added now.
- **Settings:** `SettingsStore` / `shared_preferences` (intensity, sound on/off, selected rattle). `RattleBloc` uses constant defaults for this slice.
- **Visuals/theming:** `flutter_animate` on-screen element, `google_fonts`, theme extensions. The surface is a solid color.
- **Domain layer:** no `features/rattle/domain` entities/use cases yet — `RattleBloc` coordinates the core services directly. Introduced when a second feature or persisted state appears.

## Success criteria

- `fvm flutter analyze` and `fvm flutter test` are green.
- App launches fullscreen (system bars hidden) on an iOS/Android device/emulator.
- Dragging a finger produces speed-scaled vibration + bead sound; shaking the device produces a rattle burst (vibration + sound).
- Removing the vibrator or muting audio degrades gracefully (the other channel still works; no crash).
