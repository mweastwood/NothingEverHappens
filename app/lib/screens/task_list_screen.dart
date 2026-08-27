import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/auth_repository.dart';
import '../widgets/task_widget.dart';
import 'home_screen.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/task_instance.dart';
import '../logic/sort_helper.dart';
import '../widgets/sort_bar.dart';
import '../widgets/unsynced_banner.dart';
import '../widgets/system_task_widget.dart';
import '../logic/system_tasks/system_task.dart';
import '../logic/system_tasks/system_task_providers.dart';

import '../logic/utils/layout_breakpoints.dart';

final taskSearchQueryProvider = StateProvider<String>((ref) => '');

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _columnAffinity = {};
  Timer? _rebuildTimer;
  List<({String column, bool ascending})>? _localSortHistory;

  List<({String column, bool ascending})> _getSortHistory(
    UserSettings settings,
  ) {
    if (_localSortHistory != null) {
      return _localSortHistory!;
    }
    return settings.taskListSort ?? const [(column: 'title', ascending: true)];
  }

  int _compareInstances(
    TaskInstance a,
    TaskInstance b,
    String column,
    bool ascending,
  ) {
    if (column == 'next_due') {
      final aDue = a.dueRelativeTime.referenceTo(a.scheduledDate);
      final bDue = b.dueRelativeTime.referenceTo(b.scheduledDate);
      return compareDateTimes(aDue, bDue, ascending);
    }

    int result = 0;
    if (column == 'title') {
      result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    } else if (column == 'priority') {
      result = a.priority.index.compareTo(b.priority.index);
    }
    return ascending ? result : -result;
  }

  @override
  void initState() {
    super.initState();
    _rebuildTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(showTaskListSortBarProvider, (previous, next) {
      if (previous != next && _scrollController.hasClients) {
        final offset = _scrollController.offset;
        const barHeight = 64.0;
        if (next && offset > 5.0) {
          _scrollController.jumpTo(offset + barHeight);
        } else if (!next && offset > barHeight + 5.0) {
          _scrollController.jumpTo(offset - barHeight);
        }
      }
    });

    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;
        final currentUserId = ref.watch(authStateProvider).value?.uid;
        final schedulesVal = ref.watch(taskSchedulesProvider);
        final instancesVal = ref.watch(taskInstancesProvider);
        final settingsVal = ref.watch(userSettingsProvider);
        final settingsRepository = ref.watch(userSettingsRepositoryProvider);
        final searchQuery = ref
            .watch(taskSearchQueryProvider)
            .trim()
            .toLowerCase();

        final settings =
            settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);
        final sortHistory = _getSortHistory(settings);
        final sortColumn = sortHistory.isNotEmpty
            ? sortHistory.first.column
            : 'title';
        final sortAscending = sortHistory.isNotEmpty
            ? sortHistory.first.ascending
            : true;

        void onSort(String column) {
          final updatedSort = updateSortHistory(sortHistory, column);
          setState(() {
            _localSortHistory = updatedSort;
          });
          if (settingsRepository != null) {
            settingsRepository.updateSettings(
              settings.copyWith(taskListSort: updatedSort),
            );
          }
        }

        Widget bodySliver;
        if (schedulesVal.isLoading ||
            instancesVal.isLoading ||
            settingsVal.isLoading) {
          bodySliver = const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (schedulesVal.hasError ||
            instancesVal.hasError ||
            settingsVal.hasError) {
          final err =
              schedulesVal.error ?? instancesVal.error ?? settingsVal.error;
          bodySliver = SliverToBoxAdapter(
            child: Center(child: Text('${context.l10n.errorOccurred}: $err')),
          );
        } else {
          final schedules = schedulesVal.value ?? [];
          final instances = instancesVal.value ?? [];

          final filteredInstances = instances.where((inst) {
            final startDateTime = inst.startRelativeTime.referenceTo(
              inst.scheduledDate,
            );
            final isFuture = AppClock.now.isBefore(startDateTime);
            final isPending = inst.status == TaskStatus.pending && !isFuture;
            if (!isPending) return false;
            if (currentUserId != null &&
                inst.isCompletedForUser(currentUserId)) {
              return false;
            }
            if (inst.assignedUserId != null &&
                inst.assignedUserId != currentUserId) {
              return false;
            }
            if (searchQuery.isEmpty) return true;

            final queryWords = searchQuery
                .split(RegExp(r'\s+'))
                .where((word) => word.isNotEmpty);
            if (queryWords.isEmpty) return true;

            return queryWords.every((word) {
              final matchesTitle = inst.title.toLowerCase().contains(word);
              final matchesDesc = inst.description.toLowerCase().contains(word);
              return matchesTitle || matchesDesc;
            });
          }).toList();

          // Sort filtered instances using sort history (stable multi-key sort)
          final originalIndices = {
            for (int i = 0; i < filteredInstances.length; i++)
              filteredInstances[i].id: i,
          };
          filteredInstances.sort((a, b) {
            for (final sort in sortHistory) {
              final result = _compareInstances(
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

          if (filteredInstances.isEmpty) {
            if (searchQuery.isNotEmpty) {
              bodySliver = SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.noTasksMatching(
                            ref.read(taskSearchQueryProvider),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.read(taskSearchQueryProvider.notifier).state =
                                '';
                          },
                          child: Text(context.l10n.clearSearchButton),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              bodySliver = SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(child: Text(context.l10n.noTasksYet)),
                ),
              );
            }
          } else {
            Widget buildTaskItem(TaskInstance inst) {
              final matchingSchedules = schedules.where(
                (s) => s.id == inst.scheduleId,
              );
              final sched = matchingSchedules.isEmpty
                  ? null
                  : matchingSchedules.first;
              return TaskWidget(
                key: ValueKey(inst.id),
                instance: inst,
                schedule: sched,
              );
            }

            final isWide = isWideScreen(context);
            if (isWide) {
              final List<TaskInstance> leftColumnInstances = [];
              final List<TaskInstance> rightColumnInstances = [];

              final currentIds = filteredInstances.map((e) => e.id).toSet();
              _columnAffinity.removeWhere((id, _) => !currentIds.contains(id));

              for (final inst in filteredInstances) {
                int? col = _columnAffinity[inst.id];
                if (col == null) {
                  col =
                      leftColumnInstances.length <= rightColumnInstances.length
                      ? 0
                      : 1;
                  _columnAffinity[inst.id] = col;
                }
                if (col == 0) {
                  leftColumnInstances.add(inst);
                } else {
                  rightColumnInstances.add(inst);
                }
              }

              bodySliver = SliverPadding(
                padding: const EdgeInsets.all(8.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final inst in leftColumnInstances)
                              buildTaskItem(inst),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final inst in rightColumnInstances)
                              buildTaskItem(inst),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              bodySliver = SliverPadding(
                padding: const EdgeInsets.all(8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final inst = filteredInstances[index];
                    return buildTaskItem(inst);
                  }, childCount: filteredInstances.length),
                ),
              );
            }
          }
        }

        final showSortBar =
            instancesVal.hasValue && (instancesVal.value ?? []).isNotEmpty;

        final isSortBarVisible = ref.watch(showTaskListSortBarProvider);

        return Padding(
          padding: EdgeInsets.only(
            bottom: isMocked ? 60.0 : 0.0,
          ), // Avoid overlap with dev clock banner
          child: Stack(
            children: [
              Builder(
                builder: (context) {
                  String getWeekIdentifier(DateTime date) {
                    final monday = date.subtract(
                      Duration(days: date.weekday - 1),
                    );
                    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
                  }

                  final today = AppClock.now;
                  final currentWeekId = getWeekIdentifier(today);
                  final isConfirmed =
                      settings.lastCapacityConfirmedWeek == currentWeekId;
                  final showCapacityPrompt =
                      !settingsVal.isLoading &&
                      !settingsVal.hasError &&
                      !isConfirmed;
                  return CustomScrollView(
                    key: const PageStorageKey('tasksView'),
                    controller: _scrollController,
                    slivers: [
                      const SliverToBoxAdapter(child: UnsyncedBanner()),
                      SliverToBoxAdapter(
                        child: AnimatedContainer(
                          duration:
                              (_scrollController.hasClients &&
                                  _scrollController.offset > 5.0)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          height: (showSortBar && isSortBarVisible)
                              ? ((showCapacityPrompt && searchQuery.isEmpty)
                                    ? 64.0
                                    : 60.0)
                              : 0.0,
                        ),
                      ),
                      if (showCapacityPrompt && searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: SystemTaskWidget(
                              key: const Key('capacity_prompt_card'),
                              task: SystemTask(
                                id: 'verify_weekly_capacity',
                                title: context.l10n.capacityPromptTitle,
                                description:
                                    context.l10n.capacityPromptSubtitle,
                                icon: Icons.assignment_late,
                                priority: SystemTaskPriority.high,
                                category: SystemTaskCategory.capacity,
                                onTap: () {
                                  ref
                                          .read(homeTabIndexProvider.notifier)
                                          .state =
                                      2; // Switch to Dashboard Tab
                                },
                              ),
                              variant: SystemTaskWidgetVariant.banner,
                            ),
                          ),
                        ),
                      if (searchQuery.isEmpty)
                        for (final familyTask
                            in ref
                                .watch(activeSystemTasksProvider)
                                .where(
                                  (t) =>
                                      t.category == SystemTaskCategory.family,
                                ))
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: SystemTaskWidget(
                                key: Key('system_task_${familyTask.id}'),
                                task: familyTask,
                                variant: SystemTaskWidgetVariant.card,
                              ),
                            ),
                          ),
                      SliverPadding(
                        key: _taskListKey,
                        padding: const EdgeInsets.only(bottom: 80.0),
                        sliver: bodySliver,
                      ),
                    ],
                  );
                },
              ),
              if (showSortBar)
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
                            key: 'next_due',
                            label: context.l10n.scheduleSortNextDueLabel,
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
          ),
        );
      },
    );
  }
}
