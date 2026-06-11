import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
import 'create_task_screen.dart';
import '../logic/l10n_extension.dart';
import '../widgets/schedule_card.dart';

class TaskScheduleScreen extends ConsumerWidget {
  const TaskScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              : StreamBuilder<List<Task>>(
                  stream: taskRepository.getTasks(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '${context.l10n.errorOccurred}: ${snapshot.error}',
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTasks = snapshot.data ?? [];
                    final recurringTasks = allTasks
                        .where((task) => task.schedule is! OneOffSchedule)
                        .toList();

                    if (recurringTasks.isEmpty) {
                      return CustomScrollView(
                        key: const PageStorageKey('scheduleView'),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.l10n.noRecurringTasksScheduled,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return CustomScrollView(
                      key: const PageStorageKey('scheduleView'),
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final task = recurringTasks[index];
                            return ScheduleCard(
                              task: task,
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateTaskScreen(taskToEdit: task),
                                  ),
                                );
                              },
                              onDelete: () =>
                                  _confirmDelete(context, taskRepository, task),
                            );
                          }, childCount: recurringTasks.length),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    TaskRepository repository,
    Task task,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.deleteTaskConfirmTitle),
          content: Text(context.l10n.deleteTaskConfirmBody(task.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancelButton),
            ),
            FilledButton(
              key: Key('confirm_delete_schedule_button_${task.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                repository.deleteTask(task.id);
              },
              child: Text(context.l10n.deleteButton),
            ),
          ],
        );
      },
    );
  }
}
