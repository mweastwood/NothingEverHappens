import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../widgets/task_widget.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';

final taskSearchQueryProvider = StateProvider<String>((ref) => '');

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');
  Timer? _rebuildTimer;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;
        final schedulesVal = ref.watch(taskSchedulesProvider);
        final instancesVal = ref.watch(taskInstancesProvider);
        final settingsVal = ref.watch(userSettingsProvider);

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
          final settings =
              settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);
          final searchQuery = ref
              .watch(taskSearchQueryProvider)
              .trim()
              .toLowerCase();

          final filteredInstances = instances.where((inst) {
            final startDateTime = inst.startRelativeTime.referenceTo(
              inst.scheduledDate,
            );
            final isFuture = AppClock.now.isBefore(startDateTime);
            final isPending =
                inst.status == 'pending' &&
                (!isFuture || settings.showPendingTasks);

            final isResolvedToday =
                (inst.status == 'completed' || inst.status == 'dismissed') &&
                inst.completedAt != null &&
                CivilDay.fromDateTime(inst.completedAt!) ==
                    CivilDay.fromDateTime(AppClock.now) &&
                settings.showRecentlyResolvedTasks;

            if (!isPending && !isResolvedToday) return false;
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
            bodySliver = SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final inst = filteredInstances[index];
                  final matchingSchedules = schedules.where(
                    (s) => s.id == inst.scheduleId,
                  );
                  final sched = matchingSchedules.isEmpty
                      ? null
                      : matchingSchedules.first;
                  return Padding(
                    key: ValueKey(inst.id),
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TaskWidget(
                      key: ValueKey(inst.id),
                      instance: inst,
                      schedule: sched,
                    ),
                  );
                }, childCount: filteredInstances.length),
              ),
            );
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: isMocked ? 60.0 : 0.0,
          ), // Avoid overlap with dev clock banner
          child: CustomScrollView(
            key: const PageStorageKey('tasksView'),
            center: _taskListKey,
            slivers: [
              SliverPadding(
                key: _taskListKey,
                padding: EdgeInsets.zero,
                sliver: bodySliver,
              ),
            ],
          ),
        );
      },
    );
  }
}
