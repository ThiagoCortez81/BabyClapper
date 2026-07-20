import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:baby_clapper/features/rattle/domain/motion_service.dart';
import 'package:baby_clapper/features/rattle/domain/rattle_math.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// [MotionService] backed by the `sensors_plus` user-accelerometer stream.
///
/// Uses the *user* accelerometer (gravity already removed) so the raw
/// magnitude can be compared directly against [isShakeMagnitude]'s
/// threshold. [isShakeDue] enforces a cooldown so a single physical shake —
/// which spans several sensor samples above the threshold — fires only one
/// [shakes] event.
class SensorsMotionService implements MotionService {
  final StreamController<void> _shakes = StreamController<void>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<void> get shakes => _shakes.stream;

  @override
  Future<void> init() async {
    // Guard against reentrancy: a second init() call would otherwise leak
    // the first subscription instead of replacing it.
    if (_accelSub != null) return;
    _accelSub = userAccelerometerEventStream().listen(
      _onAccel,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'accelerometer stream error',
          name: 'MotionService',
          error: error,
          stackTrace: stackTrace,
        );
      },
      cancelOnError: false,
    );
  }

  void _onAccel(UserAccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!isShakeMagnitude(magnitude)) return;

    final now = DateTime.now();
    if (!isShakeDue(_lastShake, now)) return;
    _lastShake = now;
    _shakes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _accelSub?.cancel();
    // Clear the handle so the init() reentrancy guard doesn't mistake a
    // disposed service for an already-running one.
    _accelSub = null;
    await _shakes.close();
  }
}
