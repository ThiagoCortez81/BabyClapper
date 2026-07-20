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

    // `TestGesture.moveBy` defaults `timeStamp` to `Duration.zero`, so it
    // must be passed explicitly here — otherwise every synthesized move
    // shares timestamp zero, `velocityFromDelta`'s `dt` is always zero,
    // and the surface's 40ms throttle never clears (real devices always
    // populate real event timestamps, so this only affects the harness).
    final gesture = await tester.startGesture(const Offset(50, 300));
    var elapsed = Duration.zero;
    for (var i = 0; i < 6; i++) {
      elapsed += const Duration(milliseconds: 60);
      await gesture.moveBy(const Offset(40, 0), timeStamp: elapsed);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up(timeStamp: elapsed);
    await tester.pump();

    expect(haptic.ticks, greaterThan(0));
  });

  testWidgets(
    'moves faster than the 40ms throttle are suppressed',
    (tester) async {
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

      // The very first move only seeds the per-pointer track (no prior
      // sample to diff against), and a suppressed move does NOT advance
      // that track's timestamp — so as long as every subsequent move stays
      // within 40ms of the seed, all of them stay suppressed. Deleting the
      // `if (dt < kSwipeThrottle) return;` guard would let every one of
      // these through instead.
      final gesture = await tester.startGesture(const Offset(50, 300));
      var elapsed = Duration.zero;
      for (var i = 0; i < 4; i++) {
        elapsed += const Duration(milliseconds: 8);
        await gesture.moveBy(const Offset(40, 0), timeStamp: elapsed);
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up(timeStamp: elapsed);
      await tester.pump();

      expect(haptic.ticks, 0);
    },
  );
}
