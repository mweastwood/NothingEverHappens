import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/absolute_date_widget.dart';
import '../test_helper.dart';

void main() {
  group('AbsoluteDateWidget', () {
    testWidgets('renders initial value and label', (tester) async {
      final date = DateTime(2026, 10, 26);
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: AbsoluteDateWidget(
              date: date,
              label: 'Custom Recurrence Date',
              onDateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Custom Recurrence Date'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('triggers onDateChanged when date is picked', (tester) async {
      final date = DateTime(2026, 10, 26);
      DateTime? selectedDate;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: AbsoluteDateWidget(
              date: date,
              label: 'Recurrence Date',
              onDateChanged: (picked) {
                selectedDate = picked;
              },
            ),
          ),
        ),
      );

      // Tap the widget to open date picker
      await tester.tap(find.byType(AbsoluteDateWidget));
      await tester.pumpAndSettle();

      // Pick a day (15)
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(selectedDate, isNotNull);
      expect(selectedDate!.day, 15);
      expect(selectedDate!.month, 10);
      expect(selectedDate!.year, 2026);
    });

    testWidgets('does not open picker when read-only (onDateChanged is null)', (
      tester,
    ) async {
      final date = DateTime(2026, 10, 26);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: AbsoluteDateWidget(
              date: date,
              label: 'Recurrence Date',
              onDateChanged: null,
            ),
          ),
        ),
      );

      // Tap the widget
      await tester.tap(find.byType(AbsoluteDateWidget));
      await tester.pumpAndSettle();

      // Assert date picker did not open (no 'OK' button)
      expect(find.text('OK'), findsNothing);
    });

    testGoldens('AbsoluteDateWidget renders correctly', (tester) async {
      final date = DateTime(2026, 10, 26);
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 4)
        ..addScenario(
          'Default',
          AbsoluteDateWidget(
            date: date,
            label: 'Start Recurrence Date',
            onDateChanged: (_) {},
          ),
        )
        ..addScenario(
          'Read-only',
          AbsoluteDateWidget(
            date: date,
            label: 'Start Recurrence Date',
            onDateChanged: null,
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'absolute_date_widget');
    });
  });
}
