import 'dart:io';

void main() {
  final file = File('app/test/screens/task_list_screen_test.dart');
  String content = file.readAsStringSync();

  // 1. Remove mockInstancesFromSchedules and variables
  content = content.replaceFirst(
    '''  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;
  StreamSubscription<List<TaskSchedule>>? tasksSub;
  VoidCallback? clockListener;

  List<TaskInstance> mockInstancesFromSchedules(
    List<TaskSchedule> schedules,
    DateTime todayDate,
  ) {
    final today = CivilDay.fromDateTime(todayDate);
    final List<TaskInstance> list = [];
    for (final task in schedules) {
      final baseTaskId = task.id.startsWith('S-')
          ? task.id.substring(2)
          : task.id;
      for (int i = 0; i < task.schedules.length; i++) {
        final s = task.schedules[i];
        if (s is OneOffSchedule) {
          final startsDate = s.date.addDays(s.startRelativeTime.dayOffset);
          if (!today.isBefore(startsDate)) {
            list.add(
              TaskInstance(
                id: task.schedules.length <= 1
                    ? 'I-\${baseTaskId}_\${s.date}'
                    : 'I-\${baseTaskId}_\${s.date}_\$i',
                scheduleId: task.id,
                ruleId: s.id,
                title: task.title,
                description: task.description,
                scheduledDate: s.date,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        } else if (s is DailySchedule) {
          if (!today.isBefore(s.startDate)) {
            list.add(
              TaskInstance(
                id: task.schedules.length <= 1
                    ? 'I-\${baseTaskId}_\$today'
                    : 'I-\${baseTaskId}_\${today}_\$i',
                scheduleId: task.id,
                ruleId: s.id,
                title: task.title,
                description: task.description,
                scheduledDate: today,
                startRelativeTime: s.startRelativeTime,
                dueRelativeTime: s.dueRelativeTime,
                isFamily: task.isFamily,
                priority: task.priority,
                cycleId: task.cycleId,
                assignedUserId: task.assignedUserId,
                status: 'pending',
              ),
            );
          }
        }
      }
    }
    return list;
  }

  void updateInstances() {
    final list = mockInstancesFromSchedules(tasksSubject.value, AppClock.now);
    instancesSubject.add(list);
  }''',
    '''  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;''',
  );

  // 2. Change initial tasksSubject and instancesSubject setup
  content = content.replaceFirst(
    '''    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(initialTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(mockInstancesFromSchedules(initialTasks, AppClock.now));

    // Listen to changes to auto-update instances
    tasksSub = tasksSubject.listen((_) => updateInstances());
    clockListener = () => updateInstances();
    AppClock.timeNotifier.addListener(clockListener!);''',
    '''    final initialInstances = [
      TaskInstance(
        id: 'I-1_2024-01-01',
        scheduleId: '1',
        ruleId: initialTasks[0].schedules[0].id,
        title: 'Mock TaskSchedule',
        description: 'Mock Description',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      ),
    ];
    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(initialTasks);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(initialInstances);''',
  );

  // 3. Update addTaskSchedule mock
  content = content.replaceFirst(
    '''    when(mockTaskRepository.addTaskSchedule(any)).thenAnswer((
      invocation,
    ) async {
      final task = invocation.positionalArguments.first as TaskSchedule;
      final currentTasks = tasksSubject.value;
      tasksSubject.add([...currentTasks, task]);
    });''',
    '''    when(mockTaskRepository.addTaskSchedule(any)).thenAnswer((
      invocation,
    ) async {
      final task = invocation.positionalArguments.first as TaskSchedule;
      final currentTasks = tasksSubject.value;
      tasksSubject.add([...currentTasks, task]);
      
      final currentInstances = instancesSubject.value;
      instancesSubject.add([
        ...currentInstances,
        TaskInstance(
          id: 'I-\${task.id}_2026-03-08',
          scheduleId: task.id,
          ruleId: task.schedules.first.id,
          title: task.title,
          description: task.description,
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: task.schedules.first.startRelativeTime,
          dueRelativeTime: task.schedules.first.dueRelativeTime,
          status: 'pending',
        ),
      ]);
    });''',
  );

  // 4. Update tearDown
  content = content.replaceFirst(
    '''  tearDown(() {
    tasksSub?.cancel();
    if (clockListener != null) {
      AppClock.timeNotifier.removeListener(clockListener!);
    }
    tasksSub?.cancel();
    instancesSubject.close();
  });''',
    '''  tearDown(() {
    tasksSubject.close();
    instancesSubject.close();
  });''',
  );

  // 5. Update tests
  content = content.replaceFirst(
    '''      tasksSubject.add([recurringTask]);

      when(''',
    '''      tasksSubject.add([recurringTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-recur-1_2026-03-08',
          scheduleId: 'recur-1',
          ruleId: recurringTask.schedules.first.id,
          title: 'Daily Repeating TaskSchedule',
          description: 'Do daily',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      when(''',
  );

  content = content.replaceFirst(
    '''        tasksSubject.add([advancedTask]);
        return null;''',
    '''        tasksSubject.add([advancedTask]);
        instancesSubject.add([]);
        return null;''',
  );

  content = content.replaceFirst(
    '''      tasksSubject.add([todayTask, tomorrowTask]);

      await tester.pumpWidget(createScreen());''',
    '''      tasksSubject.add([todayTask, tomorrowTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-today-task_2026-03-08',
          scheduleId: 'today-task',
          ruleId: todayTask.schedules.first.id,
          title: 'Today TaskSchedule',
          description: 'Due today',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
        TaskInstance(
          id: 'I-tomorrow-task_2026-03-09',
          scheduleId: 'tomorrow-task',
          ruleId: tomorrowTask.schedules.first.id,
          title: 'Tomorrow TaskSchedule',
          description: 'Due tomorrow',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());''',
  );

  content = content.replaceFirst(
    '''      tasksSubject.add([activeOneOffTask]);

      await tester.pumpWidget(createScreen());''',
    '''      tasksSubject.add([activeOneOffTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-active-one-off_2026-03-09',
          scheduleId: 'active-one-off',
          ruleId: activeOneOffTask.schedules.first.id,
          title: 'Active One-Off',
          description: 'Starts today, due tomorrow',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 9),
          startRelativeTime: const RelativeTime(
            dayOffset: -1,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());''',
  );

  content = content.replaceFirst(
    '''      tasksSubject.add([snoozedOneOffTask]);

      await tester.pumpWidget(createScreen());''',
    '''      tasksSubject.add([snoozedOneOffTask]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-snoozed-one-off_2026-03-08',
          scheduleId: 'snoozed-one-off',
          ruleId: snoozedOneOffTask.schedules.first.id,
          title: 'Snoozed One-Off',
          description: 'Due today, starts tomorrow (snoozed)',
          scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
          startRelativeTime: const RelativeTime(
            dayOffset: 1,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      await tester.pumpWidget(createScreen());''',
  );

  content = content.replaceFirst(
    '''    tasksSubject.add([futureTodayTask]);

    await tester.pumpWidget(createScreen());''',
    '''    tasksSubject.add([futureTodayTask]);
    instancesSubject.add([
      TaskInstance(
        id: 'I-future-today-task_2026-03-08',
        scheduleId: 'future-today-task',
        ruleId: futureTodayTask.schedules.first.id,
        title: 'Future Today Task',
        description: 'Starts at 10 AM',
        scheduledDate: const CivilDay(year: 2026, month: 3, day: 8),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 10, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: 'pending',
      ),
    ]);

    await tester.pumpWidget(createScreen());''',
  );

  content = content.replaceFirst(
    '''      tasksSubject.add([task1, task2]);

      // Simulate deletion when completeTask is called
      when(
        mockTaskRepository.completeTaskInstance('I-1_2024-01-01'),
      ).thenAnswer((_) async {
        tasksSubject.add([task2]); // Remove task 1
        return null;
      });''',
    '''      tasksSubject.add([task1, task2]);
      instancesSubject.add([
        TaskInstance(
          id: 'I-1_2024-01-01',
          scheduleId: '1',
          ruleId: task1.schedules.first.id,
          title: 'TaskSchedule 1',
          description: 'Desc 1',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
        TaskInstance(
          id: 'I-2_2024-01-01',
          scheduleId: '2',
          ruleId: task2.schedules.first.id,
          title: 'TaskSchedule 2',
          description: 'Desc 2',
          scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          status: 'pending',
        ),
      ]);

      // Simulate deletion when completeTask is called
      when(
        mockTaskRepository.completeTaskInstance('I-1_2024-01-01'),
      ).thenAnswer((_) async {
        tasksSubject.add([task2]); // Remove task 1
        instancesSubject.add([
          TaskInstance(
            id: 'I-2_2024-01-01',
            scheduleId: '2',
            ruleId: task2.schedules.first.id,
            title: 'TaskSchedule 2',
            description: 'Desc 2',
            scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
            startRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
            dueRelativeTime: const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 17, minute: 0),
            ),
            status: 'pending',
          ),
        ]);
        return null;
      });''',
  );

  file.writeAsStringSync(content);
  print('Done.');
}
