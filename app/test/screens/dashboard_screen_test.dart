import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';
import 'home_screen_test.mocks.dart';

import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/dashboard_screen.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

void main() {
  late MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<UserSettings> settingsSubject;

  setUp(() {
    mockUserSettingsRepository = MockUserSettingsRepository();
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(
        hoursAvailable: 8.0,
        defaultDailyCapacity: {'1': 2.0, '2': 3.0},
        dailyCapacityOverrides: {},
        lastCapacityConfirmedWeek: '',
      ),
    );
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
  });

  tearDown(() {
    settingsSubject.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
      ],
      child: buildTestableWidget(child: const DashboardScreen()),
    );
  }

  testWidgets('DashboardScreen renders weekly capacity and default template', (
    WidgetTester tester,
  ) async {
    AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0)); // Wednesday
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify weekly capacity title
    expect(find.text('Weekly Capacity Forecast'), findsOneWidget);

    // Verify pencil button to edit default baseline is present
    expect(
      find.byKey(const Key('edit_default_capacity_button')),
      findsOneWidget,
    );

    // Verify custom task/card to confirm capacity is shown (since lastCapacityConfirmedWeek is empty)
    expect(find.text('Confirm capacity for this week'), findsOneWidget);
  });

  testWidgets('Tapping confirm capacity updates UserSettings', (
    WidgetTester tester,
  ) async {
    AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0)); // Wednesday
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const Key('confirm_capacity_button'));
    expect(confirmBtn, findsOneWidget);

    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify repository updateSettings was called
    verify(
      mockUserSettingsRepository.updateSettings(
        argThat(
          predicate<UserSettings>(
            (settings) => settings.lastCapacityConfirmedWeek == '2026-06-29',
          ),
        ), // Monday of that week
      ),
    ).called(1);
  });

  testWidgets(
    'Tapping a capacity bar opens edit capacity dialog and saves custom capacity override',
    (WidgetTester tester) async {
      AppClock.setMockTime(
        DateTime(2026, 7, 1, 9, 0),
      ); // Wednesday (2026-07-01)
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on Wednesday capacity bar (July 1st)
      final barKey = const Key('capacity_bar_2026-07-01');
      expect(find.byKey(barKey), findsOneWidget);

      await tester.tap(find.byKey(barKey));
      await tester.pumpAndSettle();

      // Verify edit dialog/bottom sheet is shown
      expect(find.text('Adjust Capacity'), findsOneWidget);

      // Tap increment button (+15m)
      final incBtn = find.byKey(const Key('capacity_increment_button'));
      expect(incBtn, findsOneWidget);
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      // Tap Save button
      final saveBtn = find.byKey(const Key('capacity_save_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify settings were updated with override for 2026-07-01
      verify(
        mockUserSettingsRepository.updateSettings(
          argThat(
            predicate<UserSettings>(
              (settings) =>
                  settings.dailyCapacityOverrides?['2026-07-01'] != null,
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'Tapping pencil icon opens default template dialog and lets user edit weekday baseline',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0)); // Wednesday
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify pencil icon exists
      final editBtn = find.byKey(const Key('edit_default_capacity_button'));
      expect(editBtn, findsOneWidget);

      // Tap pencil icon
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify dialog header is visible
      expect(
        find.text('Set standard availability baseline per day'),
        findsOneWidget,
      );

      // Tap Monday tile in the dialog
      final mondayTile = find.byKey(const Key('default_capacity_tile_1'));
      expect(mondayTile, findsOneWidget);
      await tester.tap(mondayTile);
      await tester.pumpAndSettle();

      // Verify edit dialog/bottom sheet is shown
      expect(find.text('Edit Default Capacity'), findsOneWidget);

      // Tap increment button (+15m)
      final incBtn = find.byKey(const Key('capacity_increment_button'));
      expect(incBtn, findsOneWidget);
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      // Tap Save button
      final saveBtn = find.byKey(const Key('capacity_save_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify settings default capacity was updated for Monday ('1')
      verify(
        mockUserSettingsRepository.updateSettings(
          argThat(
            predicate<UserSettings>(
              (settings) => settings.defaultDailyCapacity?['1'] != null,
            ),
          ),
        ),
      ).called(1);
    },
  );
}
