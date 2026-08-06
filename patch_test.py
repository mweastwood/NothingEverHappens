import sys

with open("app/test/widgets/task_widget_test.dart", "r") as f:
    content = f.read()

target1 = """    // Default completeTask/dismissTask/undoResolve to do nothing
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.dismissTaskInstance(any),
    ).thenAnswer((_) async => null);
    when(
      mockTaskRepository.undoResolveTaskInstance(any),
    ).thenAnswer((_) async {});"""

repl1 = """    // Default completeTask/dismissTask/undoResolve to do nothing
    when(
      mockTaskRepository.completeTaskInstance(any),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      return TaskInstance(
        id: id,
        scheduleId: 'S-mock',
        ruleId: 'R-mock',
        title: 'Mock Task',
        description: 'Mock Description',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
        dueRelativeTime: const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 17, minute: 0)),
        status: 'completed',
      );
    });
    when(
      mockTaskRepository.dismissTaskInstance(any),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      return TaskInstance(
        id: id,
        scheduleId: 'S-mock',
        ruleId: 'R-mock',
        title: 'Mock Task',
        description: 'Mock Description',
        scheduledDate: const CivilDay(year: 2024, month: 1, day: 1),
        startRelativeTime: const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
        dueRelativeTime: const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 17, minute: 0)),
        status: 'dismissed',
      );
    });
    when(
      mockTaskRepository.undoResolveTaskInstance(any),
    ).thenAnswer((_) async {});"""

target2 = """  testWidgets('TaskWidget delete action plays poof animation and deletes', (
    tester,
  ) async {
    when(
      mockTaskRepository.deleteTaskSchedule(any),
    ).thenAnswer((_) async => null);"""

repl2 = """  testWidgets('TaskWidget delete action plays poof animation and deletes', (
    tester,
  ) async {
    when(
      mockTaskRepository.deleteTaskSchedule(any),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      return (
        task: TaskSchedule(
          id: id,
          title: 'Mock Task',
          description: 'Mock Description',
        ),
        pendingInstances: <TaskInstance>[],
      );
    });"""

target3 = """    (tester) async {
      when(
        mockTaskRepository.deleteTaskSchedule(any),
      ).thenAnswer((_) async => null);"""

repl3 = """    (tester) async {
      when(
        mockTaskRepository.deleteTaskSchedule(any),
      ).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return (
          task: TaskSchedule(
            id: id,
            title: 'Mock Task',
            description: 'Mock Description',
          ),
          pendingInstances: <TaskInstance>[],
        );
      });"""

if target1 not in content or target2 not in content or target3 not in content:
    print("Could not find targets in file")
    sys.exit(1)

content = content.replace(target1, repl1)
content = content.replace(target2, repl2)
content = content.replace(target3, repl3)

with open("app/test/widgets/task_widget_test.dart", "w") as f:
    f.write(content)
print("Patched successfully")
