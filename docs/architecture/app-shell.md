# App shell — boot, DI, immersive mode, logging

> Deep-dive for the app shell (boot sequence, dependency injection, and the
> fullscreen/wakelock lifecycle). Loaded on demand — see the routing table
> in CLAUDE.md. For "where is X" lookups use docs/CODEMAP.md.

## Boot sequence (`main.dart` + `injection_container.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `ImmersiveMode().enable()` — hides the system bars
   (`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`)
   and acquires the wakelock (`WakelockPlus.enable()`), before DI so the
   app is already fullscreen and awake by the time the first frame draws.
3. `di.init()` — constructs `VibrationHapticService`,
   `SoundpoolSoundService`, and `SensorsMotionService`, then runs each
   `init()` through `_initSafely` and registers everything with `GetIt`.
4. `WidgetsBinding.instance.addObserver(_ImmersiveObserver(immersive))` —
   wired after DI so the observer closes over the same `ImmersiveMode`
   instance used for the initial `enable()` call.
5. `runApp(const BabyClapperApp())` — builds `MaterialApp` with a single
   `BlocProvider<RattleBloc>` wrapping `RattleScreen`. The provider's
   `create` pulls the bloc from DI and immediately dispatches
   `RattleInitialized()`: `di.sl<RattleBloc>()..add(const
   RattleInitialized())`.

## Dependency injection

`get_it` (`lib/core/di/injection_container.dart`) is the sole service
locator. `GetIt` (`sl`) is referenced only from `main.dart` and this file —
**never from widgets or blocs** — enforced by the `avoid_get_it_in_widgets`
custom lint. Widgets and blocs receive services through
`BlocProvider`/constructor injection instead.

### Per-service init isolation (`_initSafely`)

`di.init()` calls each service's `init()` through a shared helper:

```dart
Future<void> _initSafely(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (error, stackTrace) {
    log('init failed, degrading gracefully: $error', name: name, ...);
  }
}
```

Each of `HapticService`, `SoundService`, and `MotionService` gets its own
try/catch. This is deliberate isolation, not just a shared error handler: a
`vibration` plugin throwing on some platform-channel edge case must never
prevent `SoundpoolSoundService.init()` or `SensorsMotionService.init()`
from running afterwards, and boot itself must never abort on a missing
capability (CLAUDE.md's "graceful-degrade, never a crash"). All three
services are registered as `GetIt` singletons regardless of whether their
`init()` succeeded — a degraded service simply no-ops on every subsequent
call (see `docs/architecture/rattle-feedback.md` for each service's degrade
path).

`SoundService` and `MotionService` are intentionally never disposed from
`injection_container.dart`: both are app-lifetime singletons that live for
the process's whole life, so their `dispose()` (pool teardown / stream
subscription cancellation) exists for symmetry and unit-test cleanup, not
because boot ever tears them down.

## Immersive mode + wakelock lifecycle

`lib/core/system/immersive_mode.dart` wraps `SystemChrome` (immersive-sticky
system UI) and `wakelock_plus` behind one service: `enable()` re-hides the
bars and re-acquires the wakelock in a single call; `releaseWakelock()`
disables it.

`main.dart`'s `_ImmersiveObserver` (a `WidgetsBindingObserver`) re-invokes
that service on lifecycle transitions:

- **`resumed`** → `immersive.enable()` — the OS can restore the system bars
  and drop the wakelock while backgrounded, so both must be re-asserted on
  every return to foreground, not just at cold boot.
- **`paused` / `hidden`** → `immersive.releaseWakelock()` — both states
  mean the app is no longer shown to the user (backgrounded, or occluded in
  a multi-window/split-screen scenario), so the wakelock is released rather
  than left held.
- **`inactive`** → left alone. It's a brief, still-visible transition (app
  switcher, incoming call, notification shade), not a real backgrounding,
  so releasing the wakelock here would flicker it on and off during normal
  use.
- **`detached`** → left alone (no UI to hold awake).

## Logging convention

BLoCs use `dart:developer`'s `log(msg, name: '<BlocName>')` —
`RattleBloc._guard` logs each swallowed feedback failure this way. Never
`debugPrint` in a bloc: importing `package:flutter/foundation.dart` into a
bloc file trips bloc_lint's `avoid_flutter_imports`, since blocs must stay
Flutter-decoupled. Non-bloc layers use the same `dart:developer` `log` call
where structured `name`/`error`/`stackTrace` fields are useful (`_initSafely`
in `injection_container.dart`, the accelerometer stream's `onError` in
`sensors_motion_service.dart`); plain `debugPrint` is reserved for
non-bloc, non-service call sites that need a quick, unstructured trace.
`print` itself is disallowed everywhere (`avoid_print`).
