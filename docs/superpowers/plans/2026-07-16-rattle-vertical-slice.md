# BabyClapper Rattle Vertical Slice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the BabyClapper Flutter project and ship one working end-to-end rattle behavior — swipe → speed-scaled buzz + bead sound, shake → rattle burst — on iOS/Android in fullscreen.

**Architecture:** Clean-architecture, feature-first (`CLAUDE.md` §3). Pure feedback math is isolated and unit-tested; a `RattleBloc` coordinates three plugin-wrapping core services (`HapticService` / `SoundService` / `MotionService`), each behind an abstract interface so the bloc is testable with fakes. A fullscreen `Listener` surface throttles pointer moves into `SwipeTick` events; a `sensors_plus` stream fires shake events.

**Tech Stack:** Flutter (fvm-pinned `3.44.4`), `flutter_bloc`, `get_it`, `equatable`, `vibration`, `soundpool`, `audio_session`, `sensors_plus`, `wakelock_plus`; dev: `bloc_test`, `very_good_analysis`.

## Global Constraints

- **Flutter `3.44.4`, always via `fvm`** — every command is `fvm flutter ...` / `fvm dart ...`, never bare `flutter`.
- **Platforms: iOS + Android only.** No web/desktop targets; no web-safety `_io`/`_stub` conditional imports.
- **Fullscreen immersive** (`SystemUiMode.immersiveSticky`), screen kept awake; re-assert immersive on `AppLifecycleState.resumed`.
- **Imports are `package:baby_clapper/...` everywhere.** No relative imports (`always_use_package_imports`).
- **BLoCs stay Flutter-decoupled:** no `package:flutter/...` import in a bloc; use `dart:developer`'s `log(msg, name: 'RattleBloc')`, never `debugPrint`/`print`.
- **Plugins only inside their core service** (`vibration`/`soundpool`/`audio_session`/`sensors_plus`/`wakelock_plus`). Widgets and the bloc call the abstract service, never a plugin directly.
- **Haptics and audio degrade independently** — capability-checked, graceful no-op; one channel failing never blocks or crashes the other.
- **`very_good_analysis` clean** — keep lines ≤ 80 cols; run `fvm dart format .` before every commit.
- Bundle org: `com.thiagocortez` → application id `com.thiagocortez.baby_clapper`.

---

### Task 1: Bootstrap the Flutter project

**Files:**
- Create (generated): `pubspec.yaml`, `android/`, `ios/`, `lib/main.dart`, plus tree
- Create: `analysis_options.yaml`
- Create: `tool/gen_placeholder_sounds.py`
- Create: `assets/sounds/bead.wav`, `assets/sounds/rattle.wav` (generated)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Replace: `lib/main.dart`, `test/widget_test.dart`

**Interfaces:**
- Produces: a runnable fullscreen `BabyClapperApp` placeholder; project analyzes + tests green with the full dependency set installed.

- [ ] **Step 1: Create the project in-place**

Run:
```bash
fvm flutter create --platforms=ios,android --project-name baby_clapper --org com.thiagocortez .
```
Expected: files generated under the current dir; existing `CLAUDE.md`, `docs/`, `.git` untouched.

- [ ] **Step 2: Confirm our `.gitignore` `.claude` entry survived**

Run: `grep -n "settings.local.json" .gitignore || echo MISSING`
If `MISSING`, re-append:
```bash
printf '\n# Claude Code — local settings\n.claude/settings.local.json\n' >> .gitignore
```

- [ ] **Step 3: Add runtime + dev dependencies (pub resolves compatible versions)**

Run:
```bash
fvm flutter pub add flutter_bloc bloc equatable get_it vibration soundpool audio_session sensors_plus wakelock_plus
fvm flutter pub remove flutter_lints
fvm flutter pub add dev:bloc_test dev:very_good_analysis
```
Expected: `pubspec.yaml` lists all packages; `pub get` succeeds. If a package fails to resolve on Dart 3.12, take the newest compatible major `pub add` offers and note it.

- [ ] **Step 4: Replace `analysis_options.yaml`**

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
```

- [ ] **Step 5: Register the assets folder in `pubspec.yaml`**

Under the `flutter:` section, add:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
```

- [ ] **Step 6: Write the placeholder-sound generator `tool/gen_placeholder_sounds.py`**

```python
import wave, struct, random, math, os

SR = 44100
os.makedirs("assets/sounds", exist_ok=True)


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        data = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(data)


def bead(dur=0.08, seed=0):
    rnd = random.Random(seed)
    n = int(SR * dur)
    return [rnd.uniform(-1, 1) * math.exp(-i / (SR * 0.015)) * 0.7 for i in range(n)]


def rattle(dur=0.5, beads=7, seed=42):
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = [0.0] * n
    for _ in range(beads):
        start = rnd.randint(0, n - 1)
        for j, s in enumerate(bead(0.05, seed=rnd.randint(0, 9999))):
            if start + j < n:
                out[start + j] += s * 0.6
    return [max(-1.0, min(1.0, s)) for s in out]


write_wav("assets/sounds/bead.wav", bead())
write_wav("assets/sounds/rattle.wav", rattle())
print("wrote assets/sounds/bead.wav and assets/sounds/rattle.wav")
```

- [ ] **Step 7: Generate the sound assets**

Run: `python3 tool/gen_placeholder_sounds.py`
Expected: `wrote assets/sounds/bead.wav and assets/sounds/rattle.wav`; both files exist and are non-empty.

- [ ] **Step 8: Add the Android VIBRATE permission**

In `android/app/src/main/AndroidManifest.xml`, add directly above the `<application` tag:
```xml
    <uses-permission android:name="android.permission.VIBRATE"/>
```

- [ ] **Step 9: Replace `lib/main.dart` with a fullscreen placeholder**

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const BabyClapperApp());
}

class BabyClapperApp extends StatelessWidget {
  const BabyClapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'BabyClapper',
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: Color(0xFF1B1B2F), child: SizedBox.expand()),
    );
  }
}
```

- [ ] **Step 10: Replace `test/widget_test.dart` with a smoke test**

```dart
import 'package:baby_clapper/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders a fullscreen surface', (tester) async {
    await tester.pumpWidget(const BabyClapperApp());
    expect(find.byType(ColoredBox), findsOneWidget);
  });
}
```

- [ ] **Step 11: Format, analyze, test**

Run:
```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```
Expected: format clean, analyze reports **No issues found**, test **All tests passed**.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "Scaffold Flutter project (iOS/Android) with deps and assets"
```

---

### Task 2: Pure feedback math (`rattle_math.dart`)

**Files:**
- Create: `lib/core/rattle_math.dart`
- Test: `test/core/rattle_math_test.dart`

**Interfaces:**
- Produces:
  - `typedef BeadPlayback = ({double rate, double volume});`
  - `double velocityFromDelta(double distancePx, Duration dt)` — px/ms; `0` when `dt` is zero.
  - `double swipeIntensity(double velocityPxPerMs)` — clamped `0.0..1.0`, monotonic non-decreasing.
  - `BeadPlayback beadPlayback(double velocityPxPerMs)` — `rate` in `0.8..1.8`, `volume` in `0.3..1.0`.
  - `bool isShakeMagnitude(double gravityRemovedMagnitude, {double threshold = 15.0})`.

- [ ] **Step 1: Write the failing tests**

`test/core/rattle_math_test.dart`:
```dart
import 'package:baby_clapper/core/rattle_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('velocityFromDelta', () {
    test('is distance over milliseconds', () {
      expect(
        velocityFromDelta(100, const Duration(milliseconds: 50)),
        closeTo(2.0, 1e-9),
      );
    });
    test('is zero when dt is zero', () {
      expect(velocityFromDelta(100, Duration.zero), 0.0);
    });
  });

  group('swipeIntensity', () {
    test('clamps to 0..1', () {
      expect(swipeIntensity(-5), 0.0);
      expect(swipeIntensity(1000), 1.0);
    });
    test('is monotonic non-decreasing', () {
      expect(swipeIntensity(1) <= swipeIntensity(3), isTrue);
    });
  });

  group('beadPlayback', () {
    test('stays within rate/volume bounds', () {
      final slow = beadPlayback(0);
      final fast = beadPlayback(1000);
      expect(slow.rate, inInclusiveRange(0.8, 1.8));
      expect(slow.volume, inInclusiveRange(0.3, 1.0));
      expect(fast.rate, inInclusiveRange(0.8, 1.8));
      expect(fast.volume, inInclusiveRange(0.3, 1.0));
      expect(fast.volume >= slow.volume, isTrue);
    });
  });

  group('isShakeMagnitude', () {
    test('true above threshold, false below', () {
      expect(isShakeMagnitude(20), isTrue);
      expect(isShakeMagnitude(5), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `fvm flutter test test/core/rattle_math_test.dart`
Expected: FAIL — `rattle_math.dart` / symbols not defined.

- [ ] **Step 3: Implement `lib/core/rattle_math.dart`**

```dart
/// Pure feedback math for the rattle. No Flutter, no plugins — fully testable.
library;

typedef BeadPlayback = ({double rate, double volume});

/// Swipe speed in logical pixels per millisecond. Returns `0` for a zero
/// time delta (avoids division by zero on coincident pointer samples).
double velocityFromDelta(double distancePx, Duration dt) {
  final ms = dt.inMicroseconds / 1000.0;
  if (ms <= 0) return 0;
  return distancePx / ms;
}

/// Maps swipe speed to a haptic intensity in `0.0..1.0`.
double swipeIntensity(double velocityPxPerMs) {
  return (velocityPxPerMs / 4.0).clamp(0.0, 1.0);
}

/// Maps swipe speed to bead-sound playback: faster = higher pitch + louder.
BeadPlayback beadPlayback(double velocityPxPerMs) {
  final t = (velocityPxPerMs / 4.0).clamp(0.0, 1.0);
  return (rate: 0.8 + t * 1.0, volume: 0.3 + t * 0.7);
}

/// Whether a gravity-removed acceleration magnitude (m/s^2) is a shake.
bool isShakeMagnitude(double gravityRemovedMagnitude, {double threshold = 15.0}) {
  return gravityRemovedMagnitude >= threshold;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `fvm flutter test test/core/rattle_math_test.dart`
Expected: PASS — all tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
fvm dart format .
fvm flutter analyze
git add lib/core/rattle_math.dart test/core/rattle_math_test.dart
git commit -m "Add pure rattle feedback math"
```

---

### Task 3: Service interfaces + `RattleBloc` (with fakes)

**Files:**
- Create: `lib/core/haptics/haptic_service.dart`
- Create: `lib/core/audio/sound_service.dart`
- Create: `lib/core/motion/motion_service.dart`
- Create: `lib/features/rattle/presentation/bloc/rattle_event.dart`
- Create: `lib/features/rattle/presentation/bloc/rattle_state.dart`
- Create: `lib/features/rattle/presentation/bloc/rattle_bloc.dart`
- Test: `test/features/rattle/presentation/bloc/rattle_bloc_test.dart`

**Interfaces:**
- Consumes: `swipeIntensity`, `beadPlayback` from Task 2.
- Produces:
  - `abstract interface class HapticService { Future<void> init(); Future<void> tick(double intensity); Future<void> burst(); }`
  - `abstract interface class SoundService { Future<void> init(); Future<void> playBead({required double rate, required double volume}); Future<void> playRattle(); Future<void> dispose(); }`
  - `abstract interface class MotionService { Stream<void> get shakes; Future<void> init(); Future<void> dispose(); }`
  - `RattleBloc({required HapticService haptic, required SoundService sound, required MotionService motion})`
  - Events: `RattleInitialized`, `SwipeTick(double velocity)`, `RattleShaken`. State: `RattleState({bool ready})`.

- [ ] **Step 1: Write the abstract service interfaces**

`lib/core/haptics/haptic_service.dart`:
```dart
/// Vibration feedback. Implementations wrap the platform plugin and must
/// no-op gracefully when the device has no vibrator.
abstract interface class HapticService {
  Future<void> init();

  /// A single bead tick; [intensity] is `0.0..1.0`.
  Future<void> tick(double intensity);

  /// A multi-pulse rattle burst.
  Future<void> burst();
}
```

`lib/core/audio/sound_service.dart`:
```dart
/// Rattle sound playback. Implementations wrap the audio plugin and must
/// no-op gracefully when audio is unavailable.
abstract interface class SoundService {
  Future<void> init();

  Future<void> playBead({required double rate, required double volume});

  Future<void> playRattle();

  Future<void> dispose();
}
```

`lib/core/motion/motion_service.dart`:
```dart
/// Device-motion source. Emits on [shakes] each time a shake is detected.
abstract interface class MotionService {
  Stream<void> get shakes;

  Future<void> init();

  Future<void> dispose();
}
```

- [ ] **Step 2: Write the events and state**

`lib/features/rattle/presentation/bloc/rattle_event.dart`:
```dart
import 'package:equatable/equatable.dart';

sealed class RattleEvent extends Equatable {
  const RattleEvent();

  @override
  List<Object?> get props => const [];
}

/// Fired once at startup: wires the shake subscription.
class RattleInitialized extends RattleEvent {
  const RattleInitialized();
}

/// A throttled swipe sample; [velocity] is px/ms.
class SwipeTick extends RattleEvent {
  const SwipeTick(this.velocity);

  final double velocity;

  @override
  List<Object?> get props => [velocity];
}

/// The device was shaken.
class RattleShaken extends RattleEvent {
  const RattleShaken();
}
```

`lib/features/rattle/presentation/bloc/rattle_state.dart`:
```dart
import 'package:equatable/equatable.dart';

class RattleState extends Equatable {
  const RattleState({this.ready = false});

  final bool ready;

  RattleState copyWith({bool? ready}) =>
      RattleState(ready: ready ?? this.ready);

  @override
  List<Object?> get props => [ready];
}
```

- [ ] **Step 3: Write the failing bloc test**

`test/features/rattle/presentation/bloc/rattle_bloc_test.dart`:
```dart
import 'dart:async';

import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHaptic implements HapticService {
  final List<double> ticks = [];
  int bursts = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> tick(double intensity) async => ticks.add(intensity);
  @override
  Future<void> burst() async => bursts++;
}

class FakeSound implements SoundService {
  final List<BeadCall> beads = [];
  int rattles = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> playBead({required double rate, required double volume}) async =>
      beads.add(BeadCall(rate, volume));
  @override
  Future<void> playRattle() async => rattles++;
  @override
  Future<void> dispose() async {}
}

class BeadCall {
  BeadCall(this.rate, this.volume);
  final double rate;
  final double volume;
}

class FakeMotion implements MotionService {
  final StreamController<void> controller = StreamController<void>.broadcast();
  @override
  Stream<void> get shakes => controller.stream;
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async => controller.close();
  void emitShake() => controller.add(null);
}

void main() {
  late FakeHaptic haptic;
  late FakeSound sound;
  late FakeMotion motion;

  setUp(() {
    haptic = FakeHaptic();
    sound = FakeSound();
    motion = FakeMotion();
  });

  RattleBloc build() =>
      RattleBloc(haptic: haptic, sound: sound, motion: motion);

  blocTest<RattleBloc, RattleState>(
    'SwipeTick triggers one haptic tick and one bead sound',
    build: build,
    act: (bloc) => bloc.add(const SwipeTick(4)),
    verify: (_) {
      expect(haptic.ticks, hasLength(1));
      expect(sound.beads, hasLength(1));
    },
  );

  blocTest<RattleBloc, RattleState>(
    'RattleShaken triggers a burst and the rattle sound',
    build: build,
    act: (bloc) => bloc.add(const RattleShaken()),
    verify: (_) {
      expect(haptic.bursts, 1);
      expect(sound.rattles, 1);
    },
  );

  blocTest<RattleBloc, RattleState>(
    'RattleInitialized marks ready and wires the shake stream',
    build: build,
    act: (bloc) {
      bloc.add(const RattleInitialized());
      motion.emitShake();
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [const RattleState(ready: true)],
    verify: (_) => expect(haptic.bursts, 1),
  );
}
```

- [ ] **Step 4: Run to verify failure**

Run: `fvm flutter test test/features/rattle/presentation/bloc/rattle_bloc_test.dart`
Expected: FAIL — `RattleBloc` not defined.

- [ ] **Step 5: Implement `RattleBloc`**

`lib/features/rattle/presentation/bloc/rattle_bloc.dart`:
```dart
import 'dart:async';
import 'dart:developer';

import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/core/rattle_math.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_state.dart';
import 'package:bloc/bloc.dart';

class RattleBloc extends Bloc<RattleEvent, RattleState> {
  RattleBloc({
    required HapticService haptic,
    required SoundService sound,
    required MotionService motion,
  })  : _haptic = haptic,
        _sound = sound,
        _motion = motion,
        super(const RattleState()) {
    on<RattleInitialized>(_onInitialized);
    on<SwipeTick>(_onSwipeTick);
    on<RattleShaken>(_onShaken);
  }

  final HapticService _haptic;
  final SoundService _sound;
  final MotionService _motion;
  StreamSubscription<void>? _shakeSub;

  Future<void> _onInitialized(
    RattleInitialized event,
    Emitter<RattleState> emit,
  ) async {
    _shakeSub = _motion.shakes.listen((_) => add(const RattleShaken()));
    emit(state.copyWith(ready: true));
  }

  Future<void> _onSwipeTick(SwipeTick event, Emitter<RattleState> emit) async {
    final intensity = swipeIntensity(event.velocity);
    final bead = beadPlayback(event.velocity);
    await Future.wait([
      _guard(_haptic.tick(intensity)),
      _guard(_sound.playBead(rate: bead.rate, volume: bead.volume)),
    ]);
  }

  Future<void> _onShaken(RattleShaken event, Emitter<RattleState> emit) async {
    await Future.wait([
      _guard(_haptic.burst()),
      _guard(_sound.playRattle()),
    ]);
  }

  /// Runs a feedback future in isolation: a failure in one channel is logged
  /// and swallowed so it can never block or crash the other channel.
  Future<void> _guard(Future<void> action) async {
    try {
      await action;
    } catch (error, stackTrace) {
      log('feedback failed', name: 'RattleBloc', error: error,
          stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() {
    _shakeSub?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `fvm flutter test test/features/rattle/presentation/bloc/rattle_bloc_test.dart`
Expected: PASS — all three bloc tests pass.

- [ ] **Step 7: Format, analyze, commit**

```bash
fvm dart format .
fvm flutter analyze
git add lib/core/haptics lib/core/audio lib/core/motion lib/features test/features
git commit -m "Add rattle service interfaces and RattleBloc"
```

---

### Task 4: `VibrationHapticService`

**Files:**
- Create: `lib/core/haptics/vibration_haptic_service.dart`

**Interfaces:**
- Consumes: `HapticService` (Task 3).
- Produces: `class VibrationHapticService implements HapticService` — a no-arg constructor.

> This is a thin adapter over the `vibration` plugin with no branching logic worth a unit test (platform channels aren't available in the test VM). Verification is analyze + compile; behavior is checked on-device in Task 8.

- [ ] **Step 1: Implement the service**

`lib/core/haptics/vibration_haptic_service.dart`:
```dart
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:vibration/vibration.dart';

class VibrationHapticService implements HapticService {
  bool _hasVibrator = false;
  bool _hasAmplitude = false;

  @override
  Future<void> init() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
    _hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;
  }

  @override
  Future<void> tick(double intensity) async {
    if (!_hasVibrator) return;
    if (_hasAmplitude) {
      final amp = (intensity.clamp(0.0, 1.0) * 254 + 1).round();
      await Vibration.vibrate(duration: 18, amplitude: amp);
    } else {
      await Vibration.vibrate(duration: 12);
    }
  }

  @override
  Future<void> burst() async {
    if (!_hasVibrator) return;
    await Vibration.vibrate(pattern: const [0, 40, 30, 60, 30, 90, 40, 140]);
  }
}
```
> If the installed `vibration` version returns non-nullable `bool` from `hasVibrator()`/`hasAmplitudeControl()`, drop the `?? false`. Adjust to the version `pub add` picked.

- [ ] **Step 2: Analyze**

Run: `fvm dart format . && fvm flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/core/haptics/vibration_haptic_service.dart
git commit -m "Add vibration-backed HapticService"
```

---

### Task 5: `SoundpoolSoundService`

**Files:**
- Create: `lib/core/audio/soundpool_sound_service.dart`

**Interfaces:**
- Consumes: `SoundService` (Task 3); assets `assets/sounds/bead.wav`, `assets/sounds/rattle.wav` (Task 1).
- Produces: `class SoundpoolSoundService implements SoundService` — a no-arg constructor.

> Thin adapter over `soundpool` + `audio_session`; not unit-tested. Verified on-device in Task 8.

- [ ] **Step 1: Implement the service**

`lib/core/audio/soundpool_sound_service.dart`:
```dart
import 'package:audio_session/audio_session.dart';
import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:soundpool/soundpool.dart';

class SoundpoolSoundService implements SoundService {
  Soundpool? _pool;
  int? _beadId;
  int? _rattleId;

  @override
  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    final pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(maxStreams: 8),
    );
    _beadId = await pool.load(await rootBundle.load('assets/sounds/bead.wav'));
    _rattleId =
        await pool.load(await rootBundle.load('assets/sounds/rattle.wav'));
    _pool = pool;
  }

  @override
  Future<void> playBead({required double rate, required double volume}) async {
    final pool = _pool;
    final id = _beadId;
    if (pool == null || id == null) return;
    final streamId = await pool.play(id, rate: rate);
    await pool.setVolume(streamId: streamId, volume: volume);
  }

  @override
  Future<void> playRattle() async {
    final pool = _pool;
    final id = _rattleId;
    if (pool == null || id == null) return;
    await pool.play(id);
  }

  @override
  Future<void> dispose() async {
    _pool?.dispose();
    _pool = null;
  }
}
```
> `SoundpoolOptions`/`Soundpool.fromOptions` names can vary by `soundpool` major version; if the installed version exposes `Soundpool.fromOptions` differently (or a `StreamType`), adapt the two constructor lines. The `load`/`play`/`setVolume` calls are stable.

- [ ] **Step 2: Analyze**

Run: `fvm dart format . && fvm flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/core/audio/soundpool_sound_service.dart
git commit -m "Add soundpool-backed SoundService"
```

---

### Task 6: `SensorsMotionService`

**Files:**
- Create: `lib/core/motion/sensors_motion_service.dart`

**Interfaces:**
- Consumes: `MotionService` (Task 3), `isShakeMagnitude` (Task 2).
- Produces: `class SensorsMotionService implements MotionService` — a no-arg constructor.

> Thin adapter over `sensors_plus`; the shake decision it delegates to the tested `isShakeMagnitude`. The stream wiring + cooldown are platform-coupled, so not unit-tested here.

- [ ] **Step 1: Implement the service**

`lib/core/motion/sensors_motion_service.dart`:
```dart
import 'dart:async';
import 'dart:math';

import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/core/rattle_math.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorsMotionService implements MotionService {
  final StreamController<void> _shakes = StreamController<void>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<void> get shakes => _shakes.stream;

  @override
  Future<void> init() async {
    _accelSub = userAccelerometerEventStream().listen(_onAccel);
  }

  void _onAccel(UserAccelerometerEvent event) {
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (!isShakeMagnitude(magnitude)) return;

    final now = DateTime.now();
    if (now.difference(_lastShake) < const Duration(milliseconds: 300)) return;
    _lastShake = now;
    _shakes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _accelSub?.cancel();
    await _shakes.close();
  }
}
```
> If the installed `sensors_plus` exposes `userAccelerometerEvents` (a stream getter) instead of `userAccelerometerEventStream()`, use that. Both deliver `UserAccelerometerEvent` with `.x/.y/.z` (gravity already removed).

- [ ] **Step 2: Analyze**

Run: `fvm dart format . && fvm flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/core/motion/sensors_motion_service.dart
git commit -m "Add sensors_plus-backed MotionService"
```

---

### Task 7: Fullscreen immersive mode

**Files:**
- Create: `lib/core/system/immersive_mode.dart`

**Interfaces:**
- Produces: `class ImmersiveMode { Future<void> enable(); Future<void> reassert(); }`

> Thin wrapper over `SystemChrome` + `wakelock_plus`. Not unit-tested (platform channels); used by `main.dart` in Task 8.

- [ ] **Step 1: Implement the helper**

`lib/core/system/immersive_mode.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owns the app's fullscreen presentation: immersive system UI + wakelock.
class ImmersiveMode {
  Future<void> enable() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  /// Re-hide the system bars after the OS restores them (call on resume).
  Future<void> reassert() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
```

- [ ] **Step 2: Analyze**

Run: `fvm dart format . && fvm flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/core/system/immersive_mode.dart
git commit -m "Add fullscreen immersive mode helper"
```

---

### Task 8: Wire it all together (DI + gesture surface + boot)

**Files:**
- Create: `lib/core/di/injection_container.dart`
- Create: `lib/features/rattle/presentation/screens/rattle_screen.dart`
- Replace: `lib/main.dart`
- Replace: `test/widget_test.dart`

**Interfaces:**
- Consumes: every service impl (Tasks 4–6), `ImmersiveMode` (Task 7), `RattleBloc` + events (Task 3), `velocityFromDelta` (Task 2).
- Produces: `final GetIt sl`; `Future<void> init()`; `class RattleScreen`; `class BabyClapperApp`.

- [ ] **Step 1: Write the DI container**

`lib/core/di/injection_container.dart`:
```dart
import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:baby_clapper/core/audio/soundpool_sound_service.dart';
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:baby_clapper/core/haptics/vibration_haptic_service.dart';
import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/core/motion/sensors_motion_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

/// Constructs, initializes, and registers all services + the bloc factory.
Future<void> init() async {
  final haptic = VibrationHapticService();
  final sound = SoundpoolSoundService();
  final motion = SensorsMotionService();

  await haptic.init();
  await sound.init();
  await motion.init();

  sl
    ..registerSingleton<HapticService>(haptic)
    ..registerSingleton<SoundService>(sound)
    ..registerSingleton<MotionService>(motion)
    ..registerFactory<RattleBloc>(
      () => RattleBloc(haptic: sl(), sound: sl(), motion: sl()),
    );
}
```

- [ ] **Step 2: Write the fullscreen gesture surface**

`lib/features/rattle/presentation/screens/rattle_screen.dart`:
```dart
import 'package:baby_clapper/core/rattle_math.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Edge-to-edge surface: pointer moves are throttled to ~40 ms ticks and
/// dispatched as [SwipeTick]s carrying the sampled swipe velocity.
class RattleScreen extends StatefulWidget {
  const RattleScreen({super.key});

  @override
  State<RattleScreen> createState() => _RattleScreenState();
}

class _RattleScreenState extends State<RattleScreen> {
  static const _throttle = Duration(milliseconds: 40);
  Offset? _lastPos;
  Duration? _lastTs;

  void _reset([_]) {
    _lastPos = null;
    _lastTs = null;
  }

  void _onMove(PointerMoveEvent event) {
    final ts = event.timeStamp;
    final lastPos = _lastPos;
    final lastTs = _lastTs;
    if (lastPos == null || lastTs == null) {
      _lastPos = event.position;
      _lastTs = ts;
      return;
    }
    final dt = ts - lastTs;
    if (dt < _throttle) return;

    final distance = (event.position - lastPos).distance;
    final velocity = velocityFromDelta(distance, dt);
    context.read<RattleBloc>().add(SwipeTick(velocity));
    _lastPos = event.position;
    _lastTs = ts;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _reset,
      onPointerMove: _onMove,
      onPointerUp: _reset,
      onPointerCancel: _reset,
      child: const ColoredBox(
        color: Color(0xFF1B1B2F),
        child: SizedBox.expand(),
      ),
    );
  }
}
```

- [ ] **Step 3: Replace `lib/main.dart` with the real boot**

```dart
import 'package:baby_clapper/core/di/injection_container.dart' as di;
import 'package:baby_clapper/core/system/immersive_mode.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/screens/rattle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final immersive = ImmersiveMode();
  await immersive.enable();
  await di.init();
  WidgetsBinding.instance.addObserver(_ImmersiveObserver(immersive));
  runApp(const BabyClapperApp());
}

class _ImmersiveObserver with WidgetsBindingObserver {
  _ImmersiveObserver(this._immersive);
  final ImmersiveMode _immersive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _immersive.reassert();
    }
  }
}

class BabyClapperApp extends StatelessWidget {
  const BabyClapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyClapper',
      debugShowCheckedModeBanner: false,
      home: BlocProvider<RattleBloc>(
        create: (_) => di.sl<RattleBloc>()..add(const RattleInitialized()),
        child: const RattleScreen(),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace `test/widget_test.dart` with a gesture-surface test**

```dart
import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/screens/rattle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopHaptic implements HapticService {
  int ticks = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> tick(double intensity) async => ticks++;
  @override
  Future<void> burst() async {}
}

class _NoopSound implements SoundService {
  @override
  Future<void> init() async {}
  @override
  Future<void> playBead({required double rate, required double volume}) async {}
  @override
  Future<void> playRattle() async {}
  @override
  Future<void> dispose() async {}
}

class _NoopMotion implements MotionService {
  @override
  Stream<void> get shakes => const Stream<void>.empty();
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('dragging the surface dispatches swipe ticks', (tester) async {
    final haptic = _NoopHaptic();
    final bloc = RattleBloc(
      haptic: haptic,
      sound: _NoopSound(),
      motion: _NoopMotion(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RattleBloc>.value(
          value: bloc,
          child: const RattleScreen(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(50, 300));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pump();

    expect(haptic.ticks, greaterThan(0));
  });
}
```

- [ ] **Step 5: Format, analyze, test**

Run:
```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```
Expected: format clean, **No issues found**, **All tests passed**.

- [ ] **Step 6: Manual on-device verification**

Connect an Android device/emulator or iOS device, then run:
```bash
fvm flutter run
```
Confirm by observation:
- App launches **fullscreen** (status/nav bars hidden).
- Dragging a finger across the screen produces vibration + bead clicks that get stronger/denser with faster drags.
- Physically shaking the device produces a rattle burst (multi-pulse vibration + rattle sound).

> No connected device? Note it and stop after Step 5 — automated gates are green; on-device confirmation is the reviewer's to run.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Wire DI, gesture surface, and fullscreen boot into working slice"
```

---

## Notes for the implementer

- **Plugin version drift is the main risk.** `pub add` picks the newest compatible versions; the three thin adapters (Tasks 4–6) and the soundpool constructor are the spots where an API may differ from the code shown. Each of those tasks flags exactly what to adjust. If analyze fails on a plugin symbol, fix against that version's API — the interface contracts (Task 3) do not change.
- **`very_good_analysis` is strict** (80-col lines, `prefer_const`, package imports). Run `fvm dart format .` before every analyze; keep lines ≤ 80.
- **Do not** add web/desktop platforms, conditional `_io`/`_stub` files, Hive, or settings/persistence — all deferred per the spec.
