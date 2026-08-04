import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_family_assignment_section.dart';
import 'package:nothing_ever_happens/widgets/standard_choice_chip.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';

void main() {
  Widget buildWidget({
    required bool isFamily,
    ValueChanged<bool>? onFamilyToggled,
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
        body: TaskFamilyAssignmentSection(
          isFamily: isFamily,
          onFamilyToggled: onFamilyToggled,
          readOnly: readOnly,
        ),
      ),
    );
  }

  group('TaskFamilyAssignmentSection', () {
    testWidgets(
      'renders full width card and both personal and family task chips',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildWidget(isFamily: false));
        await tester.pumpAndSettle();

        final sizedBoxFinder = find.ancestor(
          of: find.byType(Card),
          matching: find.byType(SizedBox),
        );
        expect(sizedBoxFinder, findsOneWidget);
        final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
        expect(sizedBox.width, double.infinity);

        expect(find.byKey(const Key('personal_task_chip')), findsOneWidget);
        expect(find.byKey(const Key('is_family_toggle')), findsOneWidget);
      },
    );

    testWidgets(
      'displays correct selection state and helper for individual (personal) task',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildWidget(isFamily: false));
        await tester.pumpAndSettle();

        final personalChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('personal_task_chip')),
        );
        final familyChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('is_family_toggle')),
        );

        expect(personalChip.selected, isTrue);
        expect(familyChip.selected, isFalse);

        expect(find.text('Only visible to you.'), findsOneWidget);
      },
    );

    testWidgets('displays correct selection state and helper for family task', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(isFamily: true));
      await tester.pumpAndSettle();

      final personalChip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('personal_task_chip')),
      );
      final familyChip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('is_family_toggle')),
      );

      expect(personalChip.selected, isFalse);
      expect(familyChip.selected, isTrue);

      expect(
        find.text('Share this task with all family members.'),
        findsOneWidget,
      );
    });

    testWidgets('toggling from individual to family calls callback with true', (
      WidgetTester tester,
    ) async {
      bool? toggledValue;
      await tester.pumpWidget(
        buildWidget(
          isFamily: false,
          onFamilyToggled: (val) => toggledValue = val,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('is_family_toggle')));
      await tester.pumpAndSettle();

      expect(toggledValue, isTrue);
    });

    testWidgets(
      'toggling from family to individual calls callback with false',
      (WidgetTester tester) async {
        bool? toggledValue;
        await tester.pumpWidget(
          buildWidget(
            isFamily: true,
            onFamilyToggled: (val) => toggledValue = val,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('personal_task_chip')));
        await tester.pumpAndSettle();

        expect(toggledValue, isFalse);
      },
    );

    testWidgets('disables interaction when readOnly is true', (
      WidgetTester tester,
    ) async {
      bool toggled = false;
      await tester.pumpWidget(
        buildWidget(
          isFamily: false,
          readOnly: true,
          onFamilyToggled: (_) => toggled = true,
        ),
      );
      await tester.pumpAndSettle();

      final familyChip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('is_family_toggle')),
      );
      expect(familyChip.onSelected, isNull);

      await tester.tap(find.byKey(const Key('is_family_toggle')));
      await tester.pumpAndSettle();

      expect(toggled, isFalse);
    });
  });
}
