import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task.dart';
import '../widgets/task_widget.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');

  @override
  Widget build(BuildContext context) {
    final taskRepository = Provider.of<TaskRepository?>(context);

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
    return StreamBuilder<List<Task>>(
      key: _taskListKey,
      stream: taskRepository.getTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                '${context.l10n?.errorOccurred ?? 'Error'}: ${snapshot.error}',
              ),
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

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  context.l10n?.noTasksYet ?? 'No tasks yet. Add one!',
                ),
              ),
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

  Widget _buildTaskItem(Task task) {
    return TaskWidget(key: ValueKey(task.id), task: task);
  }
}
