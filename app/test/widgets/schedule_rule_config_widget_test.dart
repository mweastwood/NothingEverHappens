import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/task_schedule_rule.dart';
import 'package:nothing_ever_happens/widgets/schedule_rule_config_widget.dart';
import 'package:nothing_ever_happens/widgets/daily_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/weekly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/monthly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/yearly_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/one_off_scheduling_widget.dart';
import 'package:nothing_ever_happens/widgets/hierarchical_recurrence_selector.dart';
import 'package:nothing_ever_happens/widgets/notification_list_widget.dart';
import 'package:nothing_ever_happens/widgets/missed_occurrence_policy_selector.dart';
import '../test_helper.dart';
import 'one_off_scheduling_widget_robot.dart';
import 'absolute_time_widget_robot.dart';

void main() {
  final testStartDate = CivilDay(year: 2026, month: 10, day: 26);
  const testStartRelative = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 9, minute: 0),
  );
  const testDueRelative = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 17, minute: 0),
  );

  DailySchedule createDefaultDailySchedule({
    int interval = 1,
    SchedulingPolicy policy = const FixedCalendarPolicy(),
  }) {
    return DailySchedule(
      id: 'daily_1',
      scheduleId: 'sched_1',
      startDate: testStartDate,
      interval: interval,
      startRelativeTime: testStartRelative,
      dueRelativeTime: testDueRelative,
      notificationRelativeTimes: const [],
      schedulingPolicy: policy,
      missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
    );
  }

  WeeklySchedule createDefaultWeeklySchedule({
    int interval = 1,
    Set<int> daysOfWeek = const {1, 3, 5},
    SchedulingPolicy policy = const FixedCalendarPolicy(),
  }) {
    return WeeklySchedule(
      id: 'weekly_1',
      scheduleId: 'sched_1',
      startDate: testStartDate,
      interval: interval,
      daysOfWeek: daysOfWeek,
      startRelativeTime: testStartRelative,
      dueRelativeTime: testDueRelative,
      notificationRelativeTimes: const [],
      schedulingPolicy: policy,
      missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
    );
  }

  MonthlySchedule createDefaultMonthlySchedule({
    int interval = 1,
    int? dayOfMonth = 15,
    int? dayOfWeek,
    int? occurrence,
    SchedulingPolicy policy = const FixedCalendarPolicy(),
  }) {
    return MonthlySchedule(
      id: 'monthly_1',
      scheduleId: 'sched_1',
      startDate: testStartDate,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      occurrence: occurrence,
      startRelativeTime: testStartRelative,
      dueRelativeTime: testDueRelative,
      notificationRelativeTimes: const [],
      schedulingPolicy: policy,
      missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
    );
  }

  YearlySchedule createDefaultYearlySchedule({
    int interval = 1,
    int month = 10,
    int day = 26,
    SchedulingPolicy policy = const FixedCalendarPolicy(),
  }) {
    return YearlySchedule(
      id: 'yearly_1',
      scheduleId: 'sched_1',
      startDate: testStartDate,
      interval: interval,
      month: month,
      day: day,
      startRelativeTime: testStartRelative,
      dueRelativeTime: testDueRelative,
      notificationRelativeTimes: const [],
      schedulingPolicy: policy,
      missedOccurrencePolicy: const MissedOccurrencePolicy.stack(),
    );
  }

  OneOffSchedule createDefaultOneOffSchedule({
    CivilDay? date,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
  }) {
    return OneOffSchedule(
      id: 'one_off_1',
      scheduleId: 'sched_1',
      date: date ?? testStartDate,
      startRelativeTime: startRelativeTime ?? testStartRelative,
      dueRelativeTime: dueRelativeTime ?? testDueRelative,
      notificationRelativeTimes: const [],
    );
  }

  group('ScheduleRuleConfigWidget - Child Builder Rendering', () {
    testWidgets('renders DailySchedulingWidget for DailySchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultDailySchedule(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HierarchicalRecurrenceSelector), findsOneWidget);
      expect(find.byType(DailySchedulingWidget), findsOneWidget);
      expect(find.byType(WeeklySchedulingWidget), findsNothing);
      expect(find.byType(MonthlySchedulingWidget), findsNothing);
      expect(find.byType(YearlySchedulingWidget), findsNothing);
      expect(find.byType(OneOffSchedulingWidget), findsNothing);
    });

    testWidgets('renders WeeklySchedulingWidget for WeeklySchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultWeeklySchedule(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeeklySchedulingWidget), findsOneWidget);
      expect(find.byType(DailySchedulingWidget), findsNothing);
    });

    testWidgets('renders MonthlySchedulingWidget for MonthlySchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultMonthlySchedule(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MonthlySchedulingWidget), findsOneWidget);
      expect(find.byType(DailySchedulingWidget), findsNothing);
    });

    testWidgets('renders YearlySchedulingWidget for YearlySchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultYearlySchedule(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(YearlySchedulingWidget), findsOneWidget);
      expect(find.byType(DailySchedulingWidget), findsNothing);
    });

    testWidgets('renders OneOffSchedulingWidget for OneOffSchedule', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultOneOffSchedule(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OneOffSchedulingWidget), findsOneWidget);
      expect(find.byType(DailySchedulingWidget), findsNothing);
    });
  });

  group('ScheduleRuleConfigWidget - Rule Type Switching', () {
    testWidgets('switching from Daily to OneOff dispatches OneOffSchedule', (
      tester,
    ) async {
      TaskScheduleRule? changedRule;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultDailySchedule(),
                onChanged: (rule) => changedRule = rule,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap One-off in the recurrence selector
      await tester.tap(find.text('One-off'));
      await tester.pumpAndSettle();

      expect(changedRule, isA<OneOffSchedule>());
    });

    testWidgets('switching from OneOff to Repeating dispatches DailySchedule', (
      tester,
    ) async {
      TaskScheduleRule? changedRule;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultOneOffSchedule(),
                onChanged: (rule) => changedRule = rule,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Repeating segment
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      expect(changedRule, isA<DailySchedule>());
    });

    testWidgets(
      'switching cadence chips updates rule to Weekly, Monthly, Yearly',
      (tester) async {
        TaskScheduleRule? changedRule;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultDailySchedule(),
                  onChanged: (rule) => changedRule = rule,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Weekly chip
        await tester.tap(find.byKey(const Key('recurrence_chip_weekly')));
        await tester.pumpAndSettle();
        expect(changedRule, isA<WeeklySchedule>());

        // Re-render with Weekly schedule to test next chip
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultWeeklySchedule(),
                  onChanged: (rule) => changedRule = rule,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Monthly chip
        await tester.tap(find.byKey(const Key('recurrence_chip_monthly')));
        await tester.pumpAndSettle();
        expect(changedRule, isA<MonthlySchedule>());

        // Re-render with Monthly schedule to test next chip
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultMonthlySchedule(),
                  onChanged: (rule) => changedRule = rule,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Yearly chip
        await tester.tap(find.byKey(const Key('recurrence_chip_yearly')));
        await tester.pumpAndSettle();
        expect(changedRule, isA<YearlySchedule>());
      },
    );

    testWidgets(
      'switching specialization to completion relative dispatches updated rule',
      (tester) async {
        TaskScheduleRule? changedRule;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultDailySchedule(),
                  onChanged: (rule) => changedRule = rule,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 'Based on when last completed'
        await tester.tap(find.text('Based on when last completed'));
        await tester.pumpAndSettle();

        expect(changedRule, isA<DailySchedule>());
        expect(
          (changedRule as DailySchedule).schedulingPolicy,
          isA<CompletionRelativePolicy>(),
        );
      },
    );
  });

  group('ScheduleRuleConfigWidget - Interval Validation', () {
    testWidgets(
      'emits invalidIntervalError for non-positive or non-digit interval text',
      (tester) async {
        String? reportedError;
        late AppLocalizations l10n;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: SingleChildScrollView(
                    child: ScheduleRuleConfigWidget(
                      schedule: createDefaultDailySchedule(interval: 1),
                      onChanged: (_) {},
                      onValidationError: (err) => reportedError = err,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial validation with interval=1 should have no error
        expect(reportedError, isNull);

        final intervalField = find.byKey(const Key('interval_text_field'));
        expect(intervalField, findsOneWidget);

        // Enter '0'
        await tester.enterText(intervalField, '0');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.invalidIntervalError);

        // Enter non-digit text
        await tester.enterText(intervalField, 'abc');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.invalidIntervalError);

        // Enter empty text
        await tester.enterText(intervalField, '');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.invalidIntervalError);

        // Enter valid number '5'
        await tester.enterText(intervalField, '5');
        await tester.pumpAndSettle();
        expect(reportedError, isNull);
      },
    );

    testWidgets('validates interval on WeeklySchedule', (tester) async {
      String? reportedError;
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: SingleChildScrollView(
                  child: ScheduleRuleConfigWidget(
                    schedule: createDefaultWeeklySchedule(interval: 2),
                    onChanged: (_) {},
                    onValidationError: (err) => reportedError = err,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reportedError, isNull);

      final intervalField = find.byKey(const Key('interval_text_field'));
      await tester.enterText(intervalField, '0');
      await tester.pumpAndSettle();
      expect(reportedError, l10n.invalidIntervalError);

      await tester.enterText(intervalField, '3');
      await tester.pumpAndSettle();
      expect(reportedError, isNull);
    });
  });

  group('ScheduleRuleConfigWidget - Monthly Day-of-Month Validation', () {
    testWidgets(
      'emits dayOfMonthValidationError when day > 28, 0, or invalid',
      (tester) async {
        String? reportedError;
        late AppLocalizations l10n;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: SingleChildScrollView(
                    child: ScheduleRuleConfigWidget(
                      schedule: createDefaultMonthlySchedule(dayOfMonth: 15),
                      onChanged: (_) {},
                      onValidationError: (err) => reportedError = err,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(reportedError, isNull);

        final dayField = find.byKey(const Key('day_text_field'));
        expect(dayField, findsOneWidget);

        // Enter 29 (exceeds 28)
        await tester.enterText(dayField, '29');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.dayOfMonthValidationError);

        // Enter 31
        await tester.enterText(dayField, '31');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.dayOfMonthValidationError);

        // Enter 0
        await tester.enterText(dayField, '0');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.dayOfMonthValidationError);

        // Enter invalid text
        await tester.enterText(dayField, 'xyz');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.dayOfMonthValidationError);

        // Enter valid day 28
        await tester.enterText(dayField, '28');
        await tester.pumpAndSettle();
        expect(reportedError, isNull);
      },
    );
  });

  group('ScheduleRuleConfigWidget - Yearly Month/Day Validation', () {
    testWidgets('validates day bounds for February (max 29)', (tester) async {
      String? reportedError;
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: SingleChildScrollView(
                  child: ScheduleRuleConfigWidget(
                    schedule: createDefaultYearlySchedule(month: 2, day: 15),
                    onChanged: (_) {},
                    onValidationError: (err) => reportedError = err,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reportedError, isNull);

      final dayField = find.byKey(const Key('yearly_day_field'));
      expect(dayField, findsOneWidget);

      // Enter 30 (> 29 for February)
      await tester.enterText(dayField, '30');
      await tester.pumpAndSettle();
      expect(reportedError, l10n.dayMustBeBetweenError(29));

      // Enter 0
      await tester.enterText(dayField, '0');
      await tester.pumpAndSettle();
      expect(reportedError, l10n.dayMustBeBetweenError(29));

      // Enter valid 29
      await tester.enterText(dayField, '29');
      await tester.pumpAndSettle();
      expect(reportedError, isNull);
    });

    testWidgets(
      'validates day bounds for 30-day months like April (month: 4)',
      (tester) async {
        String? reportedError;
        late AppLocalizations l10n;

        await tester.pumpWidget(
          buildTestableWidget(
            child: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: SingleChildScrollView(
                    child: ScheduleRuleConfigWidget(
                      schedule: createDefaultYearlySchedule(month: 4, day: 20),
                      onChanged: (_) {},
                      onValidationError: (err) => reportedError = err,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(reportedError, isNull);

        final dayField = find.byKey(const Key('yearly_day_field'));

        // Enter 31 (> 30 for April)
        await tester.enterText(dayField, '31');
        await tester.pumpAndSettle();
        expect(reportedError, l10n.dayMustBeBetweenError(30));

        // Enter valid 30
        await tester.enterText(dayField, '30');
        await tester.pumpAndSettle();
        expect(reportedError, isNull);
      },
    );

    testWidgets('validates day bounds for 31-day months (month: 10)', (
      tester,
    ) async {
      String? reportedError;
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: SingleChildScrollView(
                  child: ScheduleRuleConfigWidget(
                    schedule: createDefaultYearlySchedule(month: 10, day: 26),
                    onChanged: (_) {},
                    onValidationError: (err) => reportedError = err,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reportedError, isNull);

      final dayField = find.byKey(const Key('yearly_day_field'));

      // Enter 32 (> 31)
      await tester.enterText(dayField, '32');
      await tester.pumpAndSettle();
      expect(reportedError, l10n.dayMustBeBetweenError(31));

      // Enter valid 31
      await tester.enterText(dayField, '31');
      await tester.pumpAndSettle();
      expect(reportedError, isNull);
    });
  });

  group('ScheduleRuleConfigWidget - One-Off Controller Synchronization', () {
    testWidgets('changing one-off due date/time updates underlying schedule', (
      tester,
    ) async {
      TaskScheduleRule? changedRule;
      final schedule = createDefaultOneOffSchedule(
        date: CivilDay(year: 2026, month: 10, day: 26),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 12, minute: 0),
        ),
      );

      final oneOffRobot = OneOffSchedulingWidgetRobot(tester);
      final absoluteRobot = AbsoluteTimeWidgetRobot(tester);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: schedule,
                onChanged: (r) => changedRule = r,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify OneOffSchedulingWidget is present
      expect(find.byType(OneOffSchedulingWidget), findsOneWidget);

      // Open due time picker and select 10:00 PM
      await oneOffRobot.openDueTimePicker();
      await absoluteRobot.pickTime(10, 0, isAM: false);

      expect(changedRule, isA<OneOffSchedule>());
      final updatedOneOff = changedRule as OneOffSchedule;
      expect(updatedOneOff.dueRelativeTime.time.hour, 22);

      // Re-pump widget with updated OneOffSchedule (didUpdateWidget test)
      final updatedSchedule = createDefaultOneOffSchedule(
        date: CivilDay(year: 2026, month: 10, day: 28),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 15, minute: 30),
        ),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: updatedSchedule,
                onChanged: (r) => changedRule = r,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-10-28'), findsWidgets);
    });
  });

  group('ScheduleRuleConfigWidget - Notification & Missed Policy Toggles', () {
    testWidgets('shows NotificationListWidget when showNotification is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultDailySchedule(),
                onChanged: (_) {},
                showNotification: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationListWidget), findsOneWidget);
    });

    testWidgets('hides NotificationListWidget when showNotification is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultDailySchedule(),
                onChanged: (_) {},
                showNotification: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationListWidget), findsNothing);
    });

    testWidgets(
      'shows MissedOccurrencePolicySelector for fixed recurring rules',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultDailySchedule(),
                  onChanged: (_) {},
                  showMissedPolicy: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissedOccurrencePolicySelector), findsOneWidget);
      },
    );

    testWidgets(
      'hides MissedOccurrencePolicySelector when showMissedPolicy is false',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultDailySchedule(),
                  onChanged: (_) {},
                  showMissedPolicy: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets(
      'hides MissedOccurrencePolicySelector for OneOffSchedule even if showMissedPolicy is true',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultOneOffSchedule(),
                  onChanged: (_) {},
                  showMissedPolicy: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );

    testWidgets(
      'hides MissedOccurrencePolicySelector for CompletionRelativePolicy even if showMissedPolicy is true',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: createDefaultDailySchedule(
                    policy: CompletionRelativePolicy(
                      interval: const Duration(days: 2),
                      targetTime: const TimeOfDay(hour: 9, minute: 0),
                    ),
                  ),
                  onChanged: (_) {},
                  showMissedPolicy: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MissedOccurrencePolicySelector), findsNothing);
      },
    );
  });

  group('ScheduleRuleConfigWidget - Child Widget Callback Dispatches', () {
    testWidgets(
      'Daily child widget callbacks dispatch onChanged with updated rule',
      (tester) async {
        TaskScheduleRule? changedRule;
        final schedule = createDefaultDailySchedule();

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: schedule,
                  onChanged: (r) => changedRule = r,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dailyWidget = tester.widget<DailySchedulingWidget>(
          find.byType(DailySchedulingWidget),
        );

        // Verify onStartDateChanged
        final newStartDate = CivilDay(year: 2026, month: 11, day: 1);
        dailyWidget.onStartDateChanged(newStartDate);
        expect((changedRule as DailySchedule).startDate, newStartDate);

        // Verify onIntervalChanged
        dailyWidget.onIntervalChanged(3);
        expect((changedRule as DailySchedule).interval, 3);

        // Verify onStartRelativeTimeChanged
        const newStartRel = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 8, minute: 30),
        );
        dailyWidget.onStartRelativeTimeChanged(newStartRel);
        expect((changedRule as DailySchedule).startRelativeTime, newStartRel);

        // Verify onDueRelativeTimeChanged
        const newDueRel = RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 18, minute: 0),
        );
        dailyWidget.onDueRelativeTimeChanged(newDueRel);
        expect((changedRule as DailySchedule).dueRelativeTime, newDueRel);

        // Verify onMissedOccurrencePolicyChanged
        const newMissed = MissedOccurrencePolicy.preferNewer();
        dailyWidget.onMissedOccurrencePolicyChanged?.call(newMissed);
        expect(
          (changedRule as DailySchedule).missedOccurrencePolicy,
          newMissed,
        );
      },
    );

    testWidgets(
      'Weekly child widget callbacks dispatch onChanged with updated rule',
      (tester) async {
        TaskScheduleRule? changedRule;
        final schedule = createDefaultWeeklySchedule();

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: schedule,
                  onChanged: (r) => changedRule = r,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final weeklyWidget = tester.widget<WeeklySchedulingWidget>(
          find.byType(WeeklySchedulingWidget),
        );

        // Verify onWeekdaysChanged
        weeklyWidget.onWeekdaysChanged({2, 4});
        expect((changedRule as WeeklySchedule).daysOfWeek, {2, 4});

        // Verify onIntervalChanged
        weeklyWidget.onIntervalChanged(2);
        expect((changedRule as WeeklySchedule).interval, 2);
      },
    );

    testWidgets(
      'Monthly child widget callbacks dispatch onChanged with updated rule',
      (tester) async {
        TaskScheduleRule? changedRule;
        final schedule = createDefaultMonthlySchedule(dayOfMonth: 10);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: schedule,
                  onChanged: (r) => changedRule = r,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final monthlyWidget = tester.widget<MonthlySchedulingWidget>(
          find.byType(MonthlySchedulingWidget),
        );

        // Verify onDayOfMonthChanged
        monthlyWidget.onDayOfMonthChanged(20);
        expect((changedRule as MonthlySchedule).dayOfMonth, 20);

        // Verify onRuleTypeChanged to nthDayOfWeek
        monthlyWidget.onRuleTypeChanged('nthDayOfWeek');
        expect((changedRule as MonthlySchedule).dayOfWeek, isNotNull);
        expect((changedRule as MonthlySchedule).occurrence, 1);

        // Re-render with nthDayOfWeek MonthlySchedule to test occurrence and dayOfWeek callbacks
        final nthSchedule = createDefaultMonthlySchedule(
          dayOfMonth: null,
          dayOfWeek: 1,
          occurrence: 1,
        );
        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: nthSchedule,
                  onChanged: (r) => changedRule = r,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nthMonthlyWidget = tester.widget<MonthlySchedulingWidget>(
          find.byType(MonthlySchedulingWidget),
        );

        // Verify onOccurrenceChanged and onDayOfWeekChanged
        nthMonthlyWidget.onOccurrenceChanged(2);
        expect((changedRule as MonthlySchedule).occurrence, 2);

        nthMonthlyWidget.onDayOfWeekChanged(3);
        expect((changedRule as MonthlySchedule).dayOfWeek, 3);

        // Verify switching back to dayOfMonth
        nthMonthlyWidget.onRuleTypeChanged('dayOfMonth');
        expect((changedRule as MonthlySchedule).dayOfMonth, isNotNull);
      },
    );

    testWidgets(
      'Yearly child widget callbacks dispatch onChanged with updated rule',
      (tester) async {
        TaskScheduleRule? changedRule;
        final schedule = createDefaultYearlySchedule(month: 5, day: 10);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: schedule,
                  onChanged: (r) => changedRule = r,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final yearlyWidget = tester.widget<YearlySchedulingWidget>(
          find.byType(YearlySchedulingWidget),
        );

        // Verify onMonthChanged
        yearlyWidget.onMonthChanged(8);
        expect((changedRule as YearlySchedule).month, 8);

        // Verify onDayChanged
        yearlyWidget.onDayChanged(15);
        expect((changedRule as YearlySchedule).day, 15);

        // Verify onIntervalChanged
        yearlyWidget.onIntervalChanged(2);
        expect((changedRule as YearlySchedule).interval, 2);
      },
    );

    testWidgets(
      'NotificationListWidget and MissedOccurrencePolicySelector callbacks dispatch onChanged',
      (tester) async {
        TaskScheduleRule? changedRule;
        final schedule = createDefaultDailySchedule();

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ScheduleRuleConfigWidget(
                  schedule: schedule,
                  onChanged: (r) => changedRule = r,
                  showNotification: true,
                  showMissedPolicy: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final notifWidget = tester.widget<NotificationListWidget>(
          find.byType(NotificationListWidget),
        );
        const newNotifs = [
          RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 0)),
        ];
        notifWidget.onChanged(newNotifs);
        expect(changedRule!.notificationRelativeTimes, newNotifs);

        final missedSelector = tester.widget<MissedOccurrencePolicySelector>(
          find.byType(MissedOccurrencePolicySelector),
        );
        const newPolicy = MissedOccurrencePolicy.preferOlder();
        missedSelector.onChanged(newPolicy);
        expect(changedRule!.missedOccurrencePolicy, newPolicy);
      },
    );
  });

  group('ScheduleRuleConfigWidget - ReadOnly Mode', () {
    testWidgets('passes readOnly true to child components', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleRuleConfigWidget(
                schedule: createDefaultDailySchedule(),
                onChanged: (_) {},
                readOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = tester.widget<HierarchicalRecurrenceSelector>(
        find.byType(HierarchicalRecurrenceSelector),
      );
      expect(selector.readOnly, isTrue);

      final daily = tester.widget<DailySchedulingWidget>(
        find.byType(DailySchedulingWidget),
      );
      expect(daily.readOnly, isTrue);

      final notif = tester.widget<NotificationListWidget>(
        find.byType(NotificationListWidget),
      );
      expect(notif.readOnly, isTrue);

      final missed = tester.widget<MissedOccurrencePolicySelector>(
        find.byType(MissedOccurrencePolicySelector),
      );
      expect(missed.readOnly, isTrue);
    });
  });
}
