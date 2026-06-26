import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/task_repository.dart';
import 'create_task_screen.dart';
import '../logic/l10n_extension.dart';
import '../logic/undo_notifier.dart';
import '../widgets/undo_snackbar.dart';
import '../logic/user_settings_repository.dart';

final scheduleSearchQueryProvider = StateProvider<String>((ref) => '');

class TaskScheduleScreen extends ConsumerStatefulWidget {
  const TaskScheduleScreen({super.key});

  @override
  ConsumerState<TaskScheduleScreen> createState() => _TaskScheduleScreenState();
}

class _TaskScheduleScreenState extends ConsumerState<TaskScheduleScreen> {
  final List<({String column, bool ascending})> _sortHistory = [
    (column: 'title', ascending: true),
  ];

  String get _sortColumn =>
      _sortHistory.isNotEmpty ? _sortHistory.first.column : 'title';
  bool get _sortAscending =>
      _sortHistory.isNotEmpty ? _sortHistory.first.ascending : true;

  void _onSort(String column) {
    setState(() {
      bool ascending = true;
      if (_sortHistory.isNotEmpty && _sortHistory.first.column == column) {
        ascending = !_sortHistory.first.ascending;
        _sortHistory.removeAt(0);
      } else {
        _sortHistory.removeWhere((element) => element.column == column);
      }

      _sortHistory.insert(0, (column: column, ascending: ascending));

      if (_sortHistory.length > 3) {
        _sortHistory.removeLast();
      }
    });
  }

  DateTime? _getNextStartTime(TaskSchedule task) {
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);
    DateTime? earliest;

    for (final s in task.schedules) {
      CivilDay? nextDay;
      if (s.occursOn(today)) {
        nextDay = today;
      } else {
        nextDay = s.nextOccurrenceAfter(today);
      }
      if (nextDay != null) {
        final dt = s.startRelativeTime.referenceTo(nextDay);
        if (earliest == null || dt.isBefore(earliest)) {
          earliest = dt;
        }
      }
    }
    return earliest;
  }

  DateTime? _getNextDueTime(TaskSchedule task) {
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);
    DateTime? earliest;

    for (final s in task.schedules) {
      CivilDay? nextDay;
      if (s.occursOn(today)) {
        nextDay = today;
      } else {
        nextDay = s.nextOccurrenceAfter(today);
      }
      if (nextDay != null) {
        final dt = s.dueRelativeTime.referenceTo(nextDay);
        if (earliest == null || dt.isBefore(earliest)) {
          earliest = dt;
        }
      }
    }
    return earliest;
  }

  int _compareDateTimes(DateTime? a, DateTime? b, bool ascending) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // Put nulls at the end
    if (b == null) return -1; // Put nulls at the end
    final comp = a.compareTo(b);
    return ascending ? comp : -comp;
  }

  int _compareTasks(
    TaskSchedule a,
    TaskSchedule b,
    String column,
    bool ascending,
  ) {
    if (column == 'next_start') {
      return _compareDateTimes(
        _getNextStartTime(a),
        _getNextStartTime(b),
        ascending,
      );
    } else if (column == 'next_due') {
      return _compareDateTimes(
        _getNextDueTime(a),
        _getNextDueTime(b),
        ascending,
      );
    }

    int result = 0;
    if (column == 'title') {
      result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    } else if (column == 'priority') {
      result = a.priority.index.compareTo(b.priority.index);
    }
    return ascending ? result : -result;
  }

  String _getRecurrenceRuleTypeName(
    BuildContext context,
    TaskScheduleRule? schedule,
  ) {
    if (schedule == null) return '';
    if (schedule is DailySchedule) return context.l10n.dailyLabel;
    if (schedule is WeeklySchedule) return context.l10n.weeklyLabel;
    if (schedule is MonthlySchedule) return context.l10n.monthlyLabel;
    if (schedule is YearlySchedule) return context.l10n.yearlyLabel;
    return context.l10n.oneOffLabel;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  ({String interval, String days, String start}) _getRecurrenceRuleDetails(
    BuildContext context,
    TaskScheduleRule? schedule,
  ) {
    if (schedule == null) return (interval: '', days: '', start: '');

    String intervalStr = '';
    String startStr = '';
    String daysStr = '';

    if (schedule is OneOffSchedule) {
      final dateStr =
          '${schedule.date.year}-${schedule.date.month.toString().padLeft(2, '0')}-${schedule.date.day.toString().padLeft(2, '0')}';
      intervalStr = context.l10n.oneOffLabel;
      startStr = context.l10n.startingDate(dateStr);
    } else if (schedule is DailySchedule) {
      final ds = schedule;
      intervalStr = ds.interval == 1
          ? context.l10n.everyDay
          : context.l10n.everyNDays(ds.interval);
      final dateStr =
          '${ds.startDate.year}-${ds.startDate.month.toString().padLeft(2, '0')}-${ds.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);
    } else if (schedule is WeeklySchedule) {
      final ws = schedule;
      intervalStr = ws.interval == 1
          ? context.l10n.everyWeek
          : context.l10n.everyNWeeks(ws.interval);
      final dateStr =
          '${ws.startDate.year}-${ws.startDate.month.toString().padLeft(2, '0')}-${ws.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

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
      final joinedDays = selectedDays.map((d) => dayNames[d] ?? '').join(', ');
      daysStr = context.l10n.onDaysOfWeek(joinedDays);
    } else if (schedule is MonthlySchedule) {
      final ms = schedule;
      intervalStr = ms.interval == 1
          ? context.l10n.everyMonth
          : context.l10n.everyNMonths(ms.interval);
      final dateStr =
          '${ms.startDate.year}-${ms.startDate.month.toString().padLeft(2, '0')}-${ms.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      if (ms.dayOfMonth != null) {
        if (ms.dayOfMonth! > 0) {
          daysStr = context.l10n.dayOfMonthOnDay(ms.dayOfMonth!);
        } else {
          daysStr = context.l10n.dayOfMonthFromEnd(ms.dayOfMonth!.abs());
        }
      } else {
        final occurrenceNames = {
          1: context.l10n.firstOccurrence,
          2: context.l10n.secondOccurrence,
          3: context.l10n.thirdOccurrence,
          4: context.l10n.fourthOccurrence,
          -1: context.l10n.lastOccurrence,
        };
        final dayOfWeekNames = {
          1: 'Monday',
          2: 'Tuesday',
          3: 'Wednesday',
          4: 'Thursday',
          5: 'Friday',
          6: 'Saturday',
          7: 'Sunday',
        };
        final occStr = occurrenceNames[ms.occurrence] ?? '';
        final dowStr = dayOfWeekNames[ms.dayOfWeek] ?? '';
        daysStr = context.l10n.nthDayOfWeekOccurrence(occStr, dowStr);
      }
    } else if (schedule is YearlySchedule) {
      final ys = schedule;
      intervalStr = ys.interval == 1
          ? context.l10n.everyYear
          : context.l10n.everyNYears(ys.interval);
      final dateStr =
          '${ys.startDate.year}-${ys.startDate.month.toString().padLeft(2, '0')}-${ys.startDate.day.toString().padLeft(2, '0')}';
      startStr = context.l10n.startingDate(dateStr);

      final monthNames = {
        1: 'January',
        2: 'February',
        3: 'March',
        4: 'April',
        5: 'May',
        6: 'June',
        7: 'July',
        8: 'August',
        9: 'September',
        10: 'October',
        11: 'November',
        12: 'December',
      };
      final mStr = monthNames[ys.month] ?? '';
      daysStr = context.l10n.yearlyOn(mStr, ys.day);
    }

    return (interval: intervalStr, days: daysStr, start: startStr);
  }

  String _getRecurrenceRuleTimeWindowString(TaskScheduleRule? schedule) {
    if (schedule == null) return '';
    return '${_formatTimeOfDay(schedule.startRelativeTime.time)} - ${_formatTimeOfDay(schedule.dueRelativeTime.time)}';
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskRepository = ref.watch(taskRepositoryProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final settingsVal = ref.watch(userSettingsProvider);
    final searchQuery = ref
        .watch(scheduleSearchQueryProvider)
        .trim()
        .toLowerCase();
    final theme = Theme.of(context);

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
              : settingsVal.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('${context.l10n.errorOccurred}: $err'),
                  ),
                  data: (settings) => schedulesVal.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text('${context.l10n.errorOccurred}: $err'),
                    ),
                    data: (allTasks) {
                      final showLastSpawnedDate = settings.showLastSpawnedDate;
                      final recurringTasks = allTasks
                          .where(
                            (task) =>
                                task.schedules.any((s) => s is! OneOffSchedule),
                          )
                          .toList();

                      // Filter based on search query
                      final filteredTasks = recurringTasks.where((task) {
                        if (searchQuery.isEmpty) return true;
                        final queryWords = searchQuery
                            .split(RegExp(r'\s+'))
                            .where((word) => word.isNotEmpty);
                        if (queryWords.isEmpty) return true;

                        return queryWords.every((word) {
                          final matchesTitle = task.title
                              .toLowerCase()
                              .contains(word);
                          final matchesDesc = task.description
                              .toLowerCase()
                              .contains(word);
                          return matchesTitle || matchesDesc;
                        });
                      }).toList();

                      if (recurringTasks.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      if (filteredTasks.isEmpty && searchQuery.isNotEmpty) {
                        return _buildNoMatchesState(context);
                      }

                      // Sort filtered tasks using sort history (stable multi-key sort)
                      final originalIndices = {
                        for (int i = 0; i < filteredTasks.length; i++)
                          filteredTasks[i].id: i,
                      };
                      filteredTasks.sort((a, b) {
                        for (final sort in _sortHistory) {
                          final result = _compareTasks(
                            a,
                            b,
                            sort.column,
                            sort.ascending,
                          );
                          if (result != 0) return result;
                        }
                        final indexA = originalIndices[a.id] ?? 0;
                        final indexB = originalIndices[b.id] ?? 0;
                        return indexA.compareTo(indexB);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sort bar at the top
                          _buildSortBar(context, theme),
                          const Divider(height: 1, thickness: 0.5),
                          // Scrollable list of task cards
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, index) {
                                final task = filteredTasks[index];
                                return _buildTaskCard(
                                  context,
                                  task,
                                  theme,
                                  taskRepository,
                                  showLastSpawnedDate,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSortBar(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 48.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            Text(
              context.l10n.scheduleSortByLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: Text(context.l10n.titleFieldLabel),
              selected: _sortColumn == 'title',
              showCheckmark: false,
              avatar: _sortColumn == 'title'
                  ? Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                    )
                  : null,
              onSelected: (_) => _onSort('title'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.l10n.scheduleSortNextStartLabel),
              selected: _sortColumn == 'next_start',
              showCheckmark: false,
              avatar: _sortColumn == 'next_start'
                  ? Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                    )
                  : null,
              onSelected: (_) => _onSort('next_start'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.l10n.scheduleSortNextDueLabel),
              selected: _sortColumn == 'next_due',
              showCheckmark: false,
              avatar: _sortColumn == 'next_due'
                  ? Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                    )
                  : null,
              onSelected: (_) => _onSort('next_due'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.l10n.taskPriorityLabel),
              selected: _sortColumn == 'priority',
              showCheckmark: false,
              avatar: _sortColumn == 'priority'
                  ? Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                    )
                  : null,
              onSelected: (_) => _onSort('priority'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskSchedule task,
    ThemeData theme,
    TaskRepository repository,
    bool showLastSpawnedDate,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with Title, priority, actions (high density)
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 4.0,
              top: 8.0,
              bottom: 0.0,
            ),
            child: Row(
              children: [
                // Priority bullet dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('edit_schedule_button_${task.id}'),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.editScheduleTooltip,
                  onPressed: () {
                    SystemNavigator.routeInformationUpdated(
                      uri: Uri.parse('/edit/${task.id}'),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateTaskScreen(taskToEdit: task),
                      ),
                    ).then((_) {
                      SystemNavigator.routeInformationUpdated(
                        uri: Uri.parse('/schedules'),
                      );
                    });
                  },
                ),
                IconButton(
                  key: Key('delete_schedule_button_${task.id}'),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.deleteTaskTooltip,
                  onPressed: () =>
                      _confirmDelete(context, ref, repository, task),
                ),
              ],
            ),
          ),
          if (task.description.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 28.0,
                right: 12.0,
                bottom: 8.0,
              ),
              child: MarkdownBody(
                data: task.description,
                selectable: false,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                  pPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
          if (showLastSpawnedDate)
            Padding(
              padding: const EdgeInsets.only(
                left: 28.0,
                right: 12.0,
                bottom: 8.0,
              ),
              child: Text(
                'lastSpawnedDate: ${task.lastSpawnedDate?.toString() ?? "null"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.0,
                  height: 1.2,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          const Divider(height: 1, thickness: 0.5),
          // Rule list inside task card (high density)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: task.schedules.length,
            separatorBuilder: (context, _) =>
                const Divider(height: 1, indent: 12, endIndent: 12),
            itemBuilder: (context, idx) {
              final rule = task.schedules[idx];
              final parts = _getRecurrenceRuleDetails(context, rule);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recurrence Type
                        Expanded(
                          flex: 2,
                          child: Text(
                            _getRecurrenceRuleTypeName(context, rule),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Details
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parts.interval,
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (parts.days.isNotEmpty)
                                Text(
                                  parts.days,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (parts.start.isNotEmpty)
                                Text(
                                  parts.start,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              if (isNarrow) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getRecurrenceRuleTimeWindowString(rule),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(width: 8),
                          // Time Window
                          Expanded(
                            flex: 3,
                            child: Text(
                              _getRecurrenceRuleTimeWindowString(rule),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildNoMatchesState(BuildContext context) {
    final query = ref.read(scheduleSearchQueryProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.noSchedulesMatching(query),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.read(scheduleSearchQueryProvider.notifier).state = '';
            },
            child: Text(context.l10n.clearSearchButton),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TaskRepository repository,
    TaskSchedule task,
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
              onPressed: () async {
                Navigator.pop(dialogContext);
                final deletedData = await repository.deleteTaskSchedule(
                  task.id,
                );
                if (deletedData != null && context.mounted) {
                  UndoSnackBar.show(
                    context: context,
                    ref: ref,
                    action: UndoDeleteTaskScheduleAction(
                      message: context.l10n.scheduleDeleted(task.title),
                      schedule: deletedData.task,
                      pendingInstances: deletedData.pendingInstances,
                    ),
                    repository: repository,
                    undoneLabel: context.l10n.taskRestored(task.title),
                  );
                }
              },
              child: Text(context.l10n.deleteButton),
            ),
          ],
        );
      },
    );
  }
}
