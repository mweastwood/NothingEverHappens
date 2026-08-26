import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/task_priority.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_effort_and_priority_section.dart';

void main() {
  Widget buildWidget({
    required TextEditingController estimatedDurationController,
    required TaskPriority priority,
    ValueChanged<TaskPriority>? onPriorityChanged,
    required bool skipIfNoCapacity,
    ValueChanged<bool>? onSkipIfNoCapacityChanged,
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
          child: TaskEffortAndPrioritySection(
            estimatedDurationController: estimatedDurationController,
            priority: priority,
            onPriorityChanged: onPriorityChanged,
            skipIfNoCapacity: skipIfNoCapacity,
            onSkipIfNoCapacityChanged: onSkipIfNoCapacityChanged,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  group('TaskEffortAndPrioritySection', () {
    testWidgets(
      'renders effort input, presets, priority chips, and capacity checkbox',
      (WidgetTester tester) async {
        final controller = TextEditingController(text: '30');
        await tester.pumpWidget(
          buildWidget(
            estimatedDurationController: controller,
            priority: TaskPriority.medium,
            skipIfNoCapacity: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Effort and Priority'), findsOneWidget);
        expect(find.byKey(const Key('estimated_effort_field')), findsOneWidget);
        expect(
          find.byKey(const Key('estimated_effort_decrement_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('estimated_effort_increment_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('preset_chip_30')), findsOneWidget);
        expect(find.byKey(const Key('priority_chip_medium')), findsOneWidget);
        expect(
          find.byKey(const Key('skip_if_no_capacity_checkbox')),
          findsOneWidget,
        );
      },
    );

    testWidgets('increment and decrement buttons modify controller text', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController(text: '10');
      await tester.pumpWidget(
        buildWidget(
          estimatedDurationController: controller,
          priority: TaskPriority.medium,
          skipIfNoCapacity: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('estimated_effort_increment_button')),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '15');

      await tester.tap(
        find.byKey(const Key('estimated_effort_decrement_button')),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '10');
    });

    testWidgets('tapping priority chip triggers callback', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      TaskPriority? selectedPriority;

      await tester.pumpWidget(
        buildWidget(
          estimatedDurationController: controller,
          priority: TaskPriority.medium,
          onPriorityChanged: (p) => selectedPriority = p,
          skipIfNoCapacity: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('priority_chip_high')));
      await tester.pumpAndSettle();

      expect(selectedPriority, TaskPriority.high);
    });

    testWidgets('tapping skipIfNoCapacity checkbox triggers callback', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      bool? checkedValue;

      await tester.pumpWidget(
        buildWidget(
          estimatedDurationController: controller,
          priority: TaskPriority.medium,
          skipIfNoCapacity: false,
          onSkipIfNoCapacityChanged: (val) => checkedValue = val,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('skip_if_no_capacity_checkbox')));
      await tester.pumpAndSettle();

      expect(checkedValue, true);
    });
  });
}
