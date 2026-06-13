import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/civil_day.dart';
import '../widgets/task_widget.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;
        final schedulesVal = ref.watch(taskSchedulesProvider);
        final instancesVal = ref.watch(taskInstancesProvider);

        Widget bodySliver;
        if (schedulesVal.isLoading || instancesVal.isLoading) {
          bodySliver = const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (schedulesVal.hasError || instancesVal.hasError) {
          final err = schedulesVal.error ?? instancesVal.error;
          bodySliver = SliverToBoxAdapter(
            child: Center(child: Text('${context.l10n.errorOccurred}: $err')),
          );
        } else {
          final schedules = schedulesVal.value ?? [];
          final instances = instancesVal.value ?? [];

          final today = CivilDay.fromDateTime(AppClock.now);
          final filteredInstances = instances.where((inst) {
            final startsDate = inst.scheduledDate.addDays(
              inst.startRelativeTime.dayOffset,
            );
            return inst.status == 'pending' && !today.isBefore(startsDate);
          }).toList();

          if (filteredInstances.isEmpty) {
            bodySliver = SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(child: Text(context.l10n.noTasksYet)),
              ),
            );
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
