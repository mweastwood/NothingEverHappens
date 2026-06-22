import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('MissedOccurrencePolicySelector Widget Tests', () {
    testWidgets('renders dropdown with selected policy', (tester) async {
      const policy = MissedOccurrencePolicy.stack();

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: MissedOccurrencePolicySelector(
              policy: policy,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Missed Occurrence Policy'), findsOneWidget);
      expect(find.text('Stack'), findsWidgets); // Both in dropdown and preview
      expect(
        find.text(
          'Visual Simulation (Assume Mon/Tue were missed; Today is Wed)',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows custom duration inputs when policy is autoDismiss and custom',
      (tester) async {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 3),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: MissedOccurrencePolicySelector(
                policy: policy,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Dismiss After'), findsOneWidget);
        expect(find.text('Custom Duration...'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
        expect(find.text('Hour(s)'), findsOneWidget);
      },
    );

    testGoldens('MissedOccurrencePolicySelector renders correctly', (
      tester,
    ) async {
      const preferOlderPolicy = MissedOccurrencePolicy.preferOlder();
      const preferNewerPolicy = MissedOccurrencePolicy.preferNewer();
      const autoDismiss24h = MissedOccurrencePolicy.autoDismiss(
        gracePeriod: Duration(days: 1),
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Prefer Older',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: preferOlderPolicy,
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Prefer Newer',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: preferNewerPolicy,
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Auto-Dismiss (24 Hours)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: autoDismiss24h,
                onChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 1400),
      );
      await screenMatchesGolden(tester, 'missed_occurrence_policy_selector');
    });
  });
}
