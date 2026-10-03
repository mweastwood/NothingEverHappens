import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/app_clock.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/dashboard_stats.dart';
import '../widgets/family_history_stats_card.dart';
import '../widgets/family_contributions_card.dart';
import '../widgets/weekly_capacity_chart.dart';
import '../widgets/daily_activity_breakdown_sheet.dart';
import '../widgets/system_task_widget.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/edit_capacity_sheet.dart';
import '../widgets/default_capacity_template_sheet.dart';
import '../logic/system_tasks/system_task_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _getWeekIdentifier(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  void _confirmCapacity(UserSettings settings, String weekId) {
    final repository = ref.read(userSettingsRepositoryProvider);
    if (repository != null) {
      repository.updateSettings(
        settings.copyWith(lastCapacityConfirmedWeek: weekId),
      );
      AppSnackBar.show(
        context,
        content: const Text('Weekly capacity confirmed successfully'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsVal = ref.watch(userSettingsProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final instancesVal = ref.watch(taskInstancesProvider);

    if (settingsVal.isLoading ||
        schedulesVal.isLoading ||
        instancesVal.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (settingsVal.hasError ||
        schedulesVal.hasError ||
        instancesVal.hasError) {
      final err = settingsVal.error ?? schedulesVal.error ?? instancesVal.error;
      return Center(child: Text('${context.l10n.errorOccurred}: $err'));
    }

    final settings =
        settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);
    final plannedMinutesPerDay = ref.watch(plannedMinutesPerDayProvider);
    final personalStats = ref.watch(personalLastWeekStatsProvider);
    final familyStats = ref.watch(familyLastWeekStatsProvider);

    final activeSystemTasks = ref.watch(activeSystemTasksProvider);
    final today = AppClock.now;
    final currentWeekId = _getWeekIdentifier(today);

    // 13-day timeline (6 days history + today + 6 days forecast)
    final timelineDays = List.generate(
      13,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: index - 6)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final sysTask in activeSystemTasks) ...[
            SystemTaskWidget(
              key: Key('system_task_${sysTask.id}'),
              task: sysTask.id == 'verify_weekly_capacity'
                  ? sysTask.copyWith(
                      onAction: () => _confirmCapacity(settings, currentWeekId),
                    )
                  : sysTask,
              variant: SystemTaskWidgetVariant.card,
              actionButtonKey: sysTask.id == 'verify_weekly_capacity'
                  ? const Key('confirm_capacity_button')
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // Combined Activity & Capacity Timeline Card
          Builder(
            builder: (context) {
              final timelineStats = ref.watch(personalTimelineStatsProvider);
              final daysData = timelineDays.map((date) {
                final capacity = settings.getCapacityForDate(date);
                final day = CivilDay.fromDateTime(date);
                final plannedMinutes = plannedMinutesPerDay[day] ?? 0.0;
                final dateStr =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final isOverridden =
                    settings.dailyCapacityOverrides?.containsKey(dateStr) ??
                    false;

                final dayStats =
                    timelineStats[day] ??
                    DailyStatsData(
                      day: day,
                      completedCount: 0,
                      skippedCount: 0,
                      missedCount: 0,
                      completedHours: 0.0,
                    );
                final completedMinutes = (dayStats.completedHours) * 60.0;

                return DailyCapacityData(
                  date: date,
                  capacityHours: capacity,
                  plannedMinutes: plannedMinutes,
                  completedMinutes: completedMinutes,
                  isOverridden: isOverridden,
                  statsData: dayStats,
                );
              }).toList();

              final schedules = schedulesVal.value ?? [];
              final scheduleMap = <String, TaskSchedule>{
                for (final s in schedules) s.id: s,
              };
              final familyMemberCount = familyStats?.memberStats.length ?? 1;

              return WeeklyCapacityChart(
                daysData: daysData,
                stats: personalStats,
                onDayTap: (date) => EditCapacitySheet.show(
                  context,
                  settings: settings,
                  date: date,
                  isOverride: true,
                ),
                onDayActivityTap: (dayData) => DailyActivityBreakdownSheet.show(
                  context,
                  dayData,
                  isFamilyTimeline: false,
                  scheduleMap: scheduleMap,
                  familyMemberCount: familyMemberCount,
                ),
                onEditDefaultCapacity: () => DefaultCapacityTemplateSheet.show(
                  context,
                  settings: settings,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Family Timeline Card (if part of a family)
          if (familyStats != null) ...[
            Builder(
              builder: (context) {
                final schedules = schedulesVal.value ?? [];
                final scheduleMap = <String, TaskSchedule>{
                  for (final s in schedules) s.id: s,
                };
                final familyMemberCount = familyStats.memberStats.length;

                return FamilyHistoryStatsCard(
                  stats: familyStats,
                  onDayActivityTap: (dayData) =>
                      DailyActivityBreakdownSheet.show(
                        context,
                        dayData,
                        isFamilyTimeline: true,
                        scheduleMap: scheduleMap,
                        familyMemberCount: familyMemberCount,
                      ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Family Contributions Card (Pie chart)
            Builder(
              builder: (context) {
                final schedules = schedulesVal.value ?? [];
                final scheduleMap = <String, TaskSchedule>{
                  for (final s in schedules) s.id: s,
                };

                return FamilyContributionsCard(
                  stats: familyStats,
                  scheduleMap: scheduleMap,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
