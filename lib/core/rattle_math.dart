/// Pure feedback math for the rattle. No Flutter, no plugins — fully testable.
library;

/// Playback parameters for a bead sound: pitch rate and volume.
typedef BeadPlayback = ({double rate, double volume});

/// Swipe speed in logical pixels per millisecond. Returns `0` for a zero
/// time delta (avoids division by zero on coincident pointer samples).
double velocityFromDelta(double distancePx, Duration dt) {
  final ms = dt.inMicroseconds / 1000.0;
  if (ms <= 0) return 0;
  return distancePx / ms;
}

/// Maps swipe speed to a haptic intensity in `0.0..1.0`.
double swipeIntensity(double velocityPxPerMs) {
  return (velocityPxPerMs / 4.0).clamp(0.0, 1.0);
}

/// Maps swipe speed to bead-sound playback: faster = higher pitch + louder.
BeadPlayback beadPlayback(double velocityPxPerMs) {
  final t = (velocityPxPerMs / 4.0).clamp(0.0, 1.0);
  return (rate: 0.8 + t * 1.0, volume: 0.3 + t * 0.7);
}

/// Whether a gravity-removed acceleration magnitude (m/s^2) is a shake.
bool isShakeMagnitude(
  double gravityRemovedMagnitude, {
  double threshold = 15.0,
}) {
  return gravityRemovedMagnitude >= threshold;
}
