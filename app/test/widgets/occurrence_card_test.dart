import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/l10n_extension.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/widgets/occurrence_card.dart';
import '../test_helper.dart';

void main() {
  group('occurrence_card formatters & l10n date lists', () {
    testWidgets('provides 12 localized month names and 7 weekday names', (
      tester,
    ) async {
      late List<String> months;
      late List<String> weekdays;
      late String formattedDay;
      late String formattedDateTime;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) {
              months = context.l10n.monthNames;
              weekdays = context.l10n.weekdayNames;
              formattedDay = formatLocalizedCivilDay(
                context,
                const CivilDay(year: 2026, month: 10, day: 26),
              );
              formattedDateTime = formatLocalizedDateTime(
                context,
                DateTime(2026, 10, 26, 14, 30),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(months, hasLength(12));
      expect(months.first, 'January');
      expect(months.last, 'December');
      expect(weekdays, hasLength(7));
      expect(weekdays.first, 'Monday');
      expect(weekdays.last, 'Sunday');
      expect(formattedDay, 'Monday, October 26, 2026');
      expect(formattedDateTime, 'Monday, October 26, 2026 2:30 PM');
    });
  });

  group('FutureOccurrenceCard & PastOccurrenceCard', () {
    const occurrence = CivilDay(year: 2026, month: 10, day: 27);
    const startRel = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
    const dueRel = RelativeTime(dayOffset: 0, hour: 17, minute: 0);

    testWidgets(
      'FutureOccurrenceCard renders from instance and fromRule with expected keys',
      (tester) async {
        final instance = TaskInstance(
          id: 'inst-1',
          scheduleId: 'sched-1',
          ruleId: 'rule-1',
          title: 'Task',
          description: '',
          scheduledDate: occurrence,
          startRelativeTime: startRel,
          dueRelativeTime: dueRel,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Column(
                children: [
                  FutureOccurrenceCard(instance: instance, index: 0),
                  const FutureOccurrenceCard.fromRule(
                    occurrence: occurrence,
                    startRelativeTime: startRel,
                    dueRelativeTime: dueRel,
                    index: 1,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('spawned_occurrence_card_0')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('occurrence_card_1')), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Tuesday, October 27, 2026'), findsNWidgets(2));
      },
    );

    testWidgets(
      'PastOccurrenceCard renders completed, skipped, active, and overdue states',
      (tester) async {
        final now = DateTime(2026, 10, 27, 12, 0);
        final completed = TaskInstance(
          id: 'inst-c',
          scheduleId: 'sched-1',
          ruleId: 'rule-1',
          title: 'Task',
          description: '',
          scheduledDate: occurrence,
          startRelativeTime: startRel,
          dueRelativeTime: dueRel,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 10, 27, 10, 15),
        );
        final active = TaskInstance(
          id: 'inst-a',
          scheduleId: 'sched-1',
          ruleId: 'rule-1',
          title: 'Task',
          description: '',
          scheduledDate: occurrence,
          startRelativeTime: startRel,
          dueRelativeTime: dueRel,
          status: TaskStatus.pending,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Column(
                children: [
                  PastOccurrenceCard(instance: completed, index: 0, now: now),
                  PastOccurrenceCard(
                    instance: active,
                    index: 0,
                    now: now,
                    keyPrefix: 'current',
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('past_occurrence_card_0')), findsOneWidget);
        expect(
          find.byKey(const Key('current_occurrence_card_0')),
          findsOneWidget,
        );
        expect(find.textContaining('Completed:'), findsOneWidget);
        expect(find.textContaining('Active (Due:'), findsOneWidget);
      },
    );
  });
}
