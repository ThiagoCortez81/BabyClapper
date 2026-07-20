# BabyClapper Code Map

Start here to find anything. This is the master "where is X?" index for the
whole `lib/` tree.

Three sections:

- **[Directory map](#directory-map)** — every `lib/` directory with a
  one-line purpose and its key files.
- **[Where is…?](#where-is-concept-lookup)** — an alphabetical concept →
  file lookup.
- **[Cross-cutting flows](#cross-cutting-flows)** — the three end-to-end
  chains that span the app: swipe, shake, and boot.

Format note: every directory path is written as a literal string
(`lib/<path>`). The coverage test in `test/docs/codemap_coverage_test.dart`
requires every `lib/` directory that contains hand-written Dart files to
appear below verbatim, so a new file or feature can't silently escape the
map. Each `.dart` file also opens with a `//` header describing it — read
the file's own header for detail beyond the one-liners here.

Architecture at a glance: BabyClapper is essentially **one feature**
(`rattle`) sitting over two `core/` services. `rattle` is split
feature-first + clean architecture: `domain/` (pure Dart abstract service
contracts + feedback math, zero Flutter/plugin imports), `data/` (plugin
adapters implementing those contracts), `presentation/` (`RattleBloc` +
the fullscreen gesture screen). Shared cross-feature code lives under
`lib/core/`. See `CLAUDE.md` for the full mandates.

---

## Directory map

### Root & core

| Path | Purpose | Key files |
|---|---|---|
| `lib` | App entry point + boot sequence. | `main.dart` (immersive mode, DI init, `MaterialApp` + `BlocProvider<RattleBloc>`, the resume/pause lifecycle observer) |
| `lib/core/di` | GetIt bootstrap. | `injection_container.dart` (constructs + isolates-inits the 3 services, registers singletons + the `RattleBloc` factory) |
| `lib/core/system` | Fullscreen presentation service. | `immersive_mode.dart` (`SystemChrome` immersive-sticky + `wakelock_plus`) |

### `rattle` — the whole app: swipe/shake → haptic + sound feedback

| Path | Purpose | Key files |
|---|---|---|
| `lib/features/rattle/domain` | Abstract service contracts + pure feedback math (no Flutter, no plugins). | `haptic_service.dart`, `sound_service.dart`, `motion_service.dart`, `rattle_math.dart` (the 4 tuning constants + velocity/shake math) |
| `lib/features/rattle/data` | Plugin adapters implementing the domain contracts. | `vibration_haptic_service.dart`, `soundpool_sound_service.dart`, `sensors_motion_service.dart` |
| `lib/features/rattle/presentation/bloc` | `RattleBloc` + its events/state. | `rattle_bloc.dart`, `rattle_event.dart`, `rattle_state.dart` |
| `lib/features/rattle/presentation/screens` | Fullscreen edge-to-edge gesture surface. | `rattle_screen.dart` |

---

## Where is…? (concept lookup)

Alphabetical. Each concept points at its primary file(s); read the file's
own `//` header for detail.

| Concept | File(s) |
|---|---|
| Amplitude (vibration intensity → duty cycle) | `lib/features/rattle/data/vibration_haptic_service.dart` |
| App entry / boot sequence | `lib/main.dart`, `lib/core/di/injection_container.dart` |
| Audio session (silent switch respected, mixes with other audio) | `lib/features/rattle/data/soundpool_sound_service.dart` |
| Bead sound (pitch/volume curve + playback) | `lib/features/rattle/domain/rattle_math.dart` (`beadPlayback`), `lib/features/rattle/data/soundpool_sound_service.dart` (`playBead`) |
| Boot sequence | `lib/main.dart`, `lib/core/di/injection_container.dart` |
| Burst (multi-pulse shake vibration pattern) | `lib/features/rattle/data/vibration_haptic_service.dart` (`burst`), `lib/features/rattle/presentation/bloc/rattle_bloc.dart` (`_onShaken`) |
| Degradation / graceful no-op on missing capability | `lib/features/rattle/presentation/bloc/rattle_bloc.dart` (`_guard`), `lib/core/di/injection_container.dart` (`_initSafely`) |
| Dependency injection (GetIt / `sl`) | `lib/core/di/injection_container.dart` |
| Gesture surface (raw pointer moves) | `lib/features/rattle/presentation/screens/rattle_screen.dart` |
| Haptic service (abstract contract) | `lib/features/rattle/domain/haptic_service.dart` |
| Haptic service (`vibration` plugin impl) | `lib/features/rattle/data/vibration_haptic_service.dart` |
| Immersive mode (fullscreen system UI) | `lib/core/system/immersive_mode.dart` |
| Lifecycle observer (resume/pause) | `lib/main.dart` (`_ImmersiveObserver`) |
| Logging convention (`dart:developer` `log`) | `lib/features/rattle/presentation/bloc/rattle_bloc.dart`, `lib/core/di/injection_container.dart`, `lib/features/rattle/data/sensors_motion_service.dart` |
| Motion service (abstract contract) | `lib/features/rattle/domain/motion_service.dart` |
| Motion service (`sensors_plus` impl) | `lib/features/rattle/data/sensors_motion_service.dart` |
| Multi-pointer / per-finger tracking | `lib/features/rattle/presentation/screens/rattle_screen.dart` (`_PointerTrack`, keyed by `PointerEvent.pointer`) |
| `RattleBloc` | `lib/features/rattle/presentation/bloc/rattle_bloc.dart` |
| `RattleEvent` (`RattleInitialized` / `SwipeTick` / `RattleShaken`) | `lib/features/rattle/presentation/bloc/rattle_event.dart` |
| `RattleState` | `lib/features/rattle/presentation/bloc/rattle_state.dart` |
| Sample preload (bead/rattle `.wav`) | `lib/features/rattle/data/soundpool_sound_service.dart` (`init`, `_loadAsset`) |
| Shake cooldown / debounce (300ms) | `lib/features/rattle/domain/rattle_math.dart` (`kShakeCooldown`, `isShakeDue`) |
| Shake detection (threshold + magnitude) | `lib/features/rattle/domain/rattle_math.dart` (`kShakeThreshold`, `isShakeMagnitude`), `lib/features/rattle/data/sensors_motion_service.dart` |
| Shake subscription (constructor-wired, not event-wired) | `lib/features/rattle/presentation/bloc/rattle_bloc.dart` |
| Sound service (abstract contract) | `lib/features/rattle/domain/sound_service.dart` |
| Sound service (`soundpool` + `audio_session` impl) | `lib/features/rattle/data/soundpool_sound_service.dart` |
| Swipe throttle (40ms per-pointer) | `lib/features/rattle/domain/rattle_math.dart` (`kSwipeThrottle`), `lib/features/rattle/presentation/screens/rattle_screen.dart` |
| Swipe velocity (px/ms) | `lib/features/rattle/domain/rattle_math.dart` (`velocityFromDelta`, `swipeIntensity`), `lib/features/rattle/presentation/screens/rattle_screen.dart` |
| Tuning constants (`kVelocityDivisor`, `kShakeThreshold`, `kShakeCooldown`, `kSwipeThrottle`) | `lib/features/rattle/domain/rattle_math.dart` |
| Vibration amplitude / duration | `lib/features/rattle/data/vibration_haptic_service.dart` |
| Wakelock (screen stays awake) | `lib/core/system/immersive_mode.dart`, `lib/main.dart` (`_ImmersiveObserver`) |

---

## Cross-cutting flows

Each numbered chain is a step-by-step `file — role`. Follow them to trace
an end-to-end behavior.

### 1. Swipe → feedback

1. `lib/features/rattle/presentation/screens/rattle_screen.dart` — `_onMove`
   tracks each pointer independently, throttles samples to `kSwipeThrottle`
   (~40ms), computes distance, calls `velocityFromDelta`, and dispatches
   `SwipeTick(velocity)`.
2. `lib/features/rattle/domain/rattle_math.dart` — `velocityFromDelta`
   (px/ms), `swipeIntensity` (clamped 0.0–1.0 via `kVelocityDivisor`), and
   `beadPlayback` (velocity → pitch rate + volume).
3. `lib/features/rattle/presentation/bloc/rattle_bloc.dart` — `_onSwipeTick`
   computes intensity + bead playback and fires both feedback channels
   concurrently via `Future.wait([_guard(...), _guard(...)])`.
4. `lib/features/rattle/data/vibration_haptic_service.dart` — `tick`
   maps intensity to a vibration amplitude (or a fixed-duration buzz if the
   device lacks amplitude control) and vibrates.
5. `lib/features/rattle/data/soundpool_sound_service.dart` — `playBead`
   sets the sample's volume *before* calling `play` (the attack-transient
   invariant), then plays the bead sample at the sampled pitch rate.

### 2. Shake → feedback

1. `lib/features/rattle/data/sensors_motion_service.dart` — `_onAccel`
   computes the gravity-removed acceleration magnitude, checks
   `isShakeMagnitude` (`kShakeThreshold`) and `isShakeDue`
   (`kShakeCooldown`), and emits on the `shakes` stream.
2. `lib/features/rattle/presentation/bloc/rattle_bloc.dart` — the
   constructor subscribes to `_motion.shakes` synchronously (before
   `on<...>` handlers are wired) and dispatches `RattleShaken()` on each
   emission.
3. `_onShaken` fires both feedback channels concurrently:
   `_haptic.burst()` + `_sound.playRattle()`, each wrapped in `_guard`.
4. `lib/features/rattle/data/vibration_haptic_service.dart` — `burst`
   plays the multi-pulse vibration pattern.
5. `lib/features/rattle/data/soundpool_sound_service.dart` — `playRattle`
   plays the rattle sample.

### 3. App boot

1. `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()`, then
   `ImmersiveMode().enable()` (fullscreen system UI + wakelock).
2. `lib/core/di/injection_container.dart` — `di.init()` constructs the 3
   service implementations and runs each `init()` through `_initSafely`,
   an isolated try/catch per service so one plugin failure degrades only
   that service; registers app-lifetime singletons plus the `RattleBloc`
   factory.
3. `lib/main.dart` — registers `_ImmersiveObserver` with
   `WidgetsBinding.instance`, then `runApp(BabyClapperApp())`, which builds
   `MaterialApp` → `BlocProvider<RattleBloc>`
   (`di.sl<RattleBloc>()..add(const RattleInitialized())`) → `RattleScreen`.
4. `_ImmersiveObserver` re-asserts immersive mode + wakelock on
   `AppLifecycleState.resumed` and releases the wakelock on
   `paused`/`hidden` (the OS can restore system bars while backgrounded).
