import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../logic/task_instance.dart';
import '../logic/task_schedule.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/utils/layout_breakpoints.dart';
import 'create_task_screen.dart';

/// Unified representation of a task scheduled for a specific day on the calendar.
class CalendarDayTask {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isInstance;
  final TaskInstance? instance;
  final TaskSchedule? schedule;
  final String? timeWindow;

  const CalendarDayTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.priority,
    this.status = TaskStatus.pending,
    required this.isInstance,
    this.instance,
    this.schedule,
    this.timeWindow,
  });

  bool get isCompleted => status == TaskStatus.completed;
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ScrollController _scrollController;
  late final DateTime _initialNow;
  late final List<DateTime> _months;
  late final int _currentMonthIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initialNow = AppClock.now;

    // Generate 12 months in the past to 24 months in the future
    _months = [];
    const pastMonths = 12;
    const futureMonths = 24;

    for (int i = -pastMonths; i <= futureMonths; i++) {
      _months.add(DateTime(_initialNow.year, _initialNow.month + i, 1));
    }
    _currentMonthIndex = pastMonths;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final isWide = isWideScreen(context);
    // Approximate card height
    final targetRow = isWide ? (_currentMonthIndex ~/ 2) : _currentMonthIndex;
    final estimatedRowHeight = isWide ? 420.0 : 380.0;
    final targetOffset = (targetRow * estimatedRowHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  Map<CivilDay, List<CalendarDayTask>> _buildDayTaskMap(
    List<TaskInstance> instances,
    List<TaskSchedule> schedules,
    BuildContext context,
  ) {
    final Map<CivilDay, List<CalendarDayTask>> map = {};

    // 1. Concrete instances
    final Set<String> instanceScheduleDateKeys = {};
    for (final inst in instances) {
      if (inst.status == TaskStatus.skipped ||
          inst.status == TaskStatus.failed) {
        continue;
      }
      instanceScheduleDateKeys.add('${inst.scheduleId}_${inst.scheduledDate}');

      final startTod = TimeOfDay(
        hour: inst.startRelativeTime.hour,
        minute: inst.startRelativeTime.minute,
      );
      final dueTod = TimeOfDay(
        hour: inst.dueRelativeTime.hour,
        minute: inst.dueRelativeTime.minute,
      );
      final startTimeStr = startTod.format(context);
      final dueTimeStr = dueTod.format(context);
      final timeWindow = '$startTimeStr – $dueTimeStr';

      final task = CalendarDayTask(
        id: inst.id,
        title: inst.title,
        description: inst.description,
        priority: inst.priority,
        status: inst.status,
        isInstance: true,
        instance: inst,
        timeWindow: timeWindow,
      );

      map.putIfAbsent(inst.scheduledDate, () => []).add(task);
    }

    // 2. Projected recurring schedules that do not have an instance for that day
    for (final monthDate in _months) {
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
      for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
        final civilDay = CivilDay(
          year: monthDate.year,
          month: monthDate.month,
          day: dayNum,
        );

        for (final sched in schedules) {
          final key = '${sched.id}_$civilDay';
          if (instanceScheduleDateKeys.contains(key)) {
            continue; // Already has concrete instance
          }

          final matchingRule = sched.schedules
              .cast<TaskScheduleRule?>()
              .firstWhere(
                (r) => r != null && r.occursOn(civilDay),
                orElse: () => null,
              );

          if (matchingRule != null) {
            final startTod = TimeOfDay(
              hour: matchingRule.startRelativeTime.hour,
              minute: matchingRule.startRelativeTime.minute,
            );
            final dueTod = TimeOfDay(
              hour: matchingRule.dueRelativeTime.hour,
              minute: matchingRule.dueRelativeTime.minute,
            );
            final startTimeStr = startTod.format(context);
            final dueTimeStr = dueTod.format(context);
            final timeWindow = '$startTimeStr – $dueTimeStr';

            final task = CalendarDayTask(
              id: 'projected_${sched.id}_$civilDay',
              title: sched.title,
              description: sched.description,
              priority: sched.priority,
              status: TaskStatus.pending,
              isInstance: false,
              schedule: sched,
              timeWindow: timeWindow,
            );

            map.putIfAbsent(civilDay, () => []).add(task);
          }
        }
      }
    }

    // Sort tasks in each day: high priority first, then medium, then low
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.priority.index.compareTo(a.priority.index);
      });
    }

    return map;
  }

  void _showDayDetailsSheet(
    BuildContext context,
    CivilDay day,
    List<CalendarDayTask> tasks,
  ) {
    final theme = Theme.of(context);
    final dt = day.toDateTime();
    final formattedDate = DateFormat.yMMMMEEEEd().format(dt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sheet Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tasks.isEmpty
                                    ? context.l10n.calendarNoTasks
                                    : '${tasks.length} ${tasks.length == 1 ? "task" : "tasks"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          tooltip: context.l10n.addTaskTooltip,
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateTaskScreen(
                                  defaultToRepeating: false,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Tasks List
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          context.l10n.calendarNoTasks,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final priorityColor = _getPriorityColor(
                            theme.colorScheme,
                            task.priority,
                          );

                          return Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: priorityColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: task.isInstance
                                  ? IconButton(
                                      icon: Icon(
                                        task.isCompleted
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: task.isCompleted
                                            ? theme.colorScheme.primary
                                            : priorityColor,
                                      ),
                                      onPressed: () async {
                                        final repo = ref.read(
                                          taskRepositoryProvider,
                                        );
                                        if (repo != null &&
                                            task.instance != null) {
                                          if (task.isCompleted) {
                                            await repo.uncompleteTaskInstance(
                                              task.instance!.id,
                                            );
                                          } else {
                                            await repo.completeTaskInstance(
                                              task.instance!.id,
                                            );
                                          }
                                        }
                                        if (bottomSheetContext.mounted) {
                                          Navigator.pop(bottomSheetContext);
                                        }
                                      },
                                    )
                                  : Icon(
                                      Icons.event_repeat,
                                      color: priorityColor,
                                    ),
                              title: Text(
                                task.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        )
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task.timeWindow != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      task.timeWindow!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      task.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: priorityColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task.priority.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: priorityColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(ColorScheme colorScheme, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return colorScheme.error;
      case TaskPriority.medium:
        return colorScheme.primary;
      case TaskPriority.low:
        return colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final instancesVal = ref.watch(taskInstancesProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);

    if (instancesVal.isLoading || schedulesVal.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final instances = instancesVal.value ?? [];
    final schedules = schedulesVal.value ?? [];
    final dayTaskMap = _buildDayTaskMap(instances, schedules, context);

    final isWide = isWideScreen(context);
    final theme = Theme.of(context);
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);

    return Stack(
      children: [
        isWide
            ? _buildWideMonthList(dayTaskMap, today, theme)
            : _buildNarrowMonthList(dayTaskMap, today, theme),
        Positioned(
          right: 16,
          bottom: 16,
          child: IconButton.filledTonal(
            key: const Key('calendar_jump_to_today_button'),
            tooltip: context.l10n.calendarJumpToToday,
            iconSize: 22,
            onPressed: () => _scrollToCurrentMonth(animate: true),
            icon: const Icon(Icons.today),
          ),
        ),
      ],
    );
  }

  Widget _buildWideMonthList(
    Map<CivilDay, List<CalendarDayTask>> dayTaskMap,
    CivilDay today,
    ThemeData theme,
  ) {
    final rowCount = (_months.length / 2).ceil();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final idx1 = rowIndex * 2;
        final idx2 = idx1 + 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMonthCard(
                  _months[idx1],
                  dayTaskMap,
                  today,
                  theme,
                  isWide: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: idx2 < _months.length
                    ? _buildMonthCard(
                        _months[idx2],
                        dayTaskMap,
                        today,
                        theme,
                        isWide: true,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNarrowMonthList(
    Map<CivilDay, List<CalendarDayTask>> dayTaskMap,
    CivilDay today,
    ThemeData theme,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildMonthCard(
            _months[index],
            dayTaskMap,
            today,
            theme,
            isWide: false,
          ),
        );
      },
    );
  }

  Widget _buildMonthCard(
    DateTime monthDate,
    Map<CivilDay, List<CalendarDayTask>> dayTaskMap,
    CivilDay today,
    ThemeData theme, {
    required bool isWide,
  }) {
    final monthTitle = DateFormat.yMMMM().format(monthDate);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(
      monthDate.year,
      monthDate.month,
      1,
    ).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = firstWeekday - 1;

    final totalSlots = leadingEmptyCount + daysInMonth;
    final rowCount = (totalSlots / 7).ceil();

    final isCurrentMonth =
        monthDate.year == today.year && monthDate.month == today.month;

    return Card(
      key: Key('month_card_${monthDate.year}_${monthDate.month}'),
      elevation: isCurrentMonth ? 2.5 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentMonth
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              )
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      monthTitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCurrentMonth
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                  if (isCurrentMonth)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.calendarJumpToToday,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Weekday Headers (M, T, W, T, F, S, S)
            Row(
              children: [
                for (final dayLabel in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        dayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 4),
            // Calendar Day Grid
            for (int r = 0; r < rowCount; r++) ...[
              SizedBox(
                height: isWide ? 62.0 : 54.0,
                child: Row(
                  children: [
                    for (int c = 0; c < 7; c++) ...[
                      Expanded(
                        child: _buildDayCellSlot(
                          r,
                          c,
                          leadingEmptyCount,
                          daysInMonth,
                          monthDate,
                          dayTaskMap,
                          today,
                          theme,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayCellSlot(
    int row,
    int col,
    int leadingEmptyCount,
    int daysInMonth,
    DateTime monthDate,
    Map<CivilDay, List<CalendarDayTask>> dayTaskMap,
    CivilDay today,
    ThemeData theme,
  ) {
    final slotIndex = row * 7 + col;
    final dayNum = slotIndex - leadingEmptyCount + 1;

    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox.shrink();
    }

    final civilDay = CivilDay(
      year: monthDate.year,
      month: monthDate.month,
      day: dayNum,
    );
    final isToday = civilDay == today;
    final tasks = dayTaskMap[civilDay] ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          onTap: () => _showDayDetailsSheet(context, civilDay, tasks),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isToday
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : (tasks.isNotEmpty
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          )
                        : null),
              border: isToday
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : (tasks.isNotEmpty
                        ? Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                            width: 0.5,
                          )
                        : null),
            ),
            child: _buildResponsiveDayContent(
              constraints,
              dayNum,
              isToday,
              tasks,
              theme,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveDayContent(
    BoxConstraints constraints,
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    // Determine level of detail depending on available space:
    // Tier 1: Wide & tall cell (e.g. >= 60 width && >= 50 height)
    // Tier 2: Medium cell (>= 42 width && >= 42 height)
    // Tier 3: Compact cell (< 42 width or < 42 height)
    final bool isTier1 = width >= 60 && height >= 50;
    final bool isTier2 = !isTier1 && width >= 42 && height >= 42;

    if (isTier1) {
      return _buildTier1Day(dayNum, isToday, tasks, theme);
    } else if (isTier2) {
      return _buildTier2Day(dayNum, isToday, tasks, theme);
    } else {
      return _buildTier3Day(dayNum, isToday, tasks, theme);
    }
  }

  /// Tier 1: Wide space -> Day number + truncated task title chips with priority indicators
  Widget _buildTier1Day(
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day number row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (tasks.isNotEmpty)
                Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          // Task chips
          if (tasks.isNotEmpty) ...[
            for (int i = 0; i < (tasks.length > 2 ? 1 : tasks.length); i++) ...[
              _buildTaskChip(tasks[i], theme, showText: true),
              const SizedBox(height: 1),
            ],
            if (tasks.length > 2)
              Text(
                '+${tasks.length - 1} more',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Tier 2: Medium space -> Day number + compact task pills
  Widget _buildTier2Day(
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Spacer(),
          if (tasks.isNotEmpty) ...[
            _buildTaskChip(tasks[0], theme, showText: true),
            if (tasks.length > 1)
              Center(
                child: Text(
                  '+${tasks.length - 1}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  /// Tier 3: Compact space -> Day number + colored priority dots
  Widget _buildTier3Day(
    int dayNum,
    bool isToday,
    List<CalendarDayTask> tasks,
    ThemeData theme,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$dayNum',
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? theme.colorScheme.primary : null,
          ),
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                int i = 0;
                i < (tasks.length > 3 ? 3 : tasks.length);
                i++
              ) ...[
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tasks[i].isCompleted
                        ? theme.colorScheme.outline
                        : _getPriorityColor(
                            theme.colorScheme,
                            tasks[i].priority,
                          ),
                  ),
                ),
              ],
              if (tasks.length > 3)
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTaskChip(
    CalendarDayTask task,
    ThemeData theme, {
    required bool showText,
  }) {
    final color = _getPriorityColor(theme.colorScheme, task.priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: task.isCompleted ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? theme.colorScheme.outline : color,
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
