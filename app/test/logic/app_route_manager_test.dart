import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_route_manager.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:rxdart/rxdart.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'app_route_manager_test.mocks.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([]);
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
  });

  tearDown(() {
    tasksSubject.close();
  });

  testWidgets('AppRouteManager parses /tasks route correctly', (
    WidgetTester tester,
  ) async {
    final manager = AppRouteManager(
      mockUri: Uri.parse('https://example.com/tasks'),
    );
    int? changedIndex;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Consumer(
                builder: (context, ref, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    manager.handleUrlParameters(
                      context: context,
                      ref: ref,
                      onIndexChanged: (index) {
                        changedIndex = index;
                      },
                      currentIndex: 0,
                    );
                  });
                  return const SizedBox();
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(changedIndex, 0);
  });

  testWidgets('AppRouteManager parses /schedules route correctly', (
    WidgetTester tester,
  ) async {
    final manager = AppRouteManager(
      mockUri: Uri.parse('https://example.com/schedules'),
    );
    int? changedIndex;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Consumer(
                builder: (context, ref, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    manager.handleUrlParameters(
                      context: context,
                      ref: ref,
                      onIndexChanged: (index) {
                        changedIndex = index;
                      },
                      currentIndex: 0,
                    );
                  });
                  return const SizedBox();
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(changedIndex, 1);
  });
}
