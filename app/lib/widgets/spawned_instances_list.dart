import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/civil_day.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/scheduler_engine.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings_repository.dart';
import '../logic/task_repository.dart';

class SpawnedInstancesList extends ConsumerStatefulWidget {
  final TaskSchedule task;
  final List<TaskInstance> dbInstances;
  final DateTime now;
  final int initialTabIndex;

  const SpawnedInstancesList({
    super.key,
    required this.task,
    required this.dbInstances,
    required this.now,
    this.initialTabIndex = 1,
  });

  @override
  ConsumerState<SpawnedInstancesList> createState() =>
      _SpawnedInstancesListState();

  static List<String> _getMonthNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
  }

  static List<String> _getWeekdayNames(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.weekdayMonday,
      l10n.weekdayTuesday,
      l10n.weekdayWednesday,
      l10n.weekdayThursday,
      l10n.weekdayFriday,
      l10n.weekdaySaturday,
      l10n.weekdaySunday,
    ];
  }

  static String formatCivilDay(BuildContext context, CivilDay day) {
    final dt = day.toDateTime();
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[day.month - 1];
    return '$weekdayStr, $monthStr ${day.day}, ${day.year}';
  }

  static String formatDateTime(BuildContext context, DateTime dt) {
    final weekdayStr = _getWeekdayNames(context)[dt.weekday - 1];
    final monthStr = _getMonthNames(context)[dt.month - 1];
    final timeStr = TimeOfDay.fromDateTime(dt).format(context);
    return '$weekdayStr, $monthStr ${dt.day}, ${dt.year} $timeStr';
  }
}

class _SpawnedInstancesListState extends ConsumerState<SpawnedInstancesList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskInstance> _calculateFutureInstances(
    List<TaskInstance> currentInstances,
  ) {
    final futureInstances = currentInstances.where((inst) {
      final startDateTime = inst.startRelativeTime.referenceTo(
        inst.scheduledDate,
      );
      return widget.now.isBefore(startDateTime);
    }).toList();

    futureInstances.sort((a, b) {
      final startA = a.startRelativeTime.referenceTo(a.scheduledDate);
      final startB = b.startRelativeTime.referenceTo(b.scheduledDate);
      return startA.compareTo(startB);
    });

    if (futureInstances.length > 10) {
      return futureInstances.sublist(0, 10);
    }
    return futureInstances;
  }

  List<TaskInstance> _calculateCurrentInstances(
    List<TaskInstance> currentInstances,
  ) {
    final activeInstances = currentInstances.where((inst) {
      final startDateTime = inst.startRelativeTime.referenceTo(
        inst.scheduledDate,
      );
      final hasAppeared = !widget.now.isBefore(startDateTime);
      final isUnresolved =
          inst.status != TaskStatus.completed &&
          inst.status != TaskStatus.skipped;
      return hasAppeared && isUnresolved;
    }).toList();

    activeInstances.sort((a, b) {
      final startA = a.startRelativeTime.referenceTo(a.scheduledDate);
      final startB = b.startRelativeTime.referenceTo(b.scheduledDate);
      return startA.compareTo(startB);
    });

    return activeInstances;
  }

  List<TaskInstance> _calculatePastInstances(
    List<TaskInstance> currentInstances,
  ) {
    final pastInstances = currentInstances.where((inst) {
      final startDateTime = inst.startRelativeTime.referenceTo(
        inst.scheduledDate,
      );
      final hasAppeared = !widget.now.isBefore(startDateTime);
      final isResolved =
          inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped;
      return hasAppeared && isResolved;
    }).toList();

    pastInstances.sort((a, b) {
      final startA = a.startRelativeTime.referenceTo(a.scheduledDate);
      final startB = b.startRelativeTime.referenceTo(b.scheduledDate);
      return startB.compareTo(startA);
    });

    if (pastInstances.length > 10) {
      return pastInstances.sublist(0, 10);
    }
    return pastInstances;
  }

  @override
  Widget build(BuildContext context) {
    final settingsVal = ref.watch(userSettingsProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final instancesVal = ref.watch(taskInstancesProvider);

    final userSettings = settingsVal.value;
    final allTasks = schedulesVal.value ?? [];
    final allInstances = instancesVal.value ?? [];

    final taskMap = {for (final t in allTasks) t.id: t};
    final Map<CivilDay, double> dayPlannedHours = {};
    for (final inst in allInstances) {
      if (inst.status != TaskStatus.skipped &&
          inst.status != TaskStatus.failed) {
        final t = taskMap[inst.scheduleId];
        if (t != null && t.estimatedDuration != null) {
          final hours = t.estimatedDuration!.inMinutes / 60.0;
          dayPlannedHours[inst.scheduledDate] =
              (dayPlannedHours[inst.scheduledDate] ?? 0.0) + hours;
        }
      }
    }

    final action = const SchedulerEngine().evaluate(
      widget.task,
      widget.dbInstances,
      widget.now,
      userSettings: userSettings,
      dayPlannedHours: dayPlannedHours,
    );

    final Set<String> toDeleteIds = action.instancesToDelete.toSet();
    final Map<String, TaskInstance> toUpdateMap = {
      for (final inst in action.instancesToUpdate) inst.id: inst,
    };

    final List<TaskInstance> currentInstances = [];
    for (final inst in widget.dbInstances) {
      if (toDeleteIds.contains(inst.id)) continue;
      if (toUpdateMap.containsKey(inst.id)) {
        currentInstances.add(toUpdateMap[inst.id]!);
      } else {
        currentInstances.add(inst);
      }
    }
    currentInstances.addAll(action.instancesToSpawn);

    final futureInstances = _calculateFutureInstances(currentInstances);
    final currentActiveInstances = _calculateCurrentInstances(currentInstances);
    final pastInstances = _calculatePastInstances(currentInstances);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return _buildWideLayout(
            context,
            pastInstances,
            currentActiveInstances,
            futureInstances,
          );
        } else {
          return _buildNarrowLayout(
            context,
            pastInstances,
            currentActiveInstances,
            futureInstances,
          );
        }
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    List<TaskInstance> past,
    List<TaskInstance> current,
    List<TaskInstance> future,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildColumnSection(
            context,
            title: context.l10n.pastTabLabel,
            instances: past,
            placeholder: context.l10n.noPastOccurrencesPlaceholder,
            isPast: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildColumnSection(
            context,
            title: context.l10n.currentTabLabel,
            instances: current,
            placeholder: context.l10n.noCurrentOccurrencesPlaceholder,
            isCurrent: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildColumnSection(
            context,
            title: context.l10n.futureTabLabel,
            instances: future,
            placeholder: context.l10n.noOccurrencesPlaceholder,
            isFuture: true,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    List<TaskInstance> past,
    List<TaskInstance> current,
    List<TaskInstance> future,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.pastTabLabel),
            Tab(text: context.l10n.currentTabLabel),
            Tab(text: context.l10n.futureTabLabel),
          ],
        ),
        const SizedBox(height: 16),
        _buildActiveTabContent(context, past, current, future),
      ],
    );
  }

  Widget _buildActiveTabContent(
    BuildContext context,
    List<TaskInstance> past,
    List<TaskInstance> current,
    List<TaskInstance> future,
  ) {
    final selectedIndex = _tabController.index;
    if (selectedIndex == 0) {
      return _buildInstancesList(
        context,
        instances: past,
        placeholder: context.l10n.noPastOccurrencesPlaceholder,
        isPast: true,
      );
    } else if (selectedIndex == 1) {
      return _buildInstancesList(
        context,
        instances: current,
        placeholder: context.l10n.noCurrentOccurrencesPlaceholder,
        isCurrent: true,
      );
    } else {
      return _buildInstancesList(
        context,
        instances: future,
        placeholder: context.l10n.noOccurrencesPlaceholder,
        isFuture: true,
      );
    }
  }

  Widget _buildColumnSection(
    BuildContext context, {
    required String title,
    required List<TaskInstance> instances,
    required String placeholder,
    bool isPast = false,
    bool isCurrent = false,
    bool isFuture = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildInstancesList(
          context,
          instances: instances,
          placeholder: placeholder,
          isPast: isPast,
          isCurrent: isCurrent,
          isFuture: isFuture,
        ),
      ],
    );
  }

  Widget _buildInstancesList(
    BuildContext context, {
    required List<TaskInstance> instances,
    required String placeholder,
    bool isPast = false,
    bool isCurrent = false,
    bool isFuture = false,
  }) {
    final theme = Theme.of(context);
    if (instances.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          placeholder,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: instances.length,
      itemBuilder: (context, index) {
        if (isPast) {
          return PastOccurrenceCard(
            instance: instances[index],
            index: index,
            now: widget.now,
            keyPrefix: 'past',
          );
        } else if (isCurrent) {
          return PastOccurrenceCard(
            instance: instances[index],
            index: index,
            now: widget.now,
            keyPrefix: 'current',
          );
        } else {
          return FutureOccurrenceCard(instance: instances[index], index: index);
        }
      },
    );
  }
}

class FutureOccurrenceCard extends StatelessWidget {
  final TaskInstance instance;
  final int index;

  const FutureOccurrenceCard({
    super.key,
    required this.instance,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = instance.scheduledDate;
    final startAbs = instance.startRelativeTime.referenceTo(occurrence);
    final dueAbs = instance.dueRelativeTime.referenceTo(occurrence);

    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.visibility, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.occurrenceAppears(
                  SpawnedInstancesList.formatDateTime(context, startAbs),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.alarm, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.occurrenceDue(
                  SpawnedInstancesList.formatDateTime(context, dueAbs),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      key: Key('spawned_occurrence_card_$index'),
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          SpawnedInstancesList.formatCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}

class PastOccurrenceCard extends StatelessWidget {
  final TaskInstance instance;
  final int index;
  final DateTime now;
  final String keyPrefix;

  const PastOccurrenceCard({
    super.key,
    required this.instance,
    required this.index,
    required this.now,
    this.keyPrefix = 'past',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = instance.scheduledDate;
    final dueAbs = instance.dueRelativeTime.referenceTo(occurrence);

    final String statusText;
    final IconData iconData;
    final Color color;

    if (instance.status == TaskStatus.completed) {
      final formattedCompletedAt = instance.completedAt != null
          ? SpawnedInstancesList.formatDateTime(context, instance.completedAt!)
          : '';
      statusText = context.l10n.occurrenceCompleted(formattedCompletedAt);
      iconData = Icons.check_circle;
      color = Colors.green;
    } else if (instance.status == TaskStatus.skipped) {
      statusText = context.l10n.occurrenceSkipped;
      iconData = Icons.skip_next;
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      if (now.isBefore(dueAbs)) {
        final formattedDueAbs = SpawnedInstancesList.formatDateTime(
          context,
          dueAbs,
        );
        statusText = context.l10n.occurrenceActive(formattedDueAbs);
        iconData = Icons.play_circle_outline;
        color = theme.colorScheme.primary;
      } else {
        final formattedDueAbs = SpawnedInstancesList.formatDateTime(
          context,
          dueAbs,
        );
        statusText = context.l10n.occurrenceMissed(formattedDueAbs);
        iconData = Icons.alarm;
        color = theme.colorScheme.error;
      }
    }

    final detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(iconData, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      key: Key('${keyPrefix}_occurrence_card_$index'),
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(iconData, color: color),
        ),
        title: Text(
          SpawnedInstancesList.formatCivilDay(context, occurrence),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: detailsWidget,
      ),
    );
  }
}
