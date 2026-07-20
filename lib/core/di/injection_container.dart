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
