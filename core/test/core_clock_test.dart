import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('CoreClock Tests', () {
    tearDown(() {
      CoreClock.reset();
    });

    test('defaults to system clock time', () {
      final before = DateTime.now();
      final clockNow = CoreClock.now;
      final after = DateTime.now();

      expect(
        clockNow.isAfter(before.subtract(const Duration(milliseconds: 10))) ||
            clockNow.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        clockNow.isBefore(after.add(const Duration(milliseconds: 10))) ||
            clockNow.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('setNow overrides time queries deterministically', () {
      final customTime = DateTime(2026, 9, 21, 10, 0, 0);
      CoreClock.setNow(() => customTime);

      expect(CoreClock.now, equals(customTime));

      var counter = 0;
      CoreClock.setNow(() => customTime.add(Duration(minutes: counter++)));

      expect(CoreClock.now, equals(customTime));
      expect(CoreClock.now, equals(customTime.add(const Duration(minutes: 1))));
      expect(CoreClock.now, equals(customTime.add(const Duration(minutes: 2))));
    });

    test('reset restores default system DateTime.now behavior', () {
      final pastTime = DateTime(2000, 1, 1, 0, 0, 0);
      CoreClock.setNow(() => pastTime);

      expect(CoreClock.now, equals(pastTime));

      CoreClock.reset();

      final systemNow = DateTime.now();
      final clockNow = CoreClock.now;

      expect(
        clockNow.difference(systemNow).inSeconds.abs(),
        lessThanOrEqualTo(2),
      );
    });
  });
}
