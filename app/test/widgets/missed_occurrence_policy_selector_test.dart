import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/missed_policy.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('MissedOccurrencePolicySelector Widget Tests', () {
    testWidgets('renders keepAround state with sub-options', (tester) async {
      const policy = MissedOccurrencePolicy.keepAround(
        legacyPolicy: MissedPolicy.rollover,
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

      expect(find.text('Keep Around'), findsOneWidget);
      expect(find.text('Auto-Dismiss'), findsOneWidget);
      expect(find.text('Overdue Treatment'), findsOneWidget);
      expect(
        find.text('Rollover (single card, original due ref)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'triggers onChanged when toggling to autoDismiss and picking preset',
      (tester) async {
        const policy = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.rollover,
        );
        MissedOccurrencePolicy? changedPolicy;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: MissedOccurrencePolicySelector(
                policy: policy,
                onChanged: (p) {
                  changedPolicy = p;
                },
              ),
            ),
          ),
        );

        // Tap Auto-Dismiss
        await tester.tap(find.text('Auto-Dismiss'));
        await tester.pumpAndSettle();

        expect(changedPolicy?.type, MissedOccurrenceType.autoDismiss);
      },
    );

    testWidgets('shows custom duration inputs when preset is custom', (
      tester,
    ) async {
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

      expect(find.text('Custom Duration...'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
      expect(find.text('Hour(s)'), findsOneWidget);
    });

    testGoldens('MissedOccurrencePolicySelector renders correctly', (
      tester,
    ) async {
      const keepAroundPolicy = MissedOccurrencePolicy.keepAround(
        legacyPolicy: MissedPolicy.rollover,
      );
      const autoDismiss6h = MissedOccurrencePolicy.autoDismiss(
        gracePeriod: Duration(hours: 6),
      );
      const autoDismissCustom = MissedOccurrencePolicy.autoDismiss(
        gracePeriod: Duration(minutes: 15),
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Keep Around (Rollover)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: keepAroundPolicy,
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Auto-Dismiss (6 Hours)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: autoDismiss6h,
                onChanged: (_) {},
              ),
            ),
          ),
        )
        ..addScenario(
          'Auto-Dismiss (Custom Duration)',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MissedOccurrencePolicySelector(
                policy: autoDismissCustom,
                onChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 800),
      );
      await screenMatchesGolden(tester, 'missed_occurrence_policy_selector');
    });
  });
}
