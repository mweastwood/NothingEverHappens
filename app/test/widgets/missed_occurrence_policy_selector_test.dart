import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/missed_policy.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';

void main() {
  group('MissedOccurrencePolicySelector', () {
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
  });
}
