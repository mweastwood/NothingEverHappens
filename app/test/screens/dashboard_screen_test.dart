import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';
import 'home_screen_test.mocks.dart';

import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/dashboard_screen.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';

void main() {
  late MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<UserSettings> settingsSubject;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;

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
    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([]);
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
  });

  tearDown(() {
    settingsSubject.close();
    tasksSubject.close();
    instancesSubject.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
        taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
        taskInstancesProvider.overrideWith((ref) => instancesSubject.stream),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
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

      // Verify settings default capacity was updated for Monday ('1') to 2.25 hours (2.0 + 15 min)
      verify(
        mockUserSettingsRepository.updateSettings(
          argThat(
            predicate<UserSettings>(
              (settings) => settings.defaultDailyCapacity?['1'] == 2.25,
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'Tapping different weekdays in default capacity template dialog updates the correct weekday baseline without shifting',
    (WidgetTester tester) async {
      AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0)); // Wednesday

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open Default Capacity Template dialog
      await tester.tap(find.byKey(const Key('edit_default_capacity_button')));
      await tester.pumpAndSettle();

      // 1. Test Tuesday ('2') - starts at 3.0, incremented to 3.25
      final tuesdayTile = find.byKey(const Key('default_capacity_tile_2'));
      await tester.tap(tuesdayTile);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('capacity_increment_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capacity_save_button')));
      await tester.pumpAndSettle();

      verify(
        mockUserSettingsRepository.updateSettings(
          argThat(
            predicate<UserSettings>(
              (settings) => settings.defaultDailyCapacity?['2'] == 3.25,
            ),
          ),
        ),
      ).called(1);

      clearInteractions(mockUserSettingsRepository);

      // 2. Test Sunday ('7') - starts at 8.0 (default), incremented to 8.25
      final sundayTile = find.byKey(const Key('default_capacity_tile_7'));
      await tester.dragUntilVisible(
        sundayTile,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(sundayTile);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('capacity_increment_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capacity_save_button')));
      await tester.pumpAndSettle();

      verify(
        mockUserSettingsRepository.updateSettings(
          argThat(
            predicate<UserSettings>(
              (settings) => settings.defaultDailyCapacity?['7'] == 8.25,
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'DashboardScreen calculates and renders planned work vs capacity correctly',
    (WidgetTester tester) async {
      AppClock.setMockTime(
        DateTime(2026, 7, 1, 9, 0),
      ); // Wednesday (2026-07-01)

      final schedule1 = TaskSchedule(
        id: 'schedule-1',
        title: 'Task A',
        description: '90 minutes task',
        estimatedDuration: const Duration(minutes: 90),
        schedules: [
          DailySchedule(
            startDate: CivilDay(year: 2026, month: 7, day: 1),
            interval: 1,
          ),
        ],
      );

      final schedule2 = TaskSchedule(
        id: 'schedule-2',
        title: 'Task B',
        description: '45 minutes task',
        estimatedDuration: const Duration(minutes: 45),
        schedules: [
          DailySchedule(
            startDate: CivilDay(year: 2026, month: 7, day: 1),
            interval: 1,
          ),
        ],
      );

      settingsSubject.add(
        const UserSettings(
          hoursAvailable: 8.0,
          defaultDailyCapacity: {'3': 2.0}, // Wed = 2 hours
          dailyCapacityOverrides: {},
          lastCapacityConfirmedWeek: '',
        ),
      );

      final instance1 = TaskInstance(
        id: 'inst-1',
        scheduleId: schedule1.id,
        ruleId: 'r-1',
        title: 'Task A Instance',
        description: 'Desc',
        scheduledDate: CivilDay(year: 2026, month: 7, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      );

      final instance2 = TaskInstance(
        id: 'inst-2',
        scheduleId: schedule2.id,
        ruleId: 'r-2',
        title: 'Task B Instance',
        description: 'Desc',
        scheduledDate: CivilDay(year: 2026, month: 7, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      );

      tasksSubject.add([schedule1, schedule2]);
      instancesSubject.add([instance1, instance2]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Total planned = 2h 15m. Capacity = 2h.
      expect(find.text('2h 15m/2h'), findsOneWidget);
    },
  );

  testGoldens('DashboardScreen golden test', (tester) async {
    AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0)); // Wednesday (2026-07-01)

    final schedule1 = TaskSchedule(
      id: 'schedule-1',
      title: 'Task A',
      description: '90 minutes task',
      estimatedDuration: const Duration(minutes: 90),
      schedules: [
        DailySchedule(
          startDate: CivilDay(year: 2026, month: 7, day: 1),
          interval: 1,
        ),
      ],
    );

    settingsSubject.add(
      const UserSettings(
        hoursAvailable: 8.0,
        defaultDailyCapacity: {'3': 2.0}, // Wed = 2 hours
        dailyCapacityOverrides: {},
        lastCapacityConfirmedWeek: '',
      ),
    );

    final instance1 = TaskInstance(
      id: 'inst-1',
      scheduleId: schedule1.id,
      ruleId: 'r-1',
      title: 'Task A Instance',
      description: 'Desc',
      scheduledDate: CivilDay(year: 2026, month: 7, day: 1),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      status: 'pending',
    );

    tasksSubject.add([schedule1]);
    instancesSubject.add([instance1]);

    await tester.pumpWidgetBuilder(
      createTestWidget(),
      surfaceSize: const Size(400, 800),
    );

    await screenMatchesGolden(tester, 'dashboard_screen_en');
  });

  testWidgets(
    'Capacity bar heights scale dynamically to the peak data point of the week',
    (WidgetTester tester) async {
      AppClock.setMockTime(
        DateTime(2026, 7, 1, 9, 0),
      ); // Wednesday (2026-07-01)

      settingsSubject.add(
        const UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: {
            '2026-07-01': 12.0, // Peak
            '2026-07-02': 6.0, // 50%
          },
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Wednesday (Peak: 12.0 hrs) should scale to max height (120 px)
      final wedPaint = find.descendant(
        of: find.byKey(const Key('capacity_bar_2026-07-01')),
        matching: find.byType(CustomPaint),
      );
      final wedHeight = tester.getSize(wedPaint).height;
      expect(wedHeight, 120.0);

      // Thursday (6.0 hrs) should scale to 50% height (60 px)
      final thuPaint = find.descendant(
        of: find.byKey(const Key('capacity_bar_2026-07-02')),
        matching: find.byType(CustomPaint),
      );
      final thuHeight = tester.getSize(thuPaint).height;
      expect(thuHeight, 60.0);
    },
  );
}
