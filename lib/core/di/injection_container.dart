// DI bootstrap (GetIt): constructs, initializes, and registers
// HapticService, SoundService, MotionService, and the RattleBloc factory.
// Invariant: each service's init() runs through _initSafely, its own
// isolated try/catch, so one plugin failing on a platform-channel edge
// case degrades only that one service and never aborts boot or blocks the
// others from initializing (CLAUDE.md "graceful-degrade, never a crash").
// Called once from main.dart at startup; per the avoid_get_it_in_widgets
// architecture rule, `sl`/`GetIt` are referenced only from this file and
// main.dart, never from widgets.
import 'dart:developer';

import 'package:baby_clapper/features/rattle/data/sensors_motion_service.dart';
import 'package:baby_clapper/features/rattle/data/soundpool_sound_service.dart';
import 'package:baby_clapper/features/rattle/data/vibration_haptic_service.dart';
import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
import 'package:baby_clapper/features/rattle/domain/motion_service.dart';
import 'package:baby_clapper/features/rattle/domain/sound_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:get_it/get_it.dart';

/// The app's single service locator instance.
final GetIt sl = GetIt.instance;

/// Constructs, initializes, and registers all services + the bloc factory.
///
/// Each service's [init] is isolated in its own try/catch: a plugin
/// throwing on a platform-channel edge case must degrade that one service,
/// never abort boot or block the other services from initializing (see
/// CLAUDE.md "graceful-degrade, never a crash").
Future<void> init() async {
  final haptic = VibrationHapticService();
  final sound = SoundpoolSoundService();
  final motion = SensorsMotionService();

  await _initSafely('HapticService', haptic.init);
  await _initSafely('SoundService', sound.init);
  await _initSafely('MotionService', motion.init);

  // SoundService and MotionService are intentionally never disposed here:
  // both are registered as app-lifetime singletons that live for the
  // process's whole life, so their `dispose()` (pool teardown / stream
  // subscription cancellation) is unused in practice and only exists for
  // symmetry / unit-test cleanup.
  sl
    ..registerSingleton<HapticService>(haptic)
    ..registerSingleton<SoundService>(sound)
    ..registerSingleton<MotionService>(motion)
    ..registerFactory<RattleBloc>(
      () => RattleBloc(haptic: sl(), sound: sl(), motion: sl()),
    );
}

/// Runs a service's [init] and swallows any failure so one service's
/// init error can't abort boot or prevent the others from initializing.
Future<void> _initSafely(String name, Future<void> Function() init) async {
  try {
    await init();
    // Intentionally broad: any plugin/platform-channel failure here must
    // degrade that one service, never abort boot or block the others.
    // ignore: avoid_catches_without_on_clauses
  } catch (error, stackTrace) {
    log(
      'init failed, degrading gracefully: $error',
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
