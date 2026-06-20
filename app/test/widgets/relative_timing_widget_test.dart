import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/relative_timing_widget.dart';
import '../test_helper.dart';

class _RelativeTimingTestWrapper extends StatefulWidget {
  final RelativeTime initialStart;
  final RelativeTime initialDue;
  final RelativeTime? initialNotification;
  final void Function(
    RelativeTime start,
    RelativeTime due,
    RelativeTime? notification,
  )
  onChanged;

  const _RelativeTimingTestWrapper({
    required this.initialStart,
    required this.initialDue,
    required this.initialNotification,
    required this.onChanged,
  });

  @override
  State<_RelativeTimingTestWrapper> createState() =>
      _RelativeTimingTestWrapperState();
}

class _RelativeTimingTestWrapperState
    extends State<_RelativeTimingTestWrapper> {
  late RelativeTime start;
  late RelativeTime due;
  RelativeTime? notification;

  @override
  void initState() {
    super.initState();
    start = widget.initialStart;
    due = widget.initialDue;
    notification = widget.initialNotification;
  }

  @override
  Widget build(BuildContext context) {
    return RelativeTimingWidget(
      startRelativeTime: start,
      dueRelativeTime: due,
      notificationRelativeTime: notification,
      onStartChanged: (val) {
        setState(() => start = val);
        widget.onChanged(val, due, notification);
      },
      onDueChanged: (val) {
        setState(() => due = val);
        widget.onChanged(start, val, notification);
      },
      onNotificationChanged: (val) {
        setState(() => notification = val);
        widget.onChanged(start, due, val);
      },
    );
  }
}

void main() {
  group('RelativeTimingWidget Widget Tests', () {
    testWidgets('renders initial values correctly', (tester) async {
      const initialStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const initialDue = RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 17, minute: 0),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _RelativeTimingTestWrapper(
                initialStart: initialStart,
                initialDue: initialDue,
                initialNotification: null,
                onChanged: (_, _, _) {},
              ),
            ),
          ),
        ),
      );

      // Verify labels and values
      expect(find.text('Start window'), findsOneWidget);
      expect(find.text('Day of'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);

      expect(find.text('Due window'), findsOneWidget);
      expect(find.text('1 day after'), findsOneWidget);
      expect(find.text('5:00 PM'), findsOneWidget);

      expect(find.text('Enable notification reminder'), findsOneWidget);
      expect(find.text('Notification window'), findsNothing);
    });

    testWidgets('triggers time picker when tapping time buttons', (
      tester,
    ) async {
      const initialStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const initialDue = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _RelativeTimingTestWrapper(
                initialStart: initialStart,
                initialDue: initialDue,
                initialNotification: null,
                onChanged: (_, _, _) {},
              ),
            ),
          ),
        ),
      );

      // Tap on start window time button
      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();

      // Check that time picker dialog is displayed
      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets('allows changing dropdown selection', (tester) async {
      const initialStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const initialDue = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );

      RelativeTime? updatedStart;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _RelativeTimingTestWrapper(
                initialStart: initialStart,
                initialDue: initialDue,
                initialNotification: null,
                onChanged: (s, d, n) {
                  updatedStart = s;
                },
              ),
            ),
          ),
        ),
      );

      // Tap calendar icon for Start Window
      final calendars = find.byIcon(Icons.calendar_today);
      await tester.tap(calendars.first);
      await tester.pumpAndSettle();

      // Tap "1 day after"
      await tester.tap(find.text('1 day after').last);
      await tester.pumpAndSettle();

      // Tap OK to commit
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(updatedStart, isNotNull);
      expect(updatedStart!.dayOffset, 1);
    });

    testWidgets('shows custom offset input when Custom is selected', (
      tester,
    ) async {
      const initialStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const initialDue = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );

      RelativeTime? updatedStart;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _RelativeTimingTestWrapper(
                initialStart: initialStart,
                initialDue: initialDue,
                initialNotification: null,
                onChanged: (s, d, n) {
                  updatedStart = s;
                },
              ),
            ),
          ),
        ),
      );

      // Verify custom textfield is not yet visible (since no dialog is open)
      expect(find.byType(TextField), findsNothing);

      // Tap calendar icon for Start Window
      final calendars = find.byIcon(Icons.calendar_today);
      await tester.tap(calendars.first);
      await tester.pumpAndSettle();

      // Tap "Custom"
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      // Verify custom input is now visible (in dialog)
      expect(find.byType(TextField), findsOneWidget);

      // Enter "42" days
      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(updatedStart, isNotNull);
      expect(updatedStart!.dayOffset, 42);
    });

    testWidgets('enabling notifications displays notification timing', (
      tester,
    ) async {
      const initialStart = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
      const initialDue = RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      );

      RelativeTime? updatedNotification;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: _RelativeTimingTestWrapper(
                initialStart: initialStart,
                initialDue: initialDue,
                initialNotification: null,
                onChanged: (s, d, n) {
                  updatedNotification = n;
                },
              ),
            ),
          ),
        ),
      );

      // Toggle notification reminder
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Notification window controls should be visible
      expect(find.text('Notification window'), findsOneWidget);
      expect(updatedNotification, isNotNull);
      expect(updatedNotification!.dayOffset, 0);
      expect(updatedNotification!.time, const TimeOfDay(hour: 9, minute: 0));
    });

    testGoldens('RelativeTimingWidget renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Standard timing options',
          Material(
            child: RelativeTimingWidget(
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 1,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              notificationRelativeTime: null,
              onStartChanged: (_) {},
              onDueChanged: (_) {},
              onNotificationChanged: (_) {},
            ),
          ),
        )
        ..addScenario(
          'Notification timing enabled',
          Material(
            child: RelativeTimingWidget(
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              notificationRelativeTime: const RelativeTime(
                dayOffset: -1,
                time: TimeOfDay(hour: 8, minute: 30),
              ),
              onStartChanged: (_) {},
              onDueChanged: (_) {},
              onNotificationChanged: (_) {},
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 1000),
      );

      await screenMatchesGolden(tester, 'relative_timing_widget_golden');
    });
  });
}
