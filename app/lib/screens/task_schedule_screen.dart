import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

import '../logic/task_schedule.dart';
import '../logic/civil_day.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings_repository.dart';
import '../logic/user_settings.dart';
import '../logic/sort_helper.dart';
import '../widgets/sort_bar.dart';
import '../widgets/unsynced_banner.dart';
import '../logic/family_repository.dart';
import '../widgets/task_schedule_card.dart';
import '../logic/utils/layout_breakpoints.dart';
import '../logic/utils/masonry_layout_helper.dart';

final scheduleSearchQueryProvider = StateProvider<String>((ref) => '');

class TaskScheduleScreen extends ConsumerStatefulWidget {
  const TaskScheduleScreen({super.key});

  @override
  ConsumerState<TaskScheduleScreen> createState() => _TaskScheduleScreenState();
}

class _TaskScheduleScreenState extends ConsumerState<TaskScheduleScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _columnAffinity = {};
  List<({String column, bool ascending})>? _localSortHistory;

  List<TaskSchedule>? _cachedAllTasks;
  String? _cachedSearchQuery;
  String? _cachedSortHistoryString;
  DateTime? _cachedMockTime;
  List<TaskSchedule> _cachedSortedTasks = [];

  List<TaskSchedule> _getSortedFilteredTasks(
    List<TaskSchedule> allTasks,
    String searchQuery,
    List<({String column, bool ascending})> sortHistory,
    DateTime? mockTime,
  ) {
    final sortHistoryString = sortHistory.toString();
    if (_cachedAllTasks == allTasks &&
        _cachedSearchQuery == searchQuery &&
        _cachedSortHistoryString == sortHistoryString &&
        _cachedMockTime == mockTime) {
      return _cachedSortedTasks;
    }

    final recurringTasks = allTasks
        .where((task) => task.schedules.any((s) => s is! OneOffSchedule))
        .toList();

    final filteredTasks = recurringTasks.where((task) {
      if (searchQuery.isEmpty) return true;
      final queryWords = searchQuery
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty);
      if (queryWords.isEmpty) return true;

      return queryWords.every((word) {
        final matchesTitle = task.title.toLowerCase().contains(word);
        final matchesDesc = task.description.toLowerCase().contains(word);
        return matchesTitle || matchesDesc;
      });
    }).toList();

    final originalIndices = {
      for (int i = 0; i < filteredTasks.length; i++) filteredTasks[i].id: i,
    };

    filteredTasks.sort((a, b) {
      for (final sort in sortHistory) {
        final result = _compareTasks(a, b, sort.column, sort.ascending);
        if (result != 0) return result;
      }
      final indexA = originalIndices[a.id] ?? 0;
      final indexB = originalIndices[b.id] ?? 0;
      return indexA.compareTo(indexB);
    });

    _cachedAllTasks = allTasks;
    _cachedSearchQuery = searchQuery;
    _cachedSortHistoryString = sortHistoryString;
    _cachedMockTime = mockTime;
    _cachedSortedTasks = filteredTasks;

    return filteredTasks;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(showScheduleListSortBarProvider, (previous, next) {
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

    final taskRepository = ref.watch(taskRepositoryProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final settingsVal = ref.watch(userSettingsProvider);
    final settingsRepository = ref.watch(userSettingsRepositoryProvider);
    final familyProfileVal = ref.watch(familyProfileStreamProvider);
    final isParent = familyProfileVal.value?.familyRole == 'parent';
    final searchQuery = ref
        .watch(scheduleSearchQueryProvider)
        .trim()
        .toLowerCase();

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
                        _columnAffinity.clear();
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
                        final hasRecurringTasks = allTasks.any(
                          (task) =>
                              task.schedules.any((s) => s is! OneOffSchedule),
                        );

                        if (!hasRecurringTasks) {
                          return _buildEmptyState(context);
                        }

                        final filteredTasks = _getSortedFilteredTasks(
                          allTasks,
                          searchQuery,
                          sortHistory,
                          mockTime,
                        );

                        if (filteredTasks.isEmpty && searchQuery.isNotEmpty) {
                          return _buildNoMatchesState(context);
                        }

                        final isSortBarVisible = ref.watch(
                          showScheduleListSortBarProvider,
                        );

                        final isWide = isWideScreen(context);
                        late final List<TaskSchedule> leftTasks;
                        late final List<TaskSchedule> rightTasks;
                        if (isWide) {
                          leftTasks = [];
                          rightTasks = [];
                          final currentIds = filteredTasks
                              .map((e) => e.id)
                              .toSet();
                          _columnAffinity.removeWhere(
                            (id, _) => !currentIds.contains(id),
                          );
                          double leftHeight = 0.0;
                          double rightHeight = 0.0;
                          for (final task in filteredTasks) {
                            final taskHeight = estimateTaskScheduleHeight(
                              task,
                              showLastSpawnedDate: showLastSpawnedDate,
                            );
                            int? col = _columnAffinity[task.id];
                            if (col == null) {
                              col = leftHeight <= rightHeight ? 0 : 1;
                              _columnAffinity[task.id] = col;
                            }
                            if (col == 0) {
                              leftTasks.add(task);
                              leftHeight += taskHeight;
                            } else {
                              rightTasks.add(task);
                              rightHeight += taskHeight;
                            }
                          }
                        }

                        return Stack(
                          children: [
                            if (isWide)
                              ListView(
                                controller: _scrollController,
                                padding: EdgeInsets.only(
                                  top: isSortBarVisible ? 64.0 : 8.0,
                                  bottom: 80.0,
                                  left: 8.0,
                                  right: 8.0,
                                ),
                                children: [
                                  const UnsyncedBanner(),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (final task in leftTasks)
                                              TaskScheduleCard(
                                                task: task,
                                                isParent: isParent,
                                                showLastSpawnedDate:
                                                    showLastSpawnedDate,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (final task in rightTasks)
                                              TaskScheduleCard(
                                                task: task,
                                                isParent: isParent,
                                                showLastSpawnedDate:
                                                    showLastSpawnedDate,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(
                                  top: isSortBarVisible ? 64.0 : 8.0,
                                  bottom: 80.0,
                                  left: 8.0,
                                  right: 8.0,
                                ),
                                itemCount: filteredTasks.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return const UnsyncedBanner();
                                  }
                                  final task = filteredTasks[index - 1];
                                  return TaskScheduleCard(
                                    task: task,
                                    isParent: isParent,
                                    showLastSpawnedDate: showLastSpawnedDate,
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
}
