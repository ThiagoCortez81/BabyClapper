/// Rattle sound playback. Implementations wrap the audio plugin and must
/// no-op gracefully when audio is unavailable.
abstract interface class SoundService {
  /// Initializes the underlying audio plugin.
  Future<void> init();

  /// Plays a single bead sound at the given pitch [rate] and [volume].
  Future<void> playBead({required double rate, required double volume});

  /// Plays the multi-pulse rattle sound.
  Future<void> playRattle();

  /// Releases any resources held by the underlying audio plugin.
  Future<void> dispose();
}
