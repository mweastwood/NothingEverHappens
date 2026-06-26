import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/sort_helper.dart';

void main() {
  group('SortHelper unit tests', () {
    test('updateSortHistory adds new column to empty list', () {
      final history = updateSortHistory([], 'title');
      expect(history, hasLength(1));
      expect(history.first.column, 'title');
      expect(history.first.ascending, true);
    });

    test('updateSortHistory toggles ascending flag if same column clicked', () {
      var history = <({String column, bool ascending})>[
        (column: 'title', ascending: true),
      ];
      history = updateSortHistory(history, 'title');
      expect(history.first.column, 'title');
      expect(history.first.ascending, false);

      history = updateSortHistory(history, 'title');
      expect(history.first.column, 'title');
      expect(history.first.ascending, true);
    });

    test('updateSortHistory moves clicked column to the top of history', () {
      var history = <({String column, bool ascending})>[
        (column: 'priority', ascending: true),
        (column: 'title', ascending: true),
      ];
      history = updateSortHistory(history, 'title');
      expect(history, hasLength(2));
      expect(history.first.column, 'title');
      expect(history.first.ascending, true);
      expect(history[1].column, 'priority');
    });

    test('updateSortHistory limits history stack to max 3 levels', () {
      var history = <({String column, bool ascending})>[
        (column: 'a', ascending: true),
        (column: 'b', ascending: true),
        (column: 'c', ascending: true),
      ];
      history = updateSortHistory(history, 'd');
      expect(history, hasLength(3));
      expect(history[0].column, 'd');
      expect(history[1].column, 'a');
      expect(history[2].column, 'b');
    });

    test(
      'compareDateTimes sorts DateTimes correctly with null values at end',
      () {
        final a = DateTime(2026, 10, 26, 10, 0);
        final b = DateTime(2026, 10, 26, 11, 0);

        // Ascending
        expect(compareDateTimes(a, b, true), -1);
        expect(compareDateTimes(b, a, true), 1);
        expect(compareDateTimes(a, a, true), 0);

        // Descending
        expect(compareDateTimes(a, b, false), 1);
        expect(compareDateTimes(b, a, false), -1);

        // Null handling (null is always greater/put at the end)
        expect(compareDateTimes(null, a, true), 1);
        expect(compareDateTimes(a, null, true), -1);
        expect(compareDateTimes(null, null, true), 0);
      },
    );
  });
}
