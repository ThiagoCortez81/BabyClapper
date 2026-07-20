# Rattle feedback — gesture surface, RattleBloc, services, math

> Deep-dive for the rattle feedback loop (gesture surface, `RattleBloc`, the
> three feedback services, and the tuning math). Loaded on demand — see the
> routing table in CLAUDE.md. For "where is X" lookups use docs/CODEMAP.md.

## Gesture surface (`rattle_screen.dart`)

`RattleScreen` is a fullscreen `Listener` with no `SafeArea` — the gesture
area runs edge-to-edge under any cutouts. It tracks each pointer
**independently**, keyed by `PointerEvent.pointer`, in a
`Map<int, _PointerTrack>` (`({Offset pos, Duration ts})`): a baby palming
the screen with several fingers at once must not let one finger's move
overwrite another's last-known position and produce a bogus velocity spike.

`_onMove` throttles per pointer to `kSwipeThrottle` (~40ms): if the delta
since that pointer's last sample is under the throttle window, the sample
is dropped rather than queued. Once the window has elapsed, it computes the
Euclidean distance moved, converts it to velocity via `velocityFromDelta`,
and dispatches `SwipeTick(velocity)`. `_reset` (on pointer down/up/cancel)
drops that pointer's track so a new touch starts from a clean baseline
instead of computing velocity against a stale, possibly far-away position.

## `RattleBloc`

`RattleBloc` depends only on the three abstract service types
(`HapticService`, `SoundService`, `MotionService`) — never a concrete
`...Impl` or a plugin package directly — enforced by the
`bloc_depends_on_abstractions` custom lint.

### Why the shake subscription is constructor-wired

```dart
RattleBloc({required haptic, required sound, required motion})
    : _haptic = haptic, _sound = sound, _motion = motion,
      super(const RattleState()) {
  _shakeSub = _motion.shakes.listen((_) => add(const RattleShaken()));
  on<RattleInitialized>(_onInitialized);
  on<SwipeTick>(_onSwipeTick);
  on<RattleShaken>(_onShaken);
}
```

The shake subscription is attached synchronously in the constructor body,
**not** inside the async `_onInitialized` handler. `Bloc.add()` defers
event processing to a microtask; if the shake listener were instead wired
from within the handler for a `RattleInitialized` event, a shake firing
in the window between bloc construction and that microtask running could
race past an unattached listener and be silently dropped. Wiring it in the
constructor guarantees the subscription exists before the bloc is even
handed to a `BlocProvider`.

### Degrade-independent feedback (`_guard`)

Both `_onSwipeTick` and `_onShaken` fire their haptic and sound calls
concurrently via `Future.wait([_guard(...), _guard(...)])`. `_guard` wraps
a single feedback future, catches anything it throws, and logs it via
`log('feedback failed', name: 'RattleBloc', ...)` — so a haptic failure can
never block or crash the sound call (or vice versa), per CLAUDE.md's
"haptics and audio degrade independently."

`close()` cancels `_shakeSub` before calling `super.close()`, satisfying
`close_sinks`.

## The three services and their degrade paths

| Service | Abstract contract | Impl | Degrade path |
|---|---|---|---|
| Haptics | `lib/features/rattle/domain/haptic_service.dart` | `lib/features/rattle/data/vibration_haptic_service.dart` | `init()` checks `Vibration.hasVibrator()` / `hasAmplitudeControl()` once. No vibrator → `tick`/`burst` no-op. Vibrator but no amplitude control → `tick` falls back to a fixed 12ms buzz instead of amplitude-scaled vibration. |
| Sound | `lib/features/rattle/domain/sound_service.dart` | `lib/features/rattle/data/soundpool_sound_service.dart` | `init()` configures the `audio_session` in a try/catch that never blocks sample loading; each sample (`bead.wav`, `rattle.wav`) loads independently and a failed load leaves that sample's id `null`, so `playBead`/`playRattle` no-op individually rather than failing together. |
| Motion | `lib/features/rattle/domain/motion_service.dart` | `lib/features/rattle/data/sensors_motion_service.dart` | The `userAccelerometerEventStream()` subscription has `cancelOnError: false` and logs stream errors via `onError` instead of tearing down the subscription, so a transient sensor error doesn't permanently kill shake detection. |

All three are constructed unconditionally in `injection_container.dart` and
their `init()` calls run through `_initSafely` (see
`docs/architecture/app-shell.md`) — a failed `init()` still leaves a
registered, safely-no-opping singleton, never a missing dependency.

## Feedback math and the four tuning constants (`rattle_math.dart`)

Pure Dart, no Flutter or plugin imports — shared by both the bloc and the
data-layer services, and independently unit-tested in
`test/features/rattle/domain/rattle_math_test.dart`.

- **`kVelocityDivisor` (4.0)** — divides swipe speed (px/ms) to produce the
  `0.0..1.0` intensity curve (`swipeIntensity`) that drives both haptic
  amplitude and bead pitch/volume (`beadPlayback`). Lower it to make a
  swipe reach full intensity at a slower speed.
- **`kShakeThreshold` (15.0 m/s²)** — the gravity-removed acceleration
  magnitude above which a motion sample counts as a shake
  (`isShakeMagnitude`). Uses the *user* accelerometer (gravity already
  removed), so the raw magnitude compares directly against this constant.
- **`kShakeCooldown` (300ms)** — the minimum gap between two dispatched
  shake events (`isShakeDue`). One physical shake spans several sensor
  samples above the threshold; this cooldown collapses them into a single
  `RattleShaken` event instead of a burst of duplicates.
- **`kSwipeThrottle` (40ms)** — the minimum gap between two dispatched
  `SwipeTick`s per pointer, enforced in `rattle_screen.dart`. Without it a
  fast continuous swipe would queue vibrations/samples far faster than a
  realistic feedback cadence.

Tune all four on real hardware — they encode device-feel, not arbitrary
constants — and expect them to move as the app is tested on more devices.

## The audio-session decision

`SoundpoolSoundService` configures `audio_session` with a fixed,
deliberately chosen `AudioSessionConfiguration`:

- **iOS**: `AVAudioSessionCategory.ambient` — the one category that both
  respects the hardware silent switch (unlike `.playback`, which ignores
  it) *and* mixes with other audio by default; `mixWithOthers` makes the
  mixing explicit. The product requirement is that the rattle goes silent
  when the silent switch is on, and never interrupts music/podcasts the
  parent is already playing.
- **Android**: the `androidAudioAttributes` / `androidAudioFocusGainType`
  fields are declarative intent only — `audio_session` only applies them
  via `setActive(true)`, which this app never calls, so **no audio focus is
  ever requested**. That's the desired behavior (it's precisely why other
  apps' audio is never paused), not an oversight; don't "fix" it by adding
  a `setActive(true)` call.

Haptics are entirely independent of this session's state — a silent-switch
phone still buzzes on every swipe and shake, since `VibrationHapticService`
never consults audio session state.

### Sample playback ordering invariant

`playBead` calls `pool.setVolume(soundId: id, volume: ...)` **before**
`pool.play(id, rate: ...)`. `bead.wav` is an ~80ms exponentially-decaying
click whose entire perceptual content is its first ~15ms attack; setting
volume on the resulting *stream* after `play()` returns lands after that
attack has already been rendered, making the velocity→volume half of the
feedback curve inert. Any change to `playBead` must preserve this
set-then-play order.
