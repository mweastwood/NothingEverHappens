import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/create_task/task_family_assignment_section.dart';
import 'package:nothing_ever_happens/widgets/standard_choice_chip.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_task_completion_mode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import '../../test_helper.dart';

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

    testWidgets(
      'renders completion requirement choice chips and helper when isFamily is true',
      (WidgetTester tester) async {
        FamilyCompletionMode currentMode = FamilyCompletionMode.anyone;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return TaskFamilyAssignmentSection(
                    isFamily: true,
                    familyCompletionMode: currentMode,
                    onFamilyCompletionModeChanged: (mode) {
                      setState(() {
                        currentMode = mode;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Completion Requirement'), findsOneWidget);
        expect(
          find.byKey(const Key('completion_mode_anyone_chip')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('completion_mode_individual_chip')),
          findsOneWidget,
        );
        expect(
          find.text('One person can check off this task for everyone.'),
          findsOneWidget,
        );

        // Tap Everyone individually
        await tester.tap(
          find.byKey(const Key('completion_mode_individual_chip')),
        );
        await tester.pumpAndSettle();

        expect(currentMode, FamilyCompletionMode.individual);
        expect(
          find.text('Every family member must check off their own task.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'hides completion requirement choice chips when isFamily is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildWidget(isFamily: false));
        await tester.pumpAndSettle();

        expect(find.text('Completion Requirement'), findsNothing);
        expect(
          find.byKey(const Key('completion_mode_anyone_chip')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('completion_mode_individual_chip')),
          findsNothing,
        );
      },
    );

    testWidgets('readOnly disables completion requirement choice chips', (
      WidgetTester tester,
    ) async {
      bool modeChanged = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TaskFamilyAssignmentSection(
              isFamily: true,
              readOnly: true,
              familyCompletionMode: FamilyCompletionMode.anyone,
              onFamilyCompletionModeChanged: (_) => modeChanged = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('completion_mode_individual_chip')),
      );
      expect(chip.onSelected, isNull);

      await tester.tap(
        find.byKey(const Key('completion_mode_individual_chip')),
      );
      await tester.pumpAndSettle();
      expect(modeChanged, isFalse);
    });

    testWidgets(
      'renders member assignment chips when isFamily is true and members list is non-empty',
      (WidgetTester tester) async {
        const members = [
          FamilyMember(
            userId: 'user-1',
            displayName: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.parent,
          ),
          FamilyMember(
            userId: 'user-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.nonParent,
          ),
        ];

        String? assignedUser = 'user-1';
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskFamilyAssignmentSection(
                isFamily: true,
                members: members,
                assignedUserId: assignedUser,
                onAssignedUserChanged: (uid) => assignedUser = uid,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Assign to'), findsOneWidget);
        expect(find.byKey(const Key('unassigned_member_chip')), findsOneWidget);
        expect(find.byKey(const Key('member_chip_user-1')), findsOneWidget);
        expect(find.byKey(const Key('member_chip_user-2')), findsOneWidget);

        final unassignedChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('unassigned_member_chip')),
        );
        final aliceChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_user-1')),
        );
        final bobChip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_user-2')),
        );

        expect(unassignedChip.selected, isFalse);
        expect(aliceChip.selected, isTrue);
        expect(bobChip.selected, isFalse);

        expect(
          find.descendant(
            of: find.byKey(const Key('member_chip_user-1')),
            matching: find.byIcon(Icons.supervisor_account),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('member_chip_user-2')),
            matching: find.byIcon(Icons.person),
          ),
          findsOneWidget,
        );

        // Tap Bob
        await tester.tap(find.byKey(const Key('member_chip_user-2')));
        await tester.pumpAndSettle();
        expect(assignedUser, 'user-2');

        // Tap Unassigned
        await tester.tap(find.byKey(const Key('unassigned_member_chip')));
        await tester.pumpAndSettle();
        expect(assignedUser, isNull);
      },
    );

    testWidgets(
      'renders "You" instead of member name when member matches currentUserId',
      (WidgetTester tester) async {
        const members = [
          FamilyMember(
            userId: 'user-1',
            displayName: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.parent,
          ),
          FamilyMember(
            userId: 'user-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.nonParent,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TaskFamilyAssignmentSection(
                isFamily: true,
                members: members,
                assignedUserId: 'user-1',
                currentUserId: 'user-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final user1Chip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_user-1')),
        );
        final user2Chip = tester.widget<StandardChoiceChip>(
          find.byKey(const Key('member_chip_user-2')),
        );

        expect(user1Chip.label, 'You');
        expect(user2Chip.label, 'Bob');
      },
    );

    testWidgets(
      'visually distinguishes parents with supervisor_account icon and non-parents with person icon',
      (WidgetTester tester) async {
        const members = [
          FamilyMember(
            userId: 'parent-1',
            displayName: 'Parent Member',
            email: 'parent@example.com',
            role: FamilyRole.parent,
          ),
          FamilyMember(
            userId: 'child-1',
            displayName: 'Child Member',
            email: 'child@example.com',
            role: FamilyRole.nonParent,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TaskFamilyAssignmentSection(
                isFamily: true,
                members: members,
                assignedUserId: 'parent-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const Key('member_chip_parent-1')),
            matching: find.byIcon(Icons.supervisor_account),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('member_chip_child-1')),
            matching: find.byIcon(Icons.person),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not render member assignment chips when isFamily is false even if members exist',
      (WidgetTester tester) async {
        const members = [
          FamilyMember(
            userId: 'user-1',
            displayName: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.parent,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TaskFamilyAssignmentSection(
                isFamily: false,
                members: members,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Assign to'), findsNothing);
        expect(find.byKey(const Key('unassigned_member_chip')), findsNothing);
        expect(find.byKey(const Key('member_chip_user-1')), findsNothing);
      },
    );

    testWidgets('disables member assignment chips when readOnly is true', (
      WidgetTester tester,
    ) async {
      const members = [
        FamilyMember(
          userId: 'user-1',
          displayName: 'Alice',
          email: 'alice@example.com',
          role: FamilyRole.parent,
        ),
      ];

      String? assignedUser = 'user-1';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TaskFamilyAssignmentSection(
              isFamily: true,
              readOnly: true,
              members: members,
              assignedUserId: assignedUser,
              onAssignedUserChanged: (uid) => assignedUser = uid,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unassignedChip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('unassigned_member_chip')),
      );
      final aliceChip = tester.widget<StandardChoiceChip>(
        find.byKey(const Key('member_chip_user-1')),
      );

      expect(unassignedChip.onSelected, isNull);
      expect(aliceChip.onSelected, isNull);

      await tester.tap(find.byKey(const Key('unassigned_member_chip')));
      await tester.pumpAndSettle();
      expect(assignedUser, 'user-1');
    });

    testGoldens(
      'TaskFamilyAssignmentSection renders correctly in different states',
      (tester) async {
        const members = [
          FamilyMember(
            userId: 'user-1',
            displayName: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.parent,
          ),
          FamilyMember(
            userId: 'user-2',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.nonParent,
          ),
        ];

        final builder = GoldenBuilder.column()
          ..addScenario(
            'Individual (Personal Task Selected)',
            TaskFamilyAssignmentSection(
              isFamily: false,
              onFamilyToggled: (_) {},
            ),
          )
          ..addScenario(
            'Family Task Selected (No Members)',
            TaskFamilyAssignmentSection(
              isFamily: true,
              onFamilyToggled: (_) {},
            ),
          )
          ..addScenario(
            'Family Task Selected with Members (Unassigned)',
            TaskFamilyAssignmentSection(
              isFamily: true,
              members: members,
              assignedUserId: null,
              onFamilyToggled: (_) {},
            ),
          )
          ..addScenario(
            'Family Task Selected with Member Assigned',
            TaskFamilyAssignmentSection(
              isFamily: true,
              members: members,
              assignedUserId: 'user-1',
              onFamilyToggled: (_) {},
            ),
          )
          ..addScenario(
            'Read Only State with Member Assigned',
            TaskFamilyAssignmentSection(
              isFamily: true,
              readOnly: true,
              members: members,
              assignedUserId: 'user-2',
            ),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(600, 1800),
        );

        await screenMatchesGolden(
          tester,
          'task_family_assignment_section_golden',
        );
      },
    );
  });
}
