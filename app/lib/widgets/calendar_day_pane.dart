import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_label.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/user_settings.dart';
import '../screens/create_task_screen.dart';
import 'app_snackbar.dart';
import 'calendar_day_timeline_view.dart';
import 'calendar_month_card.dart';
import 'calendar_task_details_sheet.dart';

/// Active display mode inside the split calendar day pane.
enum CalendarDayPaneMode { agenda, timeline }

/// Live selected-day pane paired with the month grid on [CalendarScreen].
///
/// Features an inline `Agenda | Timeline` toggle:
/// - **Agenda**: Spotlights one-off and rarer-than-weekly tasks at the top and
///   folds weekly-or-more-frequent routine tasks into a collapsible summary row.
/// - **Timeline**: Embeds the interactive 24-hour [CalendarDayTimelineView]
///   synchronized two-way with the selected day, with an option to expand full-screen.
class CalendarDayPane extends ConsumerStatefulWidget {
  final CivilDay selectedDay;
  final CivilDay today;
  final List<CalendarDayTask> dayTasks;
  final List<TaskInstance> instances;
  final List<TaskSchedule> schedules;
  final String? currentUserId;
  final Map<String, TaskLabel> labelsMap;
  final UserSettings? userSettings;
  final CalendarMonthTaskCache? monthTaskCache;
  final CalendarDayPaneMode mode;
  final ValueChanged<CalendarDayPaneMode> onModeChanged;
  final ValueChanged<CivilDay> onDayChanged;
  final VoidCallback? onExpandTimeline;

  const CalendarDayPane({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.dayTasks,
    required this.instances,
    required this.schedules,
    required this.currentUserId,
    required this.labelsMap,
    required this.userSettings,
    required this.monthTaskCache,
    required this.mode,
    required this.onModeChanged,
    required this.onDayChanged,
    this.onExpandTimeline,
  });

  @override
  ConsumerState<CalendarDayPane> createState() => _CalendarDayPaneState();
}

class _CalendarDayPaneState extends ConsumerState<CalendarDayPane> {
  bool _routinesExpanded = false;

  @override
  void didUpdateWidget(covariant CalendarDayPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _routinesExpanded = false;
    }
  }

  Future<void> _toggleTaskCompletion(CalendarDayTask task) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null || task.instance == null) return;
    try {
      if (task.isCompleted) {
        await repo.uncompleteTaskInstance(task.instance!.id);
      } else {
        await repo.completeTaskInstance(task.instance!.id);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          content: Text('${context.l10n.somethingWentWrong} $e'),
        );
      }
    }
  }

  String _formatRecurrenceTag(BuildContext context, CalendarDayTask task) {
    final l10n = context.l10n;
    final rule = task.effectiveRule;
    if (rule == null || rule is OneOffSchedule) {
      return l10n.oneOffLabel;
    }
    if (rule is YearlySchedule) {
      return l10n.yearlyLabel;
    }
    if (rule is MonthlySchedule) {
      return l10n.monthlyLabel;
    }
    if (rule is WeeklySchedule) {
      if (rule.interval > 1) {
        return l10n.everyNWeeks(rule.interval);
      }
      return l10n.weeklyLabel;
    }
    if (rule is DailySchedule) {
      if (rule.interval > 1) {
        return l10n.everyNDays(rule.interval);
      }
      return l10n.dailyLabel;
    }
    return l10n.oneOffLabel;
  }

  Color _resolveTaskAccentColor(
    BuildContext context,
    ThemeData theme,
    CalendarDayTask task,
  ) {
    final colorKey = task.primaryLabelColorKey(widget.labelsMap);
    if (colorKey != null) {
      return LabelPalette.getColor(colorKey, context);
    }
    return getPriorityColor(theme.colorScheme, task.priority);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final isToday = widget.selectedDay == widget.today;
    final isPast = widget.selectedDay.isBefore(widget.today);
    final capacityHours =
        widget.userSettings?.getCapacityForDate(
          widget.selectedDay.toDateTime(),
        ) ??
        4.0;
    final workload = CalendarDayWorkload.fromTasks(
      widget.dayTasks,
      capacityHours: capacityHours,
      labelsMap: widget.labelsMap,
      isPastDay: isPast,
    );

    final formattedDate = DateFormat.MMMEd(
      locale,
    ).format(widget.selectedDay.toDateTime());
    final capFormatted = CalendarDayWorkload.formatHoursCompact(
      (workload.effectiveCapacityHours * 60).round(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sticky Day Header with inline Agenda | Timeline toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            formattedDate,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workload.isEmpty
                          ? context.l10n.calendarNoTasks
                          : '${CalendarDayWorkload.formatHoursCompact(workload.totalMinutes)} / $capFormatted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: workload.isOverCapacity && !workload.allCompleted
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildModeToggle(context, theme),
              if (widget.mode == CalendarDayPaneMode.timeline &&
                  widget.onExpandTimeline != null)
                IconButton(
                  key: const Key('calendar_expand_timeline_button'),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.calendarExpandTimeline,
                  onPressed: widget.onExpandTimeline,
                ),
              IconButton(
                key: const Key('calendar_pane_add_task_button'),
                icon: const Icon(Icons.add_task, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.addTaskTooltip,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreateTaskScreen(defaultToRepeating: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        // Mode Content: Agenda or Embedded Timeline
        Expanded(
          child: widget.mode == CalendarDayPaneMode.agenda
              ? _buildAgendaBody(context, theme, workload)
              : CalendarDayTimelineView(
                  initialDay: widget.selectedDay,
                  onBackToMonth: () =>
                      widget.onModeChanged(CalendarDayPaneMode.agenda),
                  onDayChanged: widget.onDayChanged,
                  instances: widget.instances,
                  schedules: widget.schedules,
                  currentUserId: widget.currentUserId,
                  today: widget.today,
                  monthTaskCache: widget.monthTaskCache,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  Widget _buildModeToggle(BuildContext context, ThemeData theme) {
    final isAgenda = widget.mode == CalendarDayPaneMode.agenda;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModePillButton(
            key: const Key('calendar_mode_agenda_button'),
            label: context.l10n.calendarAgendaView,
            selected: isAgenda,
            onTap: () => widget.onModeChanged(CalendarDayPaneMode.agenda),
          ),
          _ModePillButton(
            key: const Key('calendar_mode_timeline_button'),
            label: context.l10n.calendarTimelineView,
            selected: !isAgenda,
            onTap: () => widget.onModeChanged(CalendarDayPaneMode.timeline),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaBody(
    BuildContext context,
    ThemeData theme,
    CalendarDayWorkload workload,
  ) {
    if (workload.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.calendarNoTasks,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      key: const Key('calendar_agenda_list'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // Highlighted (one-off / rarer than weekly) tasks
        if (workload.hasHighlightedTasks) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              context.l10n.calendarHighlightedSection.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final task in workload.highlightedTasks) ...[
            _buildTaskCard(context, theme, task, isRoutineCard: false),
            const SizedBox(height: 6),
          ],
          if (workload.hasRoutineTasks) const SizedBox(height: 6),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              context.l10n.calendarNoHighlightedTasks,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],

        // Collapsible Routine & Weekly summary row
        if (workload.hasRoutineTasks) ...[
          InkWell(
            key: const Key('calendar_routine_toggle'),
            onTap: () => setState(() => _routinesExpanded = !_routinesExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_repeat,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.calendarRoutineSectionCount(
                            workload.routineTasks.length,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        workload.formattedRoutineHours,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _routinesExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CalendarLabelCapacityBar(workload: workload, height: 3.5),
                ],
              ),
            ),
          ),
          if (_routinesExpanded) ...[
            const SizedBox(height: 8),
            for (final task in workload.routineTasks) ...[
              _buildTaskCard(context, theme, task, isRoutineCard: true),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    ThemeData theme,
    CalendarDayTask task, {
    required bool isRoutineCard,
  }) {
    final accentColor = _resolveTaskAccentColor(context, theme, task);
    final timeWindow = task.getTimeWindow(context);
    final durationLabel = CalendarDayWorkload.formatHoursCompact(
      task.effectiveDurationMinutes,
    );
    final recurrenceLabel = _formatRecurrenceTag(context, task);

    return Material(
      color: isRoutineCard
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('agenda_task_${task.id}'),
        onTap: () => CalendarTaskDetailsSheet.show(
          context,
          task: task,
          day: widget.selectedDay,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: task.isCompleted
                    ? theme.colorScheme.outline.withValues(alpha: 0.5)
                    : accentColor,
                width: isRoutineCard ? 3.0 : 4.0,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              if (task.isInstance)
                IconButton(
                  key: Key('agenda_task_toggle_${task.id}'),
                  icon: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: task.isCompleted
                        ? theme.colorScheme.primary
                        : accentColor,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _toggleTaskCompletion(task),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.event_repeat,
                    size: 18,
                    color: accentColor.withValues(alpha: 0.8),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isRoutineCard
                            ? FontWeight.w500
                            : FontWeight.w600,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [?timeWindow, recurrenceLabel].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (durationLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  durationLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePillButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
