import 'dart:async';

import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
import 'package:baby_clapper/features/rattle/domain/motion_service.dart';
import 'package:baby_clapper/features/rattle/domain/sound_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHaptic implements HapticService {
  FakeHaptic({this.throwOnTick = false});
  final bool throwOnTick;
  final List<double> ticks = [];
  int bursts = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> tick(double intensity) async {
    if (throwOnTick) throw StateError('haptic unavailable');
    ticks.add(intensity);
  }

  @override
  Future<void> burst() async => bursts++;
}

class FakeSound implements SoundService {
  FakeSound({this.throwOnPlayBead = false});
  final bool throwOnPlayBead;
  final List<BeadCall> beads = [];
  int rattles = 0;
  @override
  Future<void> init() async {}
  @override
  Future<void> playBead({required double rate, required double volume}) async {
    if (throwOnPlayBead) throw StateError('sound unavailable');
    beads.add(BeadCall(rate, volume));
  }

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
    'RattleInitialized marks the bloc ready',
    build: build,
    act: (bloc) {
      bloc.add(const RattleInitialized());
      motion.emitShake();
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [const RattleState(ready: true)],
    verify: (_) => expect(haptic.bursts, 1),
  );

  test(
    'the shake subscription is wired at construction time, before any '
    'event is added',
    () async {
      final bloc = build();
      addTearDown(bloc.close);

      // No `add()` call at all — the shake subscription must already be
      // live from the constructor for this to fire.
      motion.emitShake();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(haptic.bursts, 1);
      expect(sound.rattles, 1);
    },
  );

  blocTest<RattleBloc, RattleState>(
    'a throwing haptic channel does not block the sound channel',
    build: () => RattleBloc(
      haptic: FakeHaptic(throwOnTick: true),
      sound: sound,
      motion: motion,
    ),
    act: (bloc) => bloc.add(const SwipeTick(4)),
    verify: (_) {
      expect(sound.beads, hasLength(1));
    },
    errors: () => <Object>[],
  );

  blocTest<RattleBloc, RattleState>(
    'a throwing sound channel does not block the haptic channel',
    build: () => RattleBloc(
      haptic: haptic,
      sound: FakeSound(throwOnPlayBead: true),
      motion: motion,
    ),
    act: (bloc) => bloc.add(const SwipeTick(4)),
    verify: (_) {
      expect(haptic.ticks, hasLength(1));
    },
    errors: () => <Object>[],
  );
}
