import 'package:core/src/models/date_time_parser.dart';
import 'package:test/test.dart';

class _FakeTimestamp {
  final DateTime _date;
  const _FakeTimestamp(this._date);
  DateTime toDate() => _date;
}

void main() {
  group('parseFlexibleDateTime', () {
    test('returns null when value is null or unrecognized', () {
      expect(parseFlexibleDateTime(null), isNull);
      expect(parseFlexibleDateTime('not-a-date'), isNull);
      expect(parseFlexibleDateTime(Object()), isNull);
    });

    test('returns DateTime directly when value is already a DateTime', () {
      final local = DateTime(2026, 9, 16, 15, 16, 27);
      final parsed = parseFlexibleDateTime(local);
      expect(parsed, equals(local));
    });

    test('parses ISO-8601 strings and compact digit strings', () {
      expect(
        parseFlexibleDateTime('2026-09-16T15:16:27.529188Z'),
        equals(DateTime.utc(2026, 9, 16, 15, 16, 27, 529, 188)),
      );
      expect(parseFlexibleDateTime('2026')!.year, equals(2026));
      final ym = parseFlexibleDateTime('202609')!;
      expect(ym.year, equals(2026));
      expect(ym.month, equals(9));
      final ymd = parseFlexibleDateTime('20260923')!;
      expect(ymd.year, equals(2026));
      expect(ymd.month, equals(9));
      expect(ymd.day, equals(23));
    });

    test('parses numeric strings and ints as seconds or milliseconds', () {
      expect(
        parseFlexibleDateTime('1725000000')!.millisecondsSinceEpoch,
        equals(1725000000000),
      );
      expect(
        parseFlexibleDateTime('1725000000500')!.millisecondsSinceEpoch,
        equals(1725000000500),
      );
      expect(
        parseFlexibleDateTime(1725000000500)!.millisecondsSinceEpoch,
        equals(1725000000500),
      );
    });

    test('parses Firestore map timestamps with microsecond precision', () {
      final fromStrings = parseFlexibleDateTime({
        '_seconds': '1725000000',
        '_nanoseconds': '500000000',
      });
      expect(fromStrings!.millisecondsSinceEpoch, equals(1725000000500));

      final fromInts = parseFlexibleDateTime({
        'seconds': 1789571787,
        'nanoseconds': 529188000,
      });
      expect(fromInts!.isUtc, isTrue);
      expect(fromInts.microsecondsSinceEpoch, equals(1789571787529188));
    });

    test('invokes toDate() on Firestore Timestamp-like objects', () {
      final dt = DateTime.utc(2026, 6, 13, 10, 0);
      final parsed = parseFlexibleDateTime(_FakeTimestamp(dt));
      expect(parsed, equals(dt));
    });
  });
}
