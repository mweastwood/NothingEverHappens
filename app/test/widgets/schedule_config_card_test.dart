import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_schedule_rule.dart';
import 'package:nothing_ever_happens/widgets/schedule_config_card.dart';
import '../test_helper.dart';

class _ScheduleConfigTestWrapper extends StatefulWidget {
  final TaskScheduleRule initialSchedule;
  final ValueChanged<TaskScheduleRule> onChanged;
  final VoidCallback? onDelete;

  const _ScheduleConfigTestWrapper({
    required this.initialSchedule,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_ScheduleConfigTestWrapper> createState() =>
      _ScheduleConfigTestWrapperState();
}

class _ScheduleConfigTestWrapperState
    extends State<_ScheduleConfigTestWrapper> {
  late TaskScheduleRule schedule;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    schedule = widget.initialSchedule;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          ScheduleConfigCard(
            schedule: schedule,
            onChanged: (val) {
              setState(() => schedule = val);
              widget.onChanged(val);
            },
            isExpanded: true,
            onExpansionChanged: (_) {},
            onDelete: widget.onDelete,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('validate_button'),
            onPressed: () {
              formKey.currentState?.validate();
            },
            child: const Text('Validate Form'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('ScheduleConfigCard Widget Tests', () {
    testWidgets('renders OneOffSchedule and handles delete and switch', (
      tester,
    ) async {
      bool deleteCalled = false;
      TaskScheduleRule? updatedSchedule;

      final schedule = OneOffSchedule(
        id: 'R-mock',
        scheduleId: 'S-mock',
        date: const CivilDay(year: 2026, month: 6, day: 15),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _ScheduleConfigTestWrapper(
                initialSchedule: schedule,
                onDelete: () => deleteCalled = true,
                onChanged: (s) => updatedSchedule = s,
              ),
            ),
          ),
        ),
      );

      // Verify date text
      expect(find.text('2026-06-15'), findsOneWidget);

      // Tap delete button
      final deleteBtn = find.byTooltip('Delete Schedule');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      expect(deleteCalled, isTrue);

      // Tap SegmentedButton to switch recurrence to Repeating (which defaults to Daily)
      await tester.tap(find.text('Repeating'));
      await tester.pumpAndSettle();

      expect(updatedSchedule, isA<DailySchedule>());
    });

    testWidgets('validates DailySchedule interval input', (tester) async {
      TaskScheduleRule? updatedSchedule;
      final schedule = DailySchedule(
        id: 'R-mock',
        scheduleId: 'S-mock',
        startDate: const CivilDay(year: 2026, month: 6, day: 15),
        interval: 2,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _ScheduleConfigTestWrapper(
                initialSchedule: schedule,
                onChanged: (s) => updatedSchedule = s,
              ),
            ),
          ),
        ),
      );

      // Verify interval field is displayed
      final intervalField = find.byKey(const Key('interval_text_field'));
      expect(intervalField, findsOneWidget);

      // Clear interval input
      await tester.enterText(intervalField, '');
      await tester.ensureVisible(find.byKey(const Key('validate_button')));
      await tester.tap(find.byKey(const Key('validate_button')));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('Interval is required'), findsOneWidget);

      // Set invalid interval (0)
      await tester.enterText(intervalField, '0');
      await tester.ensureVisible(find.byKey(const Key('validate_button')));
      await tester.tap(find.byKey(const Key('validate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a positive number'), findsOneWidget);

      // Set valid interval (3)
      await tester.enterText(intervalField, '3');
      await tester.pumpAndSettle();
      expect(updatedSchedule, isA<DailySchedule>());
      expect((updatedSchedule as DailySchedule).interval, 3);
    });

    testWidgets('WeeklySchedule weekday selection triggers onChanged', (
      tester,
    ) async {
      TaskScheduleRule? updatedSchedule;
      final schedule = WeeklySchedule(
        id: 'R-mock',
        scheduleId: 'S-mock',
        startDate: const CivilDay(year: 2026, month: 6, day: 15),
        interval: 1,
        daysOfWeek: {1}, // Monday
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _ScheduleConfigTestWrapper(
                initialSchedule: schedule,
                onChanged: (s) => updatedSchedule = s,
              ),
            ),
          ),
        ),
      );

      // Tap Wednesday checkbox/chip (daysOfWeek: 3)
      final wedChip = find.byKey(const Key('weekly_weekday_chip_3'));
      expect(wedChip, findsOneWidget);
      await tester.tap(wedChip);
      await tester.pumpAndSettle();

      expect(updatedSchedule, isA<WeeklySchedule>());
      expect((updatedSchedule as WeeklySchedule).daysOfWeek, contains(3));
    });

    testWidgets('MonthlySchedule validates day of month', (tester) async {
      TaskScheduleRule? updatedSchedule;
      final schedule = MonthlySchedule(
        id: 'R-mock',
        scheduleId: 'S-mock',
        startDate: const CivilDay(year: 2026, month: 6, day: 15),
        interval: 1,
        dayOfMonth: 15,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _ScheduleConfigTestWrapper(
                initialSchedule: schedule,
                onChanged: (s) => updatedSchedule = s,
              ),
            ),
          ),
        ),
      );

      final domField = find.byKey(const Key('day_text_field'));
      expect(domField, findsOneWidget);

      // Enter invalid day of month (29)
      await tester.enterText(domField, '29');
      await tester.ensureVisible(find.byKey(const Key('validate_button')));
      await tester.tap(find.byKey(const Key('validate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter 1-28'), findsOneWidget);

      // Enter valid day of month (-10)
      await tester.tap(find.text('From end of month'));
      await tester.enterText(domField, '10');
      await tester.pumpAndSettle();
      expect(updatedSchedule, isA<MonthlySchedule>());
      expect((updatedSchedule as MonthlySchedule).dayOfMonth, -10);
    });

    testWidgets('YearlySchedule validates day according to month', (
      tester,
    ) async {
      TaskScheduleRule? updatedSchedule;
      final schedule = YearlySchedule(
        id: 'R-mock',
        scheduleId: 'S-mock',
        startDate: const CivilDay(year: 2026, month: 6, day: 15),
        interval: 1,
        month: 2, // February
        day: 15,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _ScheduleConfigTestWrapper(
                initialSchedule: schedule,
                onChanged: (s) => updatedSchedule = s,
              ),
            ),
          ),
        ),
      );

      final dayField = find.byKey(const Key('yearly_day_field'));
      expect(dayField, findsOneWidget);

      // Enter invalid day (30 for February)
      await tester.enterText(dayField, '30');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('validate_button')));
      await tester.tap(find.byKey(const Key('validate_button')));
      await tester.pumpAndSettle();

      expect(find.text('1-29'), findsOneWidget);

      // Enter valid day (28)
      await tester.enterText(dayField, '28');
      await tester.pumpAndSettle();
      expect(updatedSchedule, isA<YearlySchedule>());
      expect((updatedSchedule as YearlySchedule).day, 28);
    });

    testGoldens('ScheduleConfigCard renders correctly for all schedule types', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'One-off Schedule Configuration',
          Material(
            child: ScheduleConfigCard(
              schedule: OneOffSchedule(
                id: 'R-mock',
                scheduleId: 'S-mock',
                date: const CivilDay(year: 2026, month: 6, day: 15),
              ),
              onChanged: (_) {},
              isExpanded: true,
              onExpansionChanged: (_) {},
            ),
          ),
        )
        ..addScenario(
          'Daily Schedule Configuration',
          Material(
            child: ScheduleConfigCard(
              schedule: DailySchedule(
                id: 'R-mock',
                scheduleId: 'S-mock',
                startDate: const CivilDay(year: 2026, month: 6, day: 15),
                interval: 2,
              ),
              onChanged: (_) {},
              isExpanded: true,
              onExpansionChanged: (_) {},
            ),
          ),
        )
        ..addScenario(
          'Weekly Schedule Configuration',
          Material(
            child: ScheduleConfigCard(
              schedule: WeeklySchedule(
                id: 'R-mock',
                scheduleId: 'S-mock',
                startDate: const CivilDay(year: 2026, month: 6, day: 15),
                interval: 1,
                daysOfWeek: {1, 3, 5},
              ),
              onChanged: (_) {},
              isExpanded: true,
              onExpansionChanged: (_) {},
            ),
          ),
        )
        ..addScenario(
          'Monthly Schedule Configuration',
          Material(
            child: ScheduleConfigCard(
              schedule: MonthlySchedule(
                id: 'R-mock',
                scheduleId: 'S-mock',
                startDate: const CivilDay(year: 2026, month: 6, day: 15),
                interval: 1,
                dayOfMonth: 15,
              ),
              onChanged: (_) {},
              isExpanded: true,
              onExpansionChanged: (_) {},
            ),
          ),
        )
        ..addScenario(
          'Yearly Schedule Configuration',
          Material(
            child: ScheduleConfigCard(
              schedule: YearlySchedule(
                id: 'R-mock',
                scheduleId: 'S-mock',
                startDate: const CivilDay(year: 2026, month: 6, day: 15),
                interval: 1,
                month: 6,
                day: 15,
              ),
              onChanged: (_) {},
              isExpanded: true,
              onExpansionChanged: (_) {},
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 6000),
      );

      await screenMatchesGolden(tester, 'schedule_config_card_golden');
    });
  });
}
