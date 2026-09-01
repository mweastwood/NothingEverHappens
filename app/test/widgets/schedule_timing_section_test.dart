import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/relative_time_widget.dart';
import 'package:nothing_ever_happens/widgets/schedule_timing_section.dart';
import '../test_helper.dart';

void main() {
  const initialStartTime = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 9, minute: 0),
  );

  const initialDueTime = RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 17, minute: 0),
  );

  Widget buildWidget({
    required ValueNotifier<RelativeTime> startController,
    required ValueNotifier<RelativeTime> dueController,
    String keyPrefix = 'test_schedule',
    Locale? locale,
    ThemeData? theme,
  }) {
    return buildTestableWidget(
      locale: locale,
      child: Theme(
        data: theme ?? ThemeData.light(useMaterial3: true),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleTimingSection(
              startController: startController,
              dueController: dueController,
              keyPrefix: keyPrefix,
            ),
          ),
        ),
      ),
    );
  }

  group('ScheduleTimingSection', () {
    late ValueNotifier<RelativeTime> startController;
    late ValueNotifier<RelativeTime> dueController;

    setUp(() {
      startController = ValueNotifier<RelativeTime>(initialStartTime);
      dueController = ValueNotifier<RelativeTime>(initialDueTime);
    });

    tearDown(() {
      startController.dispose();
      dueController.dispose();
    });

    group('Rendering & Localization', () {
      testWidgets(
        'renders section headers, help icons, and helper descriptions',
        (tester) async {
          final theme = ThemeData.light(useMaterial3: true);

          await tester.pumpWidget(
            buildWidget(
              startController: startController,
              dueController: dueController,
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();

          // Verify section headers
          final startLabelFinder = find.text('Start');
          final dueLabelFinder = find.text('Due');
          expect(startLabelFinder, findsOneWidget);
          expect(dueLabelFinder, findsOneWidget);

          final startLabelText = tester.widget<Text>(startLabelFinder);
          expect(startLabelText.style?.fontWeight, FontWeight.bold);
          expect(
            startLabelText.style?.color,
            theme.colorScheme.onSurfaceVariant,
          );

          final dueLabelText = tester.widget<Text>(dueLabelFinder);
          expect(dueLabelText.style?.fontWeight, FontWeight.bold);
          expect(dueLabelText.style?.color, theme.colorScheme.onSurfaceVariant);

          // Verify helper icons
          final iconFinders = find.byIcon(Icons.help_outline);
          expect(iconFinders, findsNWidgets(2));

          for (final iconElement in iconFinders.evaluate()) {
            final iconWidget = iconElement.widget as Icon;
            expect(iconWidget.size, 14);
            expect(iconWidget.color, theme.colorScheme.outline);
          }

          // Verify helper descriptions
          final startHelpFinder = find.text(
            'When does the task appear in your list of tasks?',
          );
          final dueHelpFinder = find.text(
            'When does this task need to be completed before it should be considered overdue?',
          );
          expect(startHelpFinder, findsOneWidget);
          expect(dueHelpFinder, findsOneWidget);

          final startHelpText = tester.widget<Text>(startHelpFinder);
          expect(startHelpText.style?.fontStyle, FontStyle.italic);
          expect(
            startHelpText.style?.color,
            theme.colorScheme.onSurfaceVariant,
          );

          final dueHelpText = tester.widget<Text>(dueHelpFinder);
          expect(dueHelpText.style?.fontStyle, FontStyle.italic);
          expect(dueHelpText.style?.color, theme.colorScheme.onSurfaceVariant);
        },
      );

      testWidgets('renders properly with localized Spanish strings', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            startController: startController,
            dueController: dueController,
            locale: const Locale('es'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Vence'), findsOneWidget);
        expect(
          find.text('¿Cuándo aparece la tarea en tu lista de tareas?'),
          findsOneWidget,
        );
        expect(
          find.text(
            '¿Cuándo debe completarse esta tarea antes de considerarse atrasada?',
          ),
          findsOneWidget,
        );
      });
    });

    group('Component Wiring & Properties', () {
      testWidgets(
        'instantiates two RelativeTimeWidgets with unconstrained constraints and correct keys',
        (tester) async {
          const keyPrefix = 'custom_schedule';

          await tester.pumpWidget(
            buildWidget(
              startController: startController,
              dueController: dueController,
              keyPrefix: keyPrefix,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(RelativeTimeWidget), findsNWidgets(2));

          final startPickerFinder = find.byKey(
            const Key('${keyPrefix}_start_relative_time_picker'),
          );
          final duePickerFinder = find.byKey(
            const Key('${keyPrefix}_due_relative_time_picker'),
          );

          expect(startPickerFinder, findsOneWidget);
          expect(duePickerFinder, findsOneWidget);

          final startPicker = tester.widget<RelativeTimeWidget>(
            startPickerFinder,
          );
          expect(startPicker.constraint, RelativeTimeConstraint.unconstrained);
          expect(startPicker.controller, equals(startController));

          final duePicker = tester.widget<RelativeTimeWidget>(duePickerFinder);
          expect(duePicker.constraint, RelativeTimeConstraint.unconstrained);
          expect(duePicker.controller, equals(dueController));
        },
      );

      testWidgets(
        'maintains key isolation across multiple ScheduleTimingSection instances',
        (tester) async {
          final startController2 = ValueNotifier<RelativeTime>(
            initialStartTime,
          );
          final dueController2 = ValueNotifier<RelativeTime>(initialDueTime);

          addTearDown(() {
            startController2.dispose();
            dueController2.dispose();
          });

          await tester.pumpWidget(
            buildTestableWidget(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ScheduleTimingSection(
                        startController: startController,
                        dueController: dueController,
                        keyPrefix: 'section_one',
                      ),
                      ScheduleTimingSection(
                        startController: startController2,
                        dueController: dueController2,
                        keyPrefix: 'section_two',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('section_one_start_relative_time_picker')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('section_one_due_relative_time_picker')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('section_two_start_relative_time_picker')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('section_two_due_relative_time_picker')),
            findsOneWidget,
          );
        },
      );
    });

    group('Reactivity & State Changes', () {
      testWidgets('updates UI when startController value changes dynamically', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            startController: startController,
            dueController: dueController,
          ),
        );
        await tester.pumpAndSettle();

        // Initial 9:00 AM
        expect(find.textContaining('9:00'), findsOneWidget);

        // Update start controller externally
        startController.value = const RelativeTime(
          dayOffset: 1,
          time: TimeOfDay(hour: 10, minute: 30),
        );
        await tester.pumpAndSettle();

        // 10:30 AM
        expect(find.textContaining('10:30'), findsOneWidget);
        expect(find.text('1 day after'), findsOneWidget);
      });

      testWidgets('updates UI when dueController value changes dynamically', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            startController: startController,
            dueController: dueController,
          ),
        );
        await tester.pumpAndSettle();

        // Initial 5:00 PM (17:00)
        expect(find.textContaining('5:00'), findsOneWidget);

        // Update due controller externally
        dueController.value = const RelativeTime(
          dayOffset: 2,
          time: TimeOfDay(hour: 20, minute: 15),
        );
        await tester.pumpAndSettle();

        // 8:15 PM (20:15)
        expect(find.textContaining('8:15'), findsOneWidget);
        expect(find.text('2 days later'), findsOneWidget);
      });

      testWidgets(
        'notifies controller listeners when controller values change',
        (tester) async {
          int startNotified = 0;
          int dueNotified = 0;

          startController.addListener(() => startNotified++);
          dueController.addListener(() => dueNotified++);

          await tester.pumpWidget(
            buildWidget(
              startController: startController,
              dueController: dueController,
            ),
          );
          await tester.pumpAndSettle();

          startController.value = const RelativeTime(
            dayOffset: 3,
            time: TimeOfDay(hour: 8, minute: 0),
          );
          dueController.value = const RelativeTime(
            dayOffset: 4,
            time: TimeOfDay(hour: 18, minute: 0),
          );

          expect(startNotified, 1);
          expect(dueNotified, 1);
          expect(startController.value.dayOffset, 3);
          expect(dueController.value.dayOffset, 4);
        },
      );
    });
  });
}
