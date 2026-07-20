// SoundpoolSoundService: SoundService implementation backed by the
// soundpool + audio_session plugins. Configures an ambient/mixing
// playback session (respects the iOS silent switch, never requests
// Android audio focus) and preloads the bead + rattle samples once in
// init(). Wired as an app-lifetime singleton in
// core/di/injection_container.dart. Invariant: playBead must call
// pool.setVolume() BEFORE pool.play() — bead.wav's entire perceptual
// content is its first ~15ms attack, so setting volume on the resulting
// stream afterwards lands too late and makes volume-scaling inert.
import 'package:audio_session/audio_session.dart';
import 'package:baby_clapper/features/rattle/domain/sound_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:soundpool/soundpool.dart';

/// [SoundService] backed by the `soundpool` + `audio_session` plugins.
///
/// Configures an ambient/mixing playback session and preloads both rattle
/// samples once in [init]. Every playback call no-ops gracefully when the
/// pool or a sample failed to load, so a missing capability is never a
/// crash.
class SoundpoolSoundService implements SoundService {
  Soundpool? _pool;
  int? _beadId;
  int? _rattleId;

  // Owner decision: the rattle must go SILENT when the phone's silent
  // switch is on, and must MIX with other audio (music/podcasts keep
  // playing) rather than interrupting it. Haptics still work regardless of
  // this session's state — the two channels degrade independently.
  //
  // iOS: `ambient` is the category that respects the silent switch (unlike
  // `playback`, which ignores it) and mixes with other audio by default;
  // `mixWithOthers` makes that explicit.
  //
  // Android has no true silent-switch equivalent. The android* fields below
  // are declarative only: audio_session applies them via setActive(true),
  // which this app never calls, so no audio focus is ever requested — which
  // is precisely the behaviour we want (never requesting focus is why other
  // apps' audio is never paused). Actual SoundPool playback attributes come
  // from soundpool's own pool creation, not from this config. Keep these
  // fields as intent documentation; do not rely on them taking effect.
  static const _sessionConfig = AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.ambient,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.sonification,
      usage: AndroidAudioUsage.assistanceSonification,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
  );

  @override
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(_sessionConfig);
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
    // `bead.wav` is an ~80ms exponentially-decaying click whose entire
    // perceptual content is the first ~15ms, so volume must be set on the
    // SOUND before `play()` — setting it on the resulting stream afterwards
    // lands after the attack and makes the volume half of speed-scaling
    // inert.
    await pool.setVolume(soundId: id, volume: volume.clamp(0.0, 1.0));
    await pool.play(id, rate: rate.clamp(0.5, 2.0));
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
