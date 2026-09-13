import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/family_member_tasks_sheet.dart';
import '../test_helper.dart';

void main() {
  group('FamilyMemberTasksSheet', () {
    final day = CivilDay(year: 2026, month: 7, day: 1);
    const dummyStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
    const dummyDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);
    const primaryColor = Color(0xFF1976D2);

    final completedTask1 = TaskInstance(
      id: 't-1',
      scheduleId: 's-1',
      ruleId: 'r-1',
      title: 'Cook Dinner',
      description: 'Prepare dinner for family',
      scheduledDate: day,
      startRelativeTime: dummyStart,
      dueRelativeTime: dummyDue,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 1, 14, 30),
    );

    final completedTask2 = TaskInstance(
      id: 't-2',
      scheduleId: 's-2',
      ruleId: 'r-2',
      title: 'Water Plants',
      description: '',
      scheduledDate: day,
      startRelativeTime: dummyStart,
      dueRelativeTime: dummyDue,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 1, 16, 45),
    );

    final overdueTask = TaskInstance(
      id: 't-overdue',
      scheduleId: 's-3',
      ruleId: 'r-3',
      title: 'Take Medication',
      description: '',
      scheduledDate: day,
      startRelativeTime: dummyStart,
      dueRelativeTime: dummyDue,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 1, 20, 0), // 3 hours overdue
    );

    final severeOverdueTask = TaskInstance(
      id: 't-severe',
      scheduleId: 's-4',
      ruleId: 'r-4',
      title: 'Submit Expense Report',
      description: '',
      scheduledDate: day,
      startRelativeTime: dummyStart,
      dueRelativeTime: dummyDue,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 7, 3, 10, 0), // 41 hours overdue
    );

    final scheduleMap = <String, TaskSchedule>{
      's-1': TaskSchedule(
        id: 's-1',
        title: 'Cook Dinner',
        description: '',
        estimatedDuration: const Duration(hours: 1, minutes: 30),
        schedules: [],
      ),
      's-2': TaskSchedule(
        id: 's-2',
        title: 'Water Plants',
        description: '',
        estimatedDuration: const Duration(minutes: 45),
        schedules: [],
      ),
    };

    final parentMember = FamilyMemberStats(
      userId: 'u-1',
      displayName: 'Helen Parr',
      email: 'helen@example.com',
      role: FamilyRole.parent,
      completedCount: 2,
      completedHours: 2.25,
      skippedCount: 0,
      missedCount: 0,
      contributionPercentage: 0.75,
      completedTasks: [completedTask1, completedTask2],
    );

    final nonParentMember = FamilyMemberStats(
      userId: 'u-2',
      displayName: 'Dash Parr',
      email: 'dash@example.com',
      role: FamilyRole.nonParent,
      completedCount: 0,
      completedHours: 0.0,
      skippedCount: 0,
      missedCount: 0,
      contributionPercentage: 0.0,
      completedTasks: [],
    );

    testWidgets('Header: renders displayName, avatar initials, and color', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: parentMember,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );

      // Display name
      expect(find.text('Helen Parr'), findsOneWidget);

      // Avatar initials
      expect(find.text('HP'), findsOneWidget);

      // Date range string
      expect(find.text('Jul 1 – Jul 7'), findsOneWidget);

      // Avatar text has designated color
      final textWidget = tester.widget<Text>(find.text('HP'));
      expect(textWidget.style?.color, primaryColor);
    });

    testWidgets('Header: displays Parent badge only for parent role', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      // 1. Parent member
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: parentMember,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );
      expect(find.text('Parent'), findsOneWidget);

      // 2. Non-parent member
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: nonParentMember,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );
      expect(find.text('Parent'), findsNothing);
    });

    testWidgets(
      'Metric chips: renders completed count, hours, and percentage',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
        addTearDown(AppClock.reset);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: FamilyMemberTasksSheet(
                member: parentMember,
                color: primaryColor,
                dateRangeStr: 'Jul 1 – Jul 7',
              ),
            ),
          ),
        );

        // Completed count chip
        expect(find.text('2 completed'), findsOneWidget);
        // Completed hours chip (2.25h -> 2h 15m)
        expect(find.text('2h 15m'), findsOneWidget);
        // Contribution percentage chip (75%)
        expect(find.text('75% of total'), findsOneWidget);
      },
    );

    testWidgets('Task list: sorts tasks by recency (most recent first)', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      final memberWithTasks = FamilyMemberStats(
        userId: 'u-1',
        displayName: 'Helen Parr',
        email: 'helen@example.com',
        role: FamilyRole.parent,
        completedCount: 2,
        completedHours: 2.25,
        skippedCount: 0,
        missedCount: 0,
        contributionPercentage: 0.75,
        // completedTask1 is 14:30, completedTask2 is 16:45
        completedTasks: [completedTask1, completedTask2],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: memberWithTasks,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );

      // Water Plants (16:45) should appear before Cook Dinner (14:30)
      final waterPlantsY = tester.getTopLeft(find.text('Water Plants')).dy;
      final cookDinnerY = tester.getTopLeft(find.text('Cook Dinner')).dy;
      expect(waterPlantsY < cookDinnerY, isTrue);
    });

    testWidgets('Task list: renders formatted time and estimated duration', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: parentMember,
              color: primaryColor,
              scheduleMap: scheduleMap,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );

      // Cook Dinner: 14:30, schedule estimatedDuration 1h 30m
      expect(find.text('Jul 1, 2:30 PM · 1h 30m'), findsOneWidget);
      // Water Plants: 16:45, schedule estimatedDuration 45m
      expect(find.text('Jul 1, 4:45 PM · 45m'), findsOneWidget);
    });

    testWidgets(
      'Task list: renders overdue and seriously overdue status badges',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
        addTearDown(AppClock.reset);

        final memberWithOverdue = FamilyMemberStats(
          userId: 'u-1',
          displayName: 'Helen Parr',
          email: 'helen@example.com',
          role: FamilyRole.parent,
          completedCount: 3,
          completedHours: 3.0,
          skippedCount: 0,
          missedCount: 0,
          contributionPercentage: 1.0,
          completedTasks: [completedTask1, overdueTask, severeOverdueTask],
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: FamilyMemberTasksSheet(
                member: memberWithOverdue,
                color: primaryColor,
                dateRangeStr: 'Jul 1 – Jul 7',
              ),
            ),
          ),
        );

        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Seriously Overdue'), findsOneWidget);
      },
    );

    testWidgets('Task list: renders untitled task fallback for empty titles', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      final untitledTask = TaskInstance(
        id: 't-untitled',
        scheduleId: 's-none',
        ruleId: 'r-none',
        title: '',
        description: '',
        scheduledDate: day,
        startRelativeTime: dummyStart,
        dueRelativeTime: dummyDue,
        status: TaskStatus.completed,
        completedAt: DateTime(2026, 7, 1, 10, 0),
      );

      final memberWithUntitled = FamilyMemberStats(
        userId: 'u-1',
        displayName: 'Helen Parr',
        email: 'helen@example.com',
        role: FamilyRole.parent,
        completedCount: 1,
        completedHours: 1.0,
        skippedCount: 0,
        missedCount: 0,
        contributionPercentage: 1.0,
        completedTasks: [untitledTask],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: memberWithUntitled,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );

      expect(find.text('Untitled Task'), findsOneWidget);
    });

    testWidgets('Empty state: displays icon and message when no tasks', (
      tester,
    ) async {
      AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
      addTearDown(AppClock.reset);

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FamilyMemberTasksSheet(
              member: nonParentMember,
              color: primaryColor,
              dateRangeStr: 'Jul 1 – Jul 7',
            ),
          ),
        ),
      );

      expect(
        find.text('No contributions recorded in this period'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets(
      'Interaction: FamilyMemberTasksSheet.show and close button pop',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 7, 7, 12, 0));
        addTearDown(AppClock.reset);

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => FamilyMemberTasksSheet.show(
                    context,
                    member: parentMember,
                    color: primaryColor,
                    scheduleMap: scheduleMap,
                    dateRangeStr: 'Jul 1 – Jul 7',
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('family_member_contributions_sheet')),
          findsOneWidget,
        );
        expect(find.text('Helen Parr'), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('family_member_contributions_sheet')),
          findsNothing,
        );
      },
    );

    test('typedef backwards compatibility', () {
      expect(FamilyMemberContributionsSheet, equals(FamilyMemberTasksSheet));
    });

    test('getInitials helper unit tests', () {
      expect(getInitials('Helen Parr'), 'HP');
      expect(getInitials('Dash'), 'D');
      expect(getInitials(''), '?');
      expect(getInitials('  Bob   Parr  '), 'BP');
    });
  });
}
