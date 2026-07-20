import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owns the app's fullscreen presentation: immersive system UI + wakelock.
class ImmersiveMode {
  /// Enable immersive mode and acquire wakelock on startup.
  Future<void> enable() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  /// Re-hide the system bars after the OS restores them (call on resume).
  Future<void> reassert() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Releases the wakelock (call when the app leaves the foreground).
  Future<void> releaseWakelock() async {
    await WakelockPlus.disable();
  }
}
