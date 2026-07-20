// VibrationHapticService: HapticService implementation backed by the
// vibration plugin. Checks hasVibrator()/hasAmplitudeControl() once in
// init() and no-ops gracefully when the device has no vibrator or lacks
// amplitude control (falls back to a fixed-duration buzz). Wired as an
// app-lifetime singleton in core/di/injection_container.dart.
import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
import 'package:vibration/vibration.dart';

/// [HapticService] backed by the `vibration` plugin.
///
/// Checks device capabilities once in [init] and no-ops gracefully when
/// the device has no vibrator.
class VibrationHapticService implements HapticService {
  bool _hasVibrator = false;
  bool _hasAmplitude = false;

  @override
  Future<void> init() async {
    _hasVibrator = await Vibration.hasVibrator();
    _hasAmplitude = await Vibration.hasAmplitudeControl();
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
    await Vibration.vibrate(
      pattern: const [0, 40, 30, 60, 30, 90, 40, 140],
    );
  }
}
