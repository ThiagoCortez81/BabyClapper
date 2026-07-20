// HapticService: abstract vibration-feedback contract implemented by
// VibrationHapticService.
/// Vibration feedback. Implementations wrap the platform plugin and must
/// no-op gracefully when the device has no vibrator.
abstract interface class HapticService {
  /// Initializes the underlying platform plugin.
  Future<void> init();

  /// A single bead tick; [intensity] is `0.0..1.0`.
  Future<void> tick(double intensity);

  /// A multi-pulse rattle burst.
  Future<void> burst();
}
