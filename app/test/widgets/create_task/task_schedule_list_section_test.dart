import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/schedule_rules/one_off_schedule.dart';
import 'package:nothing_ever_happens/logic/schedule_rules/task_schedule_rule.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_schedule_list_section.dart';

void main() {
  Widget buildWidget({
    required List<TaskScheduleRule> schedules,
    int? expandedScheduleIndex,
    Function(int index, TaskScheduleRule newSchedule)? onScheduleChanged,
    Function(int index)? onScheduleDeleted,
    Function(int index, bool expanded)? onExpansionChanged,
    VoidCallback? onAddSchedule,
    bool readOnly = false,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskScheduleListSection(
            schedules: schedules,
            expandedScheduleIndex: expandedScheduleIndex,
            onScheduleChanged: onScheduleChanged,
            onScheduleDeleted: onScheduleDeleted,
            onExpansionChanged: onExpansionChanged,
            onAddSchedule: onAddSchedule,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  group('TaskScheduleListSection', () {
    final defaultSchedule = OneOffSchedule(
      id: 'rule-1',
      scheduleId: 'task-1',
      date: CivilDay(year: 2026, month: 3, day: 9),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
    );

    testWidgets('renders list of schedules and add schedule button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(schedules: [defaultSchedule], expandedScheduleIndex: 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(defaultSchedule.id)), findsOneWidget);
      expect(find.byKey(const Key('add_schedule_button')), findsOneWidget);
    });

    testWidgets('tapping add schedule button triggers onAddSchedule callback', (
      WidgetTester tester,
    ) async {
      bool addCalled = false;
      await tester.pumpWidget(
        buildWidget(
          schedules: [defaultSchedule],
          onAddSchedule: () => addCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_schedule_button')));
      await tester.pumpAndSettle();

      expect(addCalled, true);
    });
  });
}
