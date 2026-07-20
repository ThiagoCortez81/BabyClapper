import 'package:audio_session/audio_session.dart';
import 'package:baby_clapper/core/audio/sound_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:soundpool/soundpool.dart';

/// [SoundService] backed by the `soundpool` + `audio_session` plugins.
///
/// Configures a music-style playback session and preloads both rattle
/// samples once in [init]. Every playback call no-ops gracefully when the
/// pool or a sample failed to load, so a missing capability is never a
/// crash.
class SoundpoolSoundService implements SoundService {
  Soundpool? _pool;
  int? _beadId;
  int? _rattleId;

  @override
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Intentionally broad: a failed session configuration must not stop
      // sample loading below, so playback can still degrade gracefully.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Unsupported platform / config rejected — playback can still work.
    }

    final pool = Soundpool.fromOptions(
      options: const SoundpoolOptions(maxStreams: 8),
    );
    _pool = pool;
    _beadId = await _loadAsset(pool, 'assets/sounds/bead.wav');
    _rattleId = await _loadAsset(pool, 'assets/sounds/rattle.wav');
  }

  Future<int?> _loadAsset(Soundpool pool, String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final id = await pool.load(data);
      return id > -1 ? id : null;
      // Intentionally broad: any load failure (missing asset, platform
      // error) degrades to "sample unavailable" rather than a crash.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> playBead({
    required double rate,
    required double volume,
  }) async {
    final pool = _pool;
    final id = _beadId;
    if (pool == null || id == null) return;
    final streamId = await pool.play(id, rate: rate.clamp(0.5, 2.0));
    if (streamId == 0) return;
    await pool.setVolume(
      streamId: streamId,
      volume: volume.clamp(0.0, 1.0),
    );
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
    _beadId = null;
    _rattleId = null;
  }
}
