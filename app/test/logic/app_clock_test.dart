import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

void main() {
  group('AppClock Unit Tests', () {
    tearDown(() {});

    test('now returns real system time by default', () {
      final clockTime = AppClock.now;
      final systemTime = DateTime.now();

      // Should be extremely close to the current system time (within 100 milliseconds)
      expect(
        clockTime.difference(systemTime).inMilliseconds.abs() < 100,
        isTrue,
      );
      expect(AppClock.timeNotifier.value, isNull);
    });

    test('setMockTime overrides system clock and updates notifier', () {
      final mockTime = DateTime(2026, 3, 8, 9, 0);
      AppClock.setMockTime(mockTime);
      addTearDown(AppClock.reset);

      expect(AppClock.now, mockTime);
      expect(AppClock.timeNotifier.value, mockTime);
    });

    test('advanceTime increases mock time relatively', () {
      final mockTime = DateTime(2026, 3, 8, 9, 0);
      AppClock.setMockTime(mockTime);
      addTearDown(AppClock.reset);

      AppClock.advanceTime(const Duration(hours: 2, minutes: 15));

      final expectedTime = DateTime(2026, 3, 8, 11, 15);
      expect(AppClock.now, expectedTime);
      expect(AppClock.timeNotifier.value, expectedTime);
    });

    test(
      'advanceTime when real-time starts mock mode from advanced current time',
      () {
        AppClock.reset();

        final beforeAdvance = DateTime.now();
        AppClock.advanceTime(const Duration(days: 5));
        final afterAdvance = AppClock.now;

        final expectedTime = beforeAdvance.add(const Duration(days: 5));
        expect(
          afterAdvance.difference(expectedTime).inMilliseconds.abs() < 100,
          isTrue,
        );
        expect(AppClock.isMockActive, isTrue);
      },
    );

    test(
      'reset clears mock overrides back to real-time and notifies listeners',
      () {
        final mockTime = DateTime(2026, 3, 8, 9, 0);
        AppClock.setMockTime(mockTime);
        addTearDown(AppClock.reset);

        expect(AppClock.timeNotifier.value, isNotNull);

        AppClock.reset();

        expect(AppClock.timeNotifier.value, isNull);

        final clockTime = AppClock.now;
        final systemTime = DateTime.now();
        expect(
          clockTime.difference(systemTime).inMilliseconds.abs() < 100,
          isTrue,
        );
      },
    );
  });
}
