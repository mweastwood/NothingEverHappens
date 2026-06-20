import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/widgets/completion_relative_config_widget.dart';
import '../test_helper.dart';

void main() {
  group('CompletionRelativeConfigWidget Widget Tests', () {
    testWidgets('renders initial interval and target start time', (
      tester,
    ) async {
      const policy = CompletionRelativePolicy(
        interval: Duration(days: 3),
        targetTime: TimeOfDay(hour: 10, minute: 30),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: CompletionRelativeConfigWidget(
              policy: policy,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Repeat Interval'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
      expect(find.text('Day(s)'), findsOneWidget);
      expect(find.text('Target Start Time'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);
    });

    testWidgets('triggers onChanged when interval number is changed', (
      tester,
    ) async {
      const policy = CompletionRelativePolicy(
        interval: Duration(days: 3),
        targetTime: TimeOfDay(hour: 10, minute: 30),
      );
      CompletionRelativePolicy? changedPolicy;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: CompletionRelativeConfigWidget(
              policy: policy,
              onChanged: (p) {
                changedPolicy = p;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(changedPolicy?.interval, const Duration(days: 5));
    });

    testWidgets('triggers onChanged when unit is changed', (tester) async {
      const policy = CompletionRelativePolicy(
        interval: Duration(days: 3),
        targetTime: TimeOfDay(hour: 10, minute: 30),
      );
      CompletionRelativePolicy? changedPolicy;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: CompletionRelativeConfigWidget(
              policy: policy,
              onChanged: (p) {
                changedPolicy = p;
              },
            ),
          ),
        ),
      );

      // Open Dropdown
      await tester.tap(find.text('Day(s)'));
      await tester.pumpAndSettle();

      // Select 'Week(s)'
      await tester.tap(find.text('Week(s)').last);
      await tester.pumpAndSettle();

      expect(changedPolicy?.interval, const Duration(days: 21)); // 3 weeks
    });

    testGoldens('CompletionRelativeConfigWidget renders correctly', (
      tester,
    ) async {
      const policy = CompletionRelativePolicy(
        interval: Duration(days: 3),
        targetTime: TimeOfDay(hour: 10, minute: 30),
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Standard Config',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CompletionRelativeConfigWidget(
                policy: policy,
                onChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 300),
      );
      await screenMatchesGolden(tester, 'completion_relative_config_widget');
    });
  });
}
