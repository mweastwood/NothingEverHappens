import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/two_column_masonry_list.dart';

typedef _TestItem = ({String id, double height});

void main() {
  group('TwoColumnMasonryList', () {
    test(
      'distribute balances items by height and preserves column affinity',
      () {
        final affinity = <String, int>{};
        final items = <_TestItem>[
          (id: 'a', height: 100),
          (id: 'b', height: 150),
          (id: 'c', height: 80),
        ];

        final initial = TwoColumnMasonryList.distribute<_TestItem>(
          items: items,
          idOf: (i) => i.id,
          estimatedHeightOf: (i) => i.height,
          columnAffinity: affinity,
        );

        expect(initial.leftColumn.map((i) => i.id), equals(['a', 'c']));
        expect(initial.rightColumn.map((i) => i.id), equals(['b']));
        expect(affinity, equals({'a': 0, 'b': 1, 'c': 0}));

        // Removing 'a' preserves 'b' in right column and 'c' in left column,
        // and prunes 'a' from affinity map.
        final afterRemove = TwoColumnMasonryList.distribute<_TestItem>(
          items: [items[1], items[2]],
          idOf: (i) => i.id,
          estimatedHeightOf: (i) => i.height,
          columnAffinity: affinity,
        );

        expect(afterRemove.leftColumn.map((i) => i.id), equals(['c']));
        expect(afterRemove.rightColumn.map((i) => i.id), equals(['b']));
        expect(affinity.containsKey('a'), isFalse);
      },
    );

    testWidgets('renders items in two side-by-side columns', (tester) async {
      final affinity = <String, int>{};
      final items = <_TestItem>[
        (id: 'item-1', height: 100),
        (id: 'item-2', height: 100),
        (id: 'item-3', height: 100),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwoColumnMasonryList<_TestItem>(
              items: items,
              idOf: (i) => i.id,
              estimatedHeightOf: (i) => i.height,
              columnAffinity: affinity,
              itemBuilder: (context, item) =>
                  SizedBox(height: item.height, child: Text(item.id)),
            ),
          ),
        ),
      );

      final rect1 = tester.getRect(find.text('item-1'));
      final rect2 = tester.getRect(find.text('item-2'));
      final rect3 = tester.getRect(find.text('item-3'));

      expect(rect1.left, equals(rect3.left));
      expect(rect2.left, greaterThan(rect1.left));
    });
  });
}
