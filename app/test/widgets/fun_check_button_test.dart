import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';

void main() {
  testWidgets('FunCheckButton shows check icon when true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FunCheckButton(value: true, onChanged: (value) {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets(
    'FunCheckButton does not show check icon when false and not hovering',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FunCheckButton(value: false, onChanged: (value) {}),
          ),
        ),
      );

      // Initial state: not checked, not hovering
      expect(find.byType(Icon), findsNothing);
    },
  );

  testWidgets('FunCheckButton calls onChanged when tapped', (
    WidgetTester tester,
  ) async {
    bool? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FunCheckButton(
            value: false,
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FunCheckButton));
    // Wait for the shrink animation (forward)
    await tester.pump(const Duration(milliseconds: 100));
    // Wait for the expand animation (reverse)
    await tester.pump(const Duration(milliseconds: 100));

    expect(changedValue, isTrue);
  });
}
