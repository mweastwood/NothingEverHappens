import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/utils/format_utils.dart';

void main() {
  group('formatDurationHours', () {
    test('formats hours and minutes correctly', () {
      expect(formatDurationHours(2.25), equals('2h 15m'));
      expect(formatDurationHours(1.5), equals('1h 30m'));
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
}
