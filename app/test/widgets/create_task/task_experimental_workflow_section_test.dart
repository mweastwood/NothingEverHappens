import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_experimental_workflow_section.dart';

void main() {
  Widget buildWidget({
    required bool isExperimentalExpanded,
    VoidCallback? onToggleExperimentalExpanded,
    required bool isMealWorkflow,
    ValueChanged<bool>? onMealWorkflowToggled,
    TimeOfDay selectTime = const TimeOfDay(hour: 10, minute: 0),
    TimeOfDay shopTime = const TimeOfDay(hour: 16, minute: 0),
    TimeOfDay prepTime = const TimeOfDay(hour: 18, minute: 30),
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
          child: TaskExperimentalWorkflowSection(
            isExperimentalExpanded: isExperimentalExpanded,
            onToggleExperimentalExpanded: onToggleExperimentalExpanded,
            isMealWorkflow: isMealWorkflow,
            onMealWorkflowToggled: onMealWorkflowToggled,
            selectTime: selectTime,
            shopTime: shopTime,
            prepTime: prepTime,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  group('TaskExperimentalWorkflowSection', () {
    testWidgets('renders header when collapsed', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(isExperimentalExpanded: false, isMealWorkflow: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Experimental Features'), findsOneWidget);
      expect(find.text('Task Workflow'), findsNothing);
    });

    testWidgets('renders workflow options and meal stage times when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(isExperimentalExpanded: true, isMealWorkflow: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Experimental Features'), findsOneWidget);
      expect(find.text('Task Workflow'), findsOneWidget);
      expect(find.byKey(const Key('workflow_standard_chip')), findsOneWidget);
      expect(find.byKey(const Key('workflow_meal_chip')), findsOneWidget);
      expect(find.text('Stage Target Times'), findsOneWidget);
      expect(find.text('1. Select'), findsOneWidget);
      expect(find.text('2. Shop'), findsOneWidget);
      expect(find.text('3. Prep'), findsOneWidget);
    });

    testWidgets('tapping header triggers onToggleExperimentalExpanded', (
      WidgetTester tester,
    ) async {
      bool toggled = false;
      await tester.pumpWidget(
        buildWidget(
          isExperimentalExpanded: false,
          onToggleExperimentalExpanded: () => toggled = true,
          isMealWorkflow: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('experimental_features_header')));
      await tester.pumpAndSettle();

      expect(toggled, true);
    });

    testWidgets('tapping workflow chip triggers callback', (
      WidgetTester tester,
    ) async {
      bool? isMeal;
      await tester.pumpWidget(
        buildWidget(
          isExperimentalExpanded: true,
          isMealWorkflow: false,
          onMealWorkflowToggled: (val) => isMeal = val,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workflow_meal_chip')));
      await tester.pumpAndSettle();

      expect(isMeal, true);
    });
  });
}
