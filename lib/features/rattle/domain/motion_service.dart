/// Device-motion source. Emits on [shakes] each time a shake is detected.
abstract interface class MotionService {
  /// Emits an event each time a shake gesture is detected.
  Stream<void> get shakes;

  /// Initializes the underlying motion-sensor plugin.
  Future<void> init();

  /// Releases any resources held by the underlying motion-sensor plugin.
  Future<void> dispose();
}
