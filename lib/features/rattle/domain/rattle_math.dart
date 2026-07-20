/// Pure feedback math for the rattle. No Flutter, no plugins — fully testable.
library;

/// Playback parameters for a bead sound: pitch rate and volume.
typedef BeadPlayback = ({double rate, double volume});

/// Divisor mapping swipe speed (px/ms) onto the `0.0..1.0` intensity curve
/// used by both haptic ticks and bead playback. Tune this on real hardware
/// to change how fast a swipe must be to reach full intensity.
const double kVelocityDivisor = 4;

/// Gravity-removed acceleration magnitude (m/s^2) above which a motion
/// sample counts as a shake. Tune this on real hardware to change shake
/// sensitivity.
const double kShakeThreshold = 15;

/// Minimum time between two shake events. A single physical shake spans
/// several sensor samples above [kShakeThreshold]; this cooldown collapses
/// them into one [isShakeDue] `true` result. Tune this on real hardware.
const Duration kShakeCooldown = Duration(milliseconds: 300);

/// Minimum time between two dispatched swipe ticks, so a fast swipe doesn't
/// queue thousands of vibrations/samples. Tune this on real hardware.
const Duration kSwipeThrottle = Duration(milliseconds: 40);

/// Swipe speed in logical pixels per millisecond. Returns `0` for a zero
/// time delta (avoids division by zero on coincident pointer samples).
double velocityFromDelta(double distancePx, Duration dt) {
  final ms = dt.inMicroseconds / 1000.0;
  if (ms <= 0) return 0;
  return distancePx / ms;
}

/// Maps swipe speed to a haptic intensity in `0.0..1.0`.
double swipeIntensity(double velocityPxPerMs) {
  return (velocityPxPerMs / kVelocityDivisor).clamp(0.0, 1.0);
}

/// Maps swipe speed to bead-sound playback: faster = higher pitch + louder.
BeadPlayback beadPlayback(double velocityPxPerMs) {
  final t = swipeIntensity(velocityPxPerMs);
  return (rate: 0.8 + t * 1.0, volume: 0.3 + t * 0.7);
}

/// Whether a gravity-removed acceleration magnitude (m/s^2) is a shake.
bool isShakeMagnitude(
  double gravityRemovedMagnitude, {
  double threshold = kShakeThreshold,
}) {
  return gravityRemovedMagnitude >= threshold;
}

/// Whether enough time has passed since [last] shake for a new shake at
/// [now] to be dispatched, given a [cooldown] window. `now - last >=
/// cooldown` is due; strictly inside the window is not (boundary is due).
bool isShakeDue(
  DateTime last,
  DateTime now, {
  Duration cooldown = kShakeCooldown,
}) {
  return now.difference(last) >= cooldown;
}
