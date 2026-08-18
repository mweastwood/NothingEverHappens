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
}
