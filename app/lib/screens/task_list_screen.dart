import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/task_schedule.dart';
import '../widgets/task_widget.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');

  @override
  Widget build(BuildContext context) {
    final taskRepository = ref.watch(taskRepositoryProvider);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;

        return Padding(
          padding: EdgeInsets.only(
            bottom: isMocked ? 60.0 : 0.0,
          ), // Avoid overlap with dev clock banner
          child: taskRepository == null
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  key: const PageStorageKey('tasksView'),
                  center: _taskListKey,
                  slivers: [_buildTaskListSliver(taskRepository)],
                ),
        );
      },
    );
  }

  Widget _buildTaskListSliver(TaskRepository taskRepository) {
    return StreamBuilder<List<TaskSchedule>>(
      key: _taskListKey,
      stream: taskRepository.getTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text('${context.l10n.errorOccurred}: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final today = CivilDay.fromDateTime(AppClock.now);
        final tasks = (snapshot.data ?? [])
            .where(
              (t) =>
                  !t.isMaster &&
                  (t.startDate == today || t.startDate.isBefore(today)),
            )
            .toList();

        if (tasks.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: Text(context.l10n.noTasksYet)),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTaskItem(tasks[index]),
              childCount: tasks.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(TaskSchedule task) {
    return TaskWidget(key: ValueKey(task.id), task: task);
  }
}
