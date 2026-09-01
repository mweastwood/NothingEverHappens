import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_section.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';

import '../test_helper.dart';

void main() {
  group('MissedOccurrencePolicySection Widget Tests', () {
    testWidgets('renders SizedBox.shrink when showMissedPolicy is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: MissedOccurrencePolicySection(
              showMissedPolicy: false,
              missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
              onMissedOccurrencePolicyChanged: (_) {},
              keyPrefix: 'test_prefix',
            ),
          ),
        ),
      );

      expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders SizedBox.shrink when missedOccurrencePolicy is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: MissedOccurrencePolicySection(
              showMissedPolicy: true,
              missedOccurrencePolicy: null,
              onMissedOccurrencePolicyChanged: (_) {},
              keyPrefix: 'test_prefix',
            ),
          ),
        ),
      );

      expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'renders SizedBox.shrink when onMissedOccurrencePolicyChanged is null',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(
              body: MissedOccurrencePolicySection(
                showMissedPolicy: true,
                missedOccurrencePolicy: MissedOccurrencePolicy.stack(),
                onMissedOccurrencePolicyChanged: null,
                keyPrefix: 'test_prefix',
              ),
            ),
          ),
        );

        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
        expect(find.byType(Divider), findsNothing);
      },
    );

    testWidgets(
      'renders Divider and MissedOccurrencePolicySelector when showMissedPolicy is true and policy/callback provided',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: MissedOccurrencePolicySection(
                  showMissedPolicy: true,
                  missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
                  onMissedOccurrencePolicyChanged: (_) {},
                  keyPrefix: 'test_prefix',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Divider), findsOneWidget);
        expect(
          find.byKey(const Key('test_prefix_missed_policy')),
          findsOneWidget,
        );
        expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
      },
    );

    testWidgets(
      'interacting with selector triggers onMissedOccurrencePolicyChanged callback',
      (tester) async {
        MissedOccurrencePolicy? updatedPolicy;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: MissedOccurrencePolicySection(
                  showMissedPolicy: true,
                  missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
                  onMissedOccurrencePolicyChanged: (policy) {
                    updatedPolicy = policy;
                  },
                  keyPrefix: 'test_prefix',
                ),
              ),
            ),
          ),
        );

        // Open policy selection dialog by tapping on the policy card
        await tester.tap(find.byKey(const Key('test_prefix_missed_policy')));
        await tester.pumpAndSettle();

        // Select 'Prefer Newer' option
        await tester.tap(find.text('Prefer Newer').last);
        await tester.pumpAndSettle();

        expect(updatedPolicy, isNotNull);
        expect(updatedPolicy?.policy, MissedPolicy.preferNewer);
      },
    );
  });
}
