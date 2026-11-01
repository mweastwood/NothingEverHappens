import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/utils/format_utils.dart';

void main() {
  group('formatDurationHours', () {
    test('formats hours and minutes correctly', () {
      expect(formatDurationHours(2.25), equals('2h 15m'));
      expect(formatDurationHours(1.5), equals('1h 30m'));
      expect(FormatUtils.formatDurationHours(1.5), equals('1h 30m'));
    });

    test('formats whole hours correctly', () {
      expect(formatDurationHours(4.0), equals('4h'));
      expect(formatDurationHours(8.0), equals('8h'));
      expect(formatDurationHours(1.0), equals('1h'));
    });

    test('formats zero hours and fractional minutes only', () {
      expect(formatDurationHours(0.0), equals('0m'));
      expect(formatDurationHours(0.5), equals('30m'));
      expect(formatDurationHours(0.75), equals('45m'));
    });
  });

  group('FormatUtils.formatDuration', () {
    test('formats zero or negative durations as empty string by default', () {
      expect(FormatUtils.formatDuration(Duration.zero), equals(''));
      expect(
        FormatUtils.formatDuration(const Duration(minutes: -10)),
        equals(''),
      );
    });

    test('formats minutes under an hour', () {
      expect(
        FormatUtils.formatDuration(const Duration(minutes: 45)),
        equals('45 min'),
      );
    });

    test('formats single and multiple hours with optional minutes', () {
      expect(
        FormatUtils.formatDuration(const Duration(hours: 1)),
        equals('1 hr'),
      );
      expect(
        FormatUtils.formatDuration(const Duration(hours: 1, minutes: 30)),
        equals('1 hr 30 min'),
      );
      expect(
        FormatUtils.formatDuration(const Duration(hours: 2)),
        equals('2 hrs'),
      );
      expect(
        FormatUtils.formatDuration(const Duration(hours: 2, minutes: 15)),
        equals('2 hrs 15 min'),
      );
    });

    test('formats compact durations when compact is true', () {
      expect(
        FormatUtils.formatDuration(
          const Duration(hours: 1, minutes: 30),
          compact: true,
        ),
        equals('1h 30m'),
      );
      expect(
        FormatUtils.formatDuration(const Duration(hours: 2), compact: true),
        equals('2h'),
      );
      expect(
        FormatUtils.formatDuration(const Duration(minutes: 45), compact: true),
        equals('45m'),
      );
    });
  });

  group('FormatUtils.formatIsoDate', () {
    test(
      'formats single-digit and double-digit months and days with zero padding',
      () {
        expect(
          FormatUtils.formatIsoDate(DateTime(2026, 3, 8)),
          equals('2026-03-08'),
        );
        expect(
          FormatUtils.formatIsoDate(DateTime(2026, 11, 25)),
          equals('2026-11-25'),
        );
      },
    );
  });
}
