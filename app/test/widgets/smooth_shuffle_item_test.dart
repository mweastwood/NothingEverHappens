import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/smooth_shuffle_item.dart';

void main() {
  setUp(() {
    SmoothShuffleItem.clearPositions();
  });

  testWidgets('SmoothShuffleItem renders child correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmoothShuffleItem(id: 'test-1', child: Text('Item 1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('SmoothShuffleItem animates smoothly when position changes', (
    tester,
  ) async {
    final ValueNotifier<bool> isReordered = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isReordered,
            builder: (context, reordered, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (!reordered)
                          const SmoothShuffleItem(
                            id: 'item-A',
                            child: SizedBox(
                              key: Key('box-A'),
                              height: 50,
                              child: Text('A'),
                            ),
                          ),
                        const SmoothShuffleItem(
                          id: 'item-B',
                          child: SizedBox(
                            key: Key('box-B'),
                            height: 50,
                            child: Text('B'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (reordered)
                          const SmoothShuffleItem(
                            id: 'item-A',
                            child: SizedBox(
                              key: Key('box-A'),
                              height: 50,
                              child: Text('A'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial position of item-A
    final initialPosA = tester.getTopLeft(find.byKey(const Key('box-A')));

    // Reorder: item-A moves to right column
    isReordered.value = true;
    await tester.pump();
    await tester.pump(); // Start ticker frame at t=0
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-animation position of item-A should be moving across
    final midPosA = tester.getTopLeft(find.byKey(const Key('box-A')));
    expect(midPosA.dx, greaterThan(initialPosA.dx));
    expect(midPosA.dx, lessThan(initialPosA.dx + 400));

    // Settle animation
    await tester.pumpAndSettle();
    final finalPosA = tester.getTopLeft(find.byKey(const Key('box-A')));
    expect(finalPosA.dx, greaterThan(initialPosA.dx));
  });

  testWidgets(
    'Scrolling a list does not trigger translation animations on SmoothShuffleItem',
    (tester) async {
      final items = List.generate(20, (index) => 'item-$index');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: items.length,
              itemExtent: 80.0,
              itemBuilder: (context, index) {
                return SmoothShuffleItem(
                  id: items[index],
                  child: SizedBox(
                    key: Key('box-$index'),
                    height: 80,
                    child: Text('Item $index'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no Transform widgets (active animations) are in the tree initially
      expect(
        find.descendant(
          of: find.byType(SmoothShuffleItem),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      // Scroll down so new items mount and existing items move in viewport
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      // Post-frame callback should execute _checkPosition without triggering animation
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(
          of: find.byType(SmoothShuffleItem),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      // Scroll back up quickly
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(
          of: find.byType(SmoothShuffleItem),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SmoothShuffleItem),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Reordering items while scrolled still animates correctly', (
    tester,
  ) async {
    final ValueNotifier<bool> isReordered = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 400), // Dummy space to allow scrolling
                ValueListenableBuilder<bool>(
                  valueListenable: isReordered,
                  builder: (context, reordered, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              if (!reordered)
                                const SmoothShuffleItem(
                                  id: 'scrolled-A',
                                  child: SizedBox(
                                    key: Key('scrolled-box-A'),
                                    height: 100,
                                    child: Text('Scrolled A'),
                                  ),
                                ),
                              const SmoothShuffleItem(
                                id: 'scrolled-B',
                                child: SizedBox(
                                  key: Key('scrolled-box-B'),
                                  height: 100,
                                  child: Text('Scrolled B'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              if (reordered)
                                const SmoothShuffleItem(
                                  id: 'scrolled-A',
                                  child: SizedBox(
                                    key: Key('scrolled-box-A'),
                                    height: 100,
                                    child: Text('Scrolled A'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down by 200px
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    final initialPosA = tester.getTopLeft(
      find.byKey(const Key('scrolled-box-A')),
    );

    // Reorder items while scrolled
    isReordered.value = true;
    await tester.pump();
    await tester.pump(); // Start frame
    await tester.pump(const Duration(milliseconds: 150));

    // mid-animation: both item-A (moving right) and item-B (sliding up) should be animating
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SmoothShuffleItem && w.id == 'scrolled-A',
        ),
        matching: find.byType(Transform),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SmoothShuffleItem),
        matching: find.byType(Transform),
      ),
      findsNWidgets(2),
    );
    final midPosA = tester.getTopLeft(find.byKey(const Key('scrolled-box-A')));
    expect(midPosA.dx, greaterThan(initialPosA.dx));

    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SmoothShuffleItem),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    final finalPosA = tester.getTopLeft(
      find.byKey(const Key('scrolled-box-A')),
    );
    expect(finalPosA.dx, greaterThan(initialPosA.dx));
  });

  testWidgets(
    'Widget rebuilds during scroll do not trigger shuffle animations',
    (tester) async {
      final ValueNotifier<int> rebuildTrigger = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<int>(
                valueListenable: rebuildTrigger,
                builder: (context, _, child) {
                  return Column(
                    children: [
                      const SizedBox(height: 300),
                      const SmoothShuffleItem(
                        id: 'stable-item',
                        child: SizedBox(
                          key: Key('stable-box'),
                          height: 100,
                          child: Text('Stable Item'),
                        ),
                      ),
                      const SizedBox(height: 500),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();

      // Trigger rebuild while scrolled
      rebuildTrigger.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should NOT trigger animation / translation
      expect(
        find.descendant(
          of: find.byType(SmoothShuffleItem),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    },
  );
}
