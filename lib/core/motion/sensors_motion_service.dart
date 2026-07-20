import 'dart:async';
import 'dart:math';

import 'package:baby_clapper/core/motion/motion_service.dart';
import 'package:baby_clapper/core/rattle_math.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// [MotionService] backed by the `sensors_plus` user-accelerometer stream.
///
/// Uses the *user* accelerometer (gravity already removed) so the raw
/// magnitude can be compared directly against [isShakeMagnitude]'s
/// threshold. A 300ms cooldown prevents a single physical shake — which
/// spans several sensor samples above the threshold — from firing more
/// than one [shakes] event.
class SensorsMotionService implements MotionService {
  final StreamController<void> _shakes = StreamController<void>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  static const _cooldown = Duration(milliseconds: 300);

  @override
  Stream<void> get shakes => _shakes.stream;

  @override
  Future<void> init() async {
    _accelSub = userAccelerometerEventStream().listen(_onAccel);
  }

  void _onAccel(UserAccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!isShakeMagnitude(magnitude)) return;

    final now = DateTime.now();
    if (now.difference(_lastShake) < _cooldown) return;
    _lastShake = now;
    _shakes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _accelSub?.cancel();
    await _shakes.close();
  }
}
