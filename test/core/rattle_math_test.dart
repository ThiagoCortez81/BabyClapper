import 'package:baby_clapper/core/rattle_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('velocityFromDelta', () {
    test('is distance over milliseconds', () {
      expect(
        velocityFromDelta(100, const Duration(milliseconds: 50)),
        closeTo(2.0, 1e-9),
      );
    });
    test('is zero when dt is zero', () {
      expect(velocityFromDelta(100, Duration.zero), 0.0);
    });
  });

  group('swipeIntensity', () {
    test('clamps to 0..1', () {
      expect(swipeIntensity(-5), 0.0);
      expect(swipeIntensity(1000), 1.0);
    });
    test('is monotonic non-decreasing', () {
      expect(swipeIntensity(1) <= swipeIntensity(3), isTrue);
    });
  });

  group('beadPlayback', () {
    test('stays within rate/volume bounds', () {
      final slow = beadPlayback(0);
      final fast = beadPlayback(1000);
      expect(slow.rate, inInclusiveRange(0.8, 1.8));
      expect(slow.volume, inInclusiveRange(0.3, 1.0));
      expect(fast.rate, inInclusiveRange(0.8, 1.8));
      expect(fast.volume, inInclusiveRange(0.3, 1.0));
      expect(fast.volume >= slow.volume, isTrue);
    });
  });

  group('isShakeMagnitude', () {
    test('true above threshold, false below', () {
      expect(isShakeMagnitude(20), isTrue);
      expect(isShakeMagnitude(5), isFalse);
    });
  });

  group('isShakeDue', () {
    final last = DateTime(2026, 1, 1, 12);

    test('is not due strictly inside the cooldown window', () {
      final now = last.add(const Duration(milliseconds: 299));
      expect(isShakeDue(last, now), isFalse);
    });

    test('is due once the cooldown window has fully elapsed', () {
      final now = last.add(const Duration(milliseconds: 301));
      expect(isShakeDue(last, now), isTrue);
    });

    test('is due exactly at the cooldown boundary', () {
      final now = last.add(kShakeCooldown);
      expect(isShakeDue(last, now), isTrue);
    });
  });
}
