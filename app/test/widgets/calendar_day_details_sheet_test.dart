import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../test_helper.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/widgets/calendar_day_details_sheet.dart';

import '../screens/home_screen_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockAuthRepository mockAuthRepository;

  final testDay = const CivilDay(year: 2026, month: 3, day: 8);

  final sampleSchedules = [
    TaskSchedule(
      id: 'S-1',
      title: 'Water Houseplants',
      description: 'Living room and balcony',
      priority: TaskPriority.high,
      schedules: [
        DailySchedule(
          id: 'R-1',
          scheduleId: 'S-1',
          startDate: const CivilDay(year: 2026, month: 3, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 8,
            minute: 0,
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            hour: 12,
            minute: 0,
          ),
        ),
      ],
    ),
  ];

  final sampleInstances = [
    TaskInstance(
      id: 'I-1',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Water Houseplants',
      description: 'Living room and balcony',
      priority: TaskPriority.high,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
      status: TaskStatus.pending,
    ),
    TaskInstance(
      id: 'I-2',
      scheduleId: 'S-2',
      ruleId: 'R-2',
      title: 'Clean Kitchen',
      description: 'Wipe counters and do dishes',
      priority: TaskPriority.medium,
      scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 13, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
      status: TaskStatus.completed,
    ),
  ];

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    mockAuthRepository = MockAuthRepository();

    when(
      mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => Stream.value(null));
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.uncompleteTaskInstance(any),
    ).thenAnswer((_) async => null);
  });

  Widget createTestWidget({
    required CivilDay day,
    List<TaskInstance> instances = const [],
    List<TaskSchedule> schedules = const [],
  }) {
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        taskInstancesProvider.overrideWith((ref) => Stream.value(instances)),
        taskSchedulesProvider.overrideWith((ref) => Stream.value(schedules)),
      ],
      child: buildTestableWidget(
        child: Scaffold(body: CalendarDayDetailsSheet(day: day)),
      ),
    );
  }

  testWidgets('Verify sheet renders correct date and tasks', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        day: testDay,
        instances: sampleInstances,
        schedules: sampleSchedules,
      ),
    );
    await tester.pumpAndSettle();

    final expectedFormattedDate = DateFormat.yMMMMEEEEd().format(
      DateTime(2026, 3, 8),
    );
    expect(find.textContaining(expectedFormattedDate), findsOneWidget);
    expect(find.text('2 tasks'), findsOneWidget);

    expect(find.text('Water Houseplants'), findsOneWidget);
    expect(find.text('Clean Kitchen'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
  });

  testWidgets('Verify toggle completion triggers repository call', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestWidget(
        day: testDay,
        instances: sampleInstances,
        schedules: sampleSchedules,
      ),
    );
    await tester.pumpAndSettle();

    // Tap unchecked task I-1 to complete
    final uncheckedFinder = find.byIcon(Icons.radio_button_unchecked);
    expect(uncheckedFinder, findsOneWidget);
    await tester.tap(uncheckedFinder);
    await tester.pumpAndSettle();

    verify(mockTaskRepository.completeTaskInstance('I-1')).called(1);

    // Tap checked task I-2 to uncomplete
    final checkedFinder = find.byIcon(Icons.check_circle);
    expect(checkedFinder, findsOneWidget);
    await tester.tap(checkedFinder);
    await tester.pumpAndSettle();

    verify(mockTaskRepository.uncompleteTaskInstance('I-2')).called(1);
  });

  testWidgets('Verify empty state display', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        day: const CivilDay(year: 2026, month: 3, day: 15),
        instances: const [],
        schedules: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tasks scheduled'), findsNWidgets(2));
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('Verify static show helper presents sheet via bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          taskInstancesProvider.overrideWith(
            (_) => Stream.value(sampleInstances),
          ),
          taskSchedulesProvider.overrideWith(
            (_) => Stream.value(sampleSchedules),
          ),
        ],
        child: buildTestableWidget(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      CalendarDayDetailsSheet.show(context, day: testDay);
                    },
                    child: const Text('Open Sheet'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDayDetailsSheet), findsOneWidget);
    expect(find.text('Water Houseplants'), findsOneWidget);
  });
}
