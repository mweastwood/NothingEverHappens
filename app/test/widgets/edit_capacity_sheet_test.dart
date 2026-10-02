import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/widgets/edit_capacity_sheet.dart';

import '../screens/home_screen_test.mocks.dart';
import '../test_helper.dart';

void main() {
  late MockUserSettingsRepository mockUserSettingsRepository;

  setUp(() {
    mockUserSettingsRepository = MockUserSettingsRepository();
    when(mockUserSettingsRepository.updateSettings(any))
        .thenAnswer((_) async {});
  });

  Widget createTestWidget({
    required UserSettings settings,
    required DateTime date,
    required bool isOverride,
  }) {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EditCapacitySheet.show(
                context,
                settings: settings,
                date: date,
                isOverride: isOverride,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    required UserSettings settings,
    required DateTime date,
    required bool isOverride,
  }) async {
    await tester.pumpWidget(
      createTestWidget(
        settings: settings,
        date: date,
        isOverride: isOverride,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
  }

  group('EditCapacitySheet', () {
    testWidgets(
      'calculates correct initial duration for override date',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: {'2026-07-01': 2.5},
        );
        final date = DateTime(2026, 7, 1); // Wednesday

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: true,
        );

        expect(find.text('Adjust Capacity'), findsOneWidget);
        expect(find.text('Set chore availability for 1/7/2026'), findsOneWidget);
        expect(find.text('2h 30m'), findsOneWidget);
      },
    );

    testWidgets(
      'calculates correct initial duration for baseline weekday template',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          defaultDailyCapacity: {'3': 4.0}, // Wednesday is weekday 3
        );
        final date = DateTime(2026, 7, 1); // Wednesday

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: false,
        );

        expect(find.text('Edit Default Capacity'), findsOneWidget);
        expect(
          find.text('Set default availability baseline for weekday'),
          findsOneWidget,
        );
        expect(find.text('4h 0m'), findsOneWidget);
      },
    );

    testWidgets(
      'stepper increments and decrements by 15m and clamps at 0',
      (WidgetTester tester) async {
        const settings = UserSettings(hoursAvailable: 0.5); // 30m
        final date = DateTime(2026, 7, 1);

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: false,
        );

        expect(find.text('30m'), findsWidgets); // stepper and preset chip

        // Increment +15m -> 45m
        final incBtn = find.byKey(const Key('capacity_increment_button'));
        await tester.tap(incBtn);
        await tester.pumpAndSettle();
        expect(find.text('45m'), findsOneWidget);

        // Decrement -15m -> 30m
        final decBtn = find.byKey(const Key('capacity_decrement_button'));
        await tester.tap(decBtn);
        await tester.pumpAndSettle();
        expect(find.text('30m'), findsWidgets);

        // Decrement -15m -> 15m
        await tester.tap(decBtn);
        await tester.pumpAndSettle();
        expect(find.text('15m'), findsOneWidget);

        // Decrement -15m -> 0m
        await tester.tap(decBtn);
        await tester.pumpAndSettle();
        expect(find.text('0m'), findsOneWidget);

        // Decrement again -> should clamp at 0m, not go negative
        await tester.tap(decBtn);
        await tester.pumpAndSettle();
        expect(find.text('0m'), findsOneWidget);
      },
    );

    testWidgets(
      'preset chips update duration to preset values',
      (WidgetTester tester) async {
        const settings = UserSettings(hoursAvailable: 8.0);
        final date = DateTime(2026, 7, 1);

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: true,
        );

        // Tap Away (0m)
        await tester.tap(find.text('Away (0m)'));
        await tester.pumpAndSettle();
        expect(find.text('0m'), findsOneWidget);

        // Tap 1h
        await tester.tap(find.text('1h'));
        await tester.pumpAndSettle();
        expect(find.text('1h 0m'), findsOneWidget);

        // Tap 2h
        await tester.tap(find.text('2h'));
        await tester.pumpAndSettle();
        expect(find.text('2h 0m'), findsOneWidget);

        // Tap 3h
        await tester.tap(find.text('3h'));
        await tester.pumpAndSettle();
        expect(find.text('3h 0m'), findsOneWidget);
      },
    );

    testWidgets(
      'reset to default removes date from overrides and updates repository',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: {
            '2026-07-01': 3.0,
            '2026-07-02': 4.0,
          },
        );
        final date = DateTime(2026, 7, 1);

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: true,
        );

        final resetBtn = find.byKey(const Key('capacity_reset_button'));
        expect(resetBtn, findsOneWidget);

        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Sheet should be dismissed
        expect(find.byType(EditCapacitySheet), findsNothing);

        // Verify repository update
        verify(
          mockUserSettingsRepository.updateSettings(
            argThat(
              predicate<UserSettings>(
                (s) =>
                    s.dailyCapacityOverrides != null &&
                    !s.dailyCapacityOverrides!.containsKey('2026-07-01') &&
                    s.dailyCapacityOverrides!['2026-07-02'] == 4.0,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'saving override updates dailyCapacityOverrides in repository',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: {'2026-07-02': 4.0},
        );
        final date = DateTime(2026, 7, 1);

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: true,
        );

        // Tap 1h preset
        await tester.tap(find.text('1h'));
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('capacity_save_button')));
        await tester.pumpAndSettle();

        expect(find.byType(EditCapacitySheet), findsNothing);

        verify(
          mockUserSettingsRepository.updateSettings(
            argThat(
              predicate<UserSettings>(
                (s) =>
                    s.dailyCapacityOverrides != null &&
                    s.dailyCapacityOverrides!['2026-07-01'] == 1.0 &&
                    s.dailyCapacityOverrides!['2026-07-02'] == 4.0,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'saving baseline updates defaultDailyCapacity in repository',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          defaultDailyCapacity: {'1': 2.0},
        );
        final date = DateTime(2026, 7, 1); // Wednesday = '3'

        await openSheet(
          tester,
          settings: settings,
          date: date,
          isOverride: false,
        );

        // Tap 2h preset
        await tester.tap(find.text('2h'));
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.byKey(const Key('capacity_save_button')));
        await tester.pumpAndSettle();

        expect(find.byType(EditCapacitySheet), findsNothing);

        verify(
          mockUserSettingsRepository.updateSettings(
            argThat(
              predicate<UserSettings>(
                (s) =>
                    s.defaultDailyCapacity != null &&
                    s.defaultDailyCapacity!['1'] == 2.0 &&
                    s.defaultDailyCapacity!['3'] == 2.0,
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}
