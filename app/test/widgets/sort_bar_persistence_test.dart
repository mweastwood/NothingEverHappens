import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';
import '../screens/home_screen_test.mocks.dart';

import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/home_screen.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  late MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<UserSettings> settingsSubject;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockUserSettingsRepository = MockUserSettingsRepository();
    mockAuthRepository = MockAuthRepository();
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(
        hoursAvailable: 8.0,
        showTaskListSortBar: true,
        showScheduleListSortBar: true,
      ),
    );
    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([]);

    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
  });

  tearDown(() {
    settingsSubject.close();
    tasksSubject.close();
    instancesSubject.close();
  });

  Widget createTestWidget({int initialTab = 0}) {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => settingsSubject.stream),
        taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
        taskInstancesProvider.overrideWith((ref) => instancesSubject.stream),
        taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        homeTabIndexProvider.overrideWith((ref) => initialTab),
      ],
      child: buildTestableWidget(child: const HomeScreen()),
    );
  }

  group('Sort Bar Persistence Tests', () {
    testWidgets(
      'Tapping sort icon on Task List screen updates showTaskListSortBar setting',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initialTab: 0));
        await tester.pumpAndSettle();

        // Tap sort toggle button in app bar
        final sortButton = find.byIcon(Icons.sort);
        expect(sortButton, findsOneWidget);

        await tester.tap(sortButton);
        await tester.pumpAndSettle();

        verify(
          mockUserSettingsRepository.updateSettings(
            argThat(
              predicate<UserSettings>(
                (s) =>
                    s.showTaskListSortBar == false &&
                    s.showScheduleListSortBar == true,
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Tapping sort icon on Schedule List screen updates showScheduleListSortBar setting',
      (tester) async {
        await tester.pumpWidget(createTestWidget(initialTab: 1));
        await tester.pumpAndSettle();

        // Tap sort toggle button in app bar on schedule tab
        final sortButton = find.byIcon(Icons.sort);
        expect(sortButton, findsOneWidget);

        await tester.tap(sortButton);
        await tester.pumpAndSettle();

        verify(
          mockUserSettingsRepository.updateSettings(
            argThat(
              predicate<UserSettings>(
                (s) =>
                    s.showTaskListSortBar == true &&
                    s.showScheduleListSortBar == false,
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}
