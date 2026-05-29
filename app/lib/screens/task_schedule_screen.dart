import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
import 'create_task_screen.dart';
import '../logic/l10n_extension.dart';

class TaskScheduleScreen extends StatelessWidget {
  const TaskScheduleScreen({super.key});

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

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
              : StreamBuilder<List<Task>>(
                  stream: taskRepository.getTasks(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('${context.l10n?.errorOccurred ?? 'Error'}: ${snapshot.error}'));
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
                                    context.l10n?.noRecurringTasksScheduled ?? 'No recurring tasks scheduled',
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
                            return _buildScheduleCard(
                              context,
                              taskRepository,
                              task,
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

  Widget _buildScheduleCard(
    BuildContext context,
    TaskRepository taskRepository,
    Task task,
  ) {
    String intervalStr = '';
    String startStr = '';
    String daysStr = '';

    if (task.schedule is DailySchedule) {
      final ds = task.schedule as DailySchedule;
      intervalStr = ds.interval == 1
          ? (context.l10n?.everyDay ?? 'Every day')
          : (context.l10n?.everyNDays(ds.interval) ?? 'Every ${ds.interval} days');
      final dateStr = '${ds.startDate.year}-${ds.startDate.month.toString().padLeft(2, '0')}-${ds.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n?.startingDate(dateStr) ?? 'Starting: $dateStr';
    } else if (task.schedule is WeeklySchedule) {
      final ws = task.schedule as WeeklySchedule;
      intervalStr = ws.interval == 1
          ? (context.l10n?.everyWeek ?? 'Every week')
          : (context.l10n?.everyNWeeks(ws.interval) ?? 'Every ${ws.interval} weeks');
      final dateStr = '${ws.startDate.year}-${ws.startDate.month.toString().padLeft(2, '0')}-${ws.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n?.startingDate(dateStr) ?? 'Starting: $dateStr';

      final dayNames = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
      final selectedDays = ws.daysOfWeek.toList()..sort();
      final joinedDays = selectedDays.map((d) => dayNames[d]).join(', ');
      daysStr = context.l10n?.onDaysOfWeek(joinedDays) ?? 'On: $joinedDays';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('edit_schedule_button_${task.id}'),
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: context.l10n?.editScheduleTooltip ?? 'Edit Schedule',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateTaskScreen(taskToEdit: task),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      key: Key('delete_schedule_button_${task.id}'),
                      icon: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: context.l10n?.deleteTaskTooltip ?? 'Delete Task',
                      onPressed: () =>
                          _confirmDelete(context, taskRepository, task),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.schedule is DailySchedule
                            ? (context.l10n?.dailyRecurrence ?? 'Daily')
                            : (context.l10n?.weeklyRecurrence ?? 'Weekly'),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              MarkdownBody(data: task.description, selectable: true),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  intervalStr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (task.schedule is WeeklySchedule) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    daysStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.play_arrow_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  startStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n?.dailyOccurrencesHeader ?? 'Daily Occurrences:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            if (task.dailyTimes.isNotEmpty)
              ...task.dailyTimes.map(
                (time) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatTimeOfDay(time.startTime)} - ${_formatTimeOfDay(time.dueTime)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTimeOfDay(task.startRelativeTime.time)} - ${_formatTimeOfDay(task.dueRelativeTime.time)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
          title: Text(context.l10n?.deleteTaskConfirmTitle ?? 'Delete Task?'),
          content: Text(
            context.l10n?.deleteTaskConfirmBody(task.title) ??
                'Are you sure you want to delete "${task.title}"? This action will permanently remove the task.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n?.cancelButton ?? 'Cancel'),
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
              child: Text(context.l10n?.deleteButton ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
