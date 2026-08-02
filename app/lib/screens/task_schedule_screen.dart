import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import 'create_task_screen.dart';
import '../logic/l10n_extension.dart';
import '../logic/undo_notifier.dart';
import '../widgets/undo_snackbar.dart';
import '../logic/user_settings_repository.dart';
import '../logic/user_settings.dart';
import '../logic/sort_helper.dart';
import '../widgets/sort_bar.dart';

final scheduleSearchQueryProvider = StateProvider<String>((ref) => '');

class TaskScheduleScreen extends ConsumerStatefulWidget {
  const TaskScheduleScreen({super.key});

  @override
  ConsumerState<TaskScheduleScreen> createState() => _TaskScheduleScreenState();
}

class _TaskScheduleScreenState extends ConsumerState<TaskScheduleScreen> {
  List<({String column, bool ascending})>? _localSortHistory;

  List<({String column, bool ascending})> _getSortHistory(
    UserSettings settings,
  ) {
    if (_localSortHistory != null) {
      return _localSortHistory!;
    }
    return settings.scheduleListSort ??
        const [(column: 'title', ascending: true)];
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

  int _compareTasks(
    TaskSchedule a,
    TaskSchedule b,
    String column,
    bool ascending,
  ) {
    if (column == 'next_start') {
      return compareDateTimes(
        _getNextStartTime(a),
        _getNextStartTime(b),
        ascending,
      );
    } else if (column == 'next_due') {
      return compareDateTimes(
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

  String _formatRelativeTime(BuildContext context, RelativeTime rt) {
    final formattedTime = rt.time.format(context);
    if (rt.dayOffset > 0) {
      return '$formattedTime (+${rt.dayOffset})';
    } else if (rt.dayOffset < 0) {
      return '$formattedTime (${rt.dayOffset})';
    }
    return formattedTime;
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
        1: context.l10n.weekdayShortMonday,
        2: context.l10n.weekdayShortTuesday,
        3: context.l10n.weekdayShortWednesday,
        4: context.l10n.weekdayShortThursday,
        5: context.l10n.weekdayShortFriday,
        6: context.l10n.weekdayShortSaturday,
        7: context.l10n.weekdayShortSunday,
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
          1: context.l10n.weekdayMonday,
          2: context.l10n.weekdayTuesday,
          3: context.l10n.weekdayWednesday,
          4: context.l10n.weekdayThursday,
          5: context.l10n.weekdayFriday,
          6: context.l10n.weekdaySaturday,
          7: context.l10n.weekdaySunday,
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
        1: context.l10n.monthJanuary,
        2: context.l10n.monthFebruary,
        3: context.l10n.monthMarch,
        4: context.l10n.monthApril,
        5: context.l10n.monthMay,
        6: context.l10n.monthJune,
        7: context.l10n.monthJuly,
        8: context.l10n.monthAugust,
        9: context.l10n.monthSeptember,
        10: context.l10n.monthOctober,
        11: context.l10n.monthNovember,
        12: context.l10n.monthDecember,
      };
      final mStr = monthNames[ys.month] ?? '';
      daysStr = context.l10n.yearlyOn(mStr, ys.day);
    }

    return (interval: intervalStr, days: daysStr, start: startStr);
  }

  String _getMissedPolicyString(BuildContext context, TaskScheduleRule rule) {
    if (rule is OneOffSchedule) return '';
    final policy = rule.missedOccurrencePolicy;
    switch (policy.policy) {
      case MissedPolicy.preferNewer:
        return context.l10n.preferNewerTitle;
      case MissedPolicy.preferOlder:
        return context.l10n.preferOlderTitle;
      case MissedPolicy.stack:
        return context.l10n.stackPolicyTitle;
      case MissedPolicy.autoDismiss:
        final minutes = policy.gracePeriod.inMinutes;
        if (minutes == 0) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.immediatelyPolicy})';
        } else if (minutes == 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.oneHourPolicy})';
        } else if (minutes == 6 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.sixHoursPolicy})';
        } else if (minutes == 12 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twelveHoursPolicy})';
        } else if (minutes == 24 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twentyFourHoursPolicy})';
        } else if (minutes % (7 * 24 * 60) == 0) {
          final weeks = minutes ~/ (7 * 24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($weeks ${context.l10n.unitWeeks})';
        } else if (minutes % (24 * 60) == 0) {
          final days = minutes ~/ (24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($days ${context.l10n.unitDays})';
        } else if (minutes % 60 == 0) {
          final hours = minutes ~/ 60;
          return '${context.l10n.autoDismissPolicyTitle} ($hours ${context.l10n.unitHours})';
        } else {
          return '${context.l10n.autoDismissPolicyTitle} ($minutes ${context.l10n.unitMinutes})';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskRepository = ref.watch(taskRepositoryProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final settingsVal = ref.watch(userSettingsProvider);
    final settingsRepository = ref.watch(userSettingsRepositoryProvider);
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
                  data: (settings) {
                    final sortHistory = _getSortHistory(settings);
                    final sortColumn = sortHistory.isNotEmpty
                        ? sortHistory.first.column
                        : 'title';
                    final sortAscending = sortHistory.isNotEmpty
                        ? sortHistory.first.ascending
                        : true;

                    void onSort(String column) {
                      final updatedSort = updateSortHistory(
                        sortHistory,
                        column,
                      );
                      setState(() {
                        _localSortHistory = updatedSort;
                      });
                      if (settingsRepository != null) {
                        settingsRepository.updateSettings(
                          settings.copyWith(scheduleListSort: updatedSort),
                        );
                      }
                    }

                    return schedulesVal.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(
                        child: Text('${context.l10n.errorOccurred}: $err'),
                      ),
                      data: (allTasks) {
                        final showLastSpawnedDate =
                            settings.showLastSpawnedDate;
                        final recurringTasks = allTasks
                            .where(
                              (task) => task.schedules.any(
                                (s) => s is! OneOffSchedule,
                              ),
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
                          for (final sort in sortHistory) {
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

                        final isSortBarVisible = ref.watch(showSortBarProvider);

                        return Stack(
                          children: [
                            ListView.builder(
                              padding: EdgeInsets.only(
                                top: isSortBarVisible ? 60.0 : 8.0,
                                bottom: 80.0,
                              ),
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
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedFloatingSortBar(
                                visible: isSortBarVisible,
                                child: FloatingSortCard(
                                  child: SortBar(
                                    title: context.l10n.scheduleSortByLabel,
                                    sortColumn: sortColumn,
                                    sortAscending: sortAscending,
                                    options: [
                                      SortOption(
                                        key: 'title',
                                        label: context.l10n.titleFieldLabel,
                                      ),
                                      SortOption(
                                        key: 'next_start',
                                        label: context
                                            .l10n
                                            .scheduleSortNextStartLabel,
                                      ),
                                      SortOption(
                                        key: 'next_due',
                                        label: context
                                            .l10n
                                            .scheduleSortNextDueLabel,
                                      ),
                                      SortOption(
                                        key: 'priority',
                                        label: context.l10n.taskPriorityLabel,
                                      ),
                                    ],
                                    onSort: onSort,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskSchedule task,
    ThemeData theme,
    TaskRepository repository,
    bool showLastSpawnedDate,
  ) {
    String formatDuration(Duration duration) {
      final minutes = duration.inMinutes;
      if (minutes <= 0) return '';
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (hours > 0) {
        final hourStr = hours == 1 ? '1 hr' : '$hours hrs';
        final minStr = remainingMinutes > 0 ? '$remainingMinutes min' : '';
        return minStr.isEmpty ? hourStr : '$hourStr $minStr';
      } else {
        return '$minutes min';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
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
                left: 12.0,
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
          if (task.estimatedDuration != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 8.0,
              ),
              child: Text(
                context.l10n.estimatedEffortLabel(
                  formatDuration(task.estimatedDuration!),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ),
          if (showLastSpawnedDate)
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
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

              String freqText = _getRecurrenceRuleTypeName(context, rule);
              int interval = 1;
              if (rule is DailySchedule) {
                interval = rule.interval;
              } else if (rule is WeeklySchedule) {
                interval = rule.interval;
              } else if (rule is MonthlySchedule) {
                interval = rule.interval;
              } else if (rule is YearlySchedule) {
                interval = rule.interval;
              }
              if (interval > 1) {
                freqText = '$freqText (${parts.interval})';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            freqText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (parts.days.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              parts.days,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Column 2
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                rule.schedulingPolicy
                                        is CompletionRelativePolicy
                                    ? Icons.sync
                                    : Icons.calendar_today,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  rule.schedulingPolicy
                                          is CompletionRelativePolicy
                                      ? context.l10n.completionRelativeLabel
                                      : context.l10n.fixedCalendarLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (rule is! OneOffSchedule &&
                              rule.schedulingPolicy
                                  is! CompletionRelativePolicy) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_late_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getMissedPolicyString(context, rule),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_formatRelativeTime(context, rule.startRelativeTime)} -- ${_formatRelativeTime(context, rule.dueRelativeTime)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
