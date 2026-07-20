import 'dart:developer';

import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:baby_clapper/core/audio/soundpool_sound_service.dart';
import 'package:baby_clapper/core/haptics/haptic_service.dart';
import 'package:baby_clapper/core/haptics/vibration_haptic_service.dart';
import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/core/motion/sensors_motion_service.dart';
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
