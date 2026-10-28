import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/civil_day.dart';
import '../logic/task_schedule.dart';
import '../logic/task_instance.dart';
import '../logic/scheduler_engine.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings_repository.dart';
import '../logic/task_repository.dart';
import 'occurrence_card.dart';

export 'occurrence_card.dart' show FutureOccurrenceCard, PastOccurrenceCard;

enum _OccurrenceSectionKind { past, current, future }

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

  static String formatCivilDay(BuildContext context, CivilDay day) =>
      formatLocalizedCivilDay(context, day);

  static String formatDateTime(BuildContext context, DateTime dt) =>
      formatLocalizedDateTime(context, dt);
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

  DateTime _startDateTime(TaskInstance inst) =>
      inst.startRelativeTime.referenceTo(inst.scheduledDate);

  List<TaskInstance> _calculateFutureInstances(
    List<TaskInstance> currentInstances,
  ) {
    final futureInstances =
        currentInstances
            .where((inst) => widget.now.isBefore(_startDateTime(inst)))
            .toList()
          ..sort((a, b) => _startDateTime(a).compareTo(_startDateTime(b)));

    if (futureInstances.length > 10) {
      return futureInstances.sublist(0, 10);
    }
    return futureInstances;
  }

  List<TaskInstance> _calculateCurrentInstances(
    List<TaskInstance> currentInstances,
  ) {
    return currentInstances.where((inst) {
      final hasAppeared = !widget.now.isBefore(_startDateTime(inst));
      final isUnresolved =
          inst.status != TaskStatus.completed &&
          inst.status != TaskStatus.skipped;
      return hasAppeared && isUnresolved;
    }).toList()..sort((a, b) => _startDateTime(a).compareTo(_startDateTime(b)));
  }

  List<TaskInstance> _calculatePastInstances(
    List<TaskInstance> currentInstances,
  ) {
    final pastInstances = currentInstances.where((inst) {
      final hasAppeared = !widget.now.isBefore(_startDateTime(inst));
      final isResolved =
          inst.status == TaskStatus.completed ||
          inst.status == TaskStatus.skipped;
      return hasAppeared && isResolved;
    }).toList()..sort((a, b) => _startDateTime(b).compareTo(_startDateTime(a)));

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
      if (inst.scheduleId == widget.task.id &&
          inst.status == TaskStatus.pending) {
        continue;
      }
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
            kind: _OccurrenceSectionKind.past,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildColumnSection(
            context,
            title: context.l10n.currentTabLabel,
            instances: current,
            placeholder: context.l10n.noCurrentOccurrencesPlaceholder,
            kind: _OccurrenceSectionKind.current,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildColumnSection(
            context,
            title: context.l10n.futureTabLabel,
            instances: future,
            placeholder: context.l10n.noOccurrencesPlaceholder,
            kind: _OccurrenceSectionKind.future,
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
    switch (_tabController.index) {
      case 0:
        return _buildInstancesList(
          context,
          instances: past,
          placeholder: context.l10n.noPastOccurrencesPlaceholder,
          kind: _OccurrenceSectionKind.past,
        );
      case 1:
        return _buildInstancesList(
          context,
          instances: current,
          placeholder: context.l10n.noCurrentOccurrencesPlaceholder,
          kind: _OccurrenceSectionKind.current,
        );
      default:
        return _buildInstancesList(
          context,
          instances: future,
          placeholder: context.l10n.noOccurrencesPlaceholder,
          kind: _OccurrenceSectionKind.future,
        );
    }
  }

  Widget _buildColumnSection(
    BuildContext context, {
    required String title,
    required List<TaskInstance> instances,
    required String placeholder,
    required _OccurrenceSectionKind kind,
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
          kind: kind,
        ),
      ],
    );
  }

  Widget _buildInstancesList(
    BuildContext context, {
    required List<TaskInstance> instances,
    required String placeholder,
    required _OccurrenceSectionKind kind,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < instances.length; index++)
          switch (kind) {
            _OccurrenceSectionKind.past => PastOccurrenceCard(
              instance: instances[index],
              index: index,
              now: widget.now,
              keyPrefix: 'past',
            ),
            _OccurrenceSectionKind.current => PastOccurrenceCard(
              instance: instances[index],
              index: index,
              now: widget.now,
              keyPrefix: 'current',
            ),
            _OccurrenceSectionKind.future => FutureOccurrenceCard(
              instance: instances[index],
              index: index,
            ),
          },
      ],
    );
  }
}
