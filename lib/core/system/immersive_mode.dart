import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owns the app's fullscreen presentation: immersive system UI + wakelock.
class ImmersiveMode {
  /// Enable immersive mode and acquire wakelock.
  ///
  /// Called on startup, and again on resume — the OS can restore the
  /// system bars while backgrounded, so both the bar hide and the
  /// wakelock re-acquire need to happen again.
  Future<void> enable() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  /// Releases the wakelock (call when the app leaves the foreground).
  Future<void> releaseWakelock() async {
    await WakelockPlus.disable();
  }
}
