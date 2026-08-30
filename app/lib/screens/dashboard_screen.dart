import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/app_clock.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/utils/format_utils.dart';
import '../logic/dashboard_stats.dart';
import '../widgets/family_history_stats_card.dart';
import '../widgets/weekly_capacity_chart.dart';
import '../widgets/daily_activity_breakdown_sheet.dart';
import '../widgets/system_task_widget.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly capacity confirmed successfully')),
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
                onDayTap: (date) => _showEditCapacityDialog(
                  context,
                  settings,
                  date,
                  isOverride: true,
                ),
                onDayActivityTap: (dayData) => DailyActivityBreakdownSheet.show(
                  context,
                  dayData,
                  isFamilyTimeline: false,
                  scheduleMap: scheduleMap,
                  familyMemberCount: familyMemberCount,
                ),
                onEditDefaultCapacity: () =>
                    _showDefaultCapacityTemplateDialog(context, settings),
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
          ],
        ],
      ),
    );
  }

  void _showEditCapacityDialog(
    BuildContext context,
    UserSettings settings,
    DateTime date, {
    required bool isOverride,
  }) {
    final theme = Theme.of(context);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final weekdayStr = date.weekday.toString();

    final double currentCapacity = isOverride
        ? (settings.dailyCapacityOverrides?[dateStr] ??
              settings.defaultDailyCapacity?[weekdayStr] ??
              settings.hoursAvailable)
        : (settings.defaultDailyCapacity?[weekdayStr] ??
              settings.hoursAvailable);

    final totalMinutes = (currentCapacity * 60).round();
    int selectedHours = totalMinutes ~/ 60;
    int selectedMinutes = totalMinutes % 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateMinutes(int delta) {
              setModalState(() {
                final currentTotal =
                    selectedHours * 60 + selectedMinutes + delta;
                if (currentTotal >= 0) {
                  selectedHours = currentTotal ~/ 60;
                  selectedMinutes = currentTotal % 60;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOverride ? 'Adjust Capacity' : 'Edit Default Capacity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOverride
                        ? 'Set chore availability for ${date.day}/${date.month}/${date.year}'
                        : 'Set default availability baseline for weekday',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stepper Controls
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: const Key('capacity_decrement_button'),
                          icon: const Icon(Icons.remove),
                          onPressed: () => updateMinutes(-15),
                        ),
                        Column(
                          children: [
                            Text(
                              'Available Duration',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedHours > 0
                                  ? '${selectedHours}h ${selectedMinutes}m'
                                  : '${selectedMinutes}m',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          key: const Key('capacity_increment_button'),
                          icon: const Icon(Icons.add),
                          onPressed: () => updateMinutes(15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preset Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                          (label: 'Away (0m)', minutes: 0),
                          (label: '30m', minutes: 30),
                          (label: '1h', minutes: 60),
                          (label: '2h', minutes: 120),
                          (label: '3h', minutes: 180),
                        ].map((preset) {
                          final isSelected =
                              (selectedHours * 60 + selectedMinutes) ==
                              preset.minutes;
                          return ChoiceChip(
                            label: Text(preset.label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  selectedHours = preset.minutes ~/ 60;
                                  selectedMinutes = preset.minutes % 60;
                                });
                              }
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isOverride &&
                          settings.dailyCapacityOverrides?.containsKey(
                                dateStr,
                              ) ==
                              true) ...[
                        TextButton(
                          key: const Key('capacity_reset_button'),
                          onPressed: () {
                            final updatedOverrides = Map<String, double>.from(
                              settings.dailyCapacityOverrides ?? {},
                            );
                            updatedOverrides.remove(dateStr);
                            final updatedSettings = settings.copyWith(
                              dailyCapacityOverrides: updatedOverrides,
                            );
                            ref
                                .read(userSettingsRepositoryProvider)
                                ?.updateSettings(updatedSettings);
                            Navigator.pop(context);
                          },
                          child: const Text('Reset to Default'),
                        ),
                        const Spacer(),
                      ],
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('capacity_save_button'),
                        onPressed: () {
                          final double newCapacity =
                              (selectedHours * 60 + selectedMinutes) / 60.0;
                          final repository = ref.read(
                            userSettingsRepositoryProvider,
                          );
                          if (repository != null) {
                            if (isOverride) {
                              final updatedOverrides = Map<String, double>.from(
                                settings.dailyCapacityOverrides ?? {},
                              );
                              updatedOverrides[dateStr] = newCapacity;
                              repository.updateSettings(
                                settings.copyWith(
                                  dailyCapacityOverrides: updatedOverrides,
                                ),
                              );
                            } else {
                              final updatedDefaults = Map<String, double>.from(
                                settings.defaultDailyCapacity ?? {},
                              );
                              updatedDefaults[weekdayStr] = newCapacity;
                              repository.updateSettings(
                                settings.copyWith(
                                  defaultDailyCapacity: updatedDefaults,
                                ),
                              );
                            }
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDefaultCapacityTemplateDialog(
    BuildContext context,
    UserSettings settings,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final settingsVal = ref.watch(userSettingsProvider);
            final currentSettings = settingsVal.value ?? settings;

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default Capacity Template',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set standard availability baseline per day',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: 7,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final weekday = index + 1;
                        final List<String> weekdays = [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ];
                        final dayLabel = weekdays[index];
                        final weekdayStr = weekday.toString();
                        final defaultCapacity =
                            currentSettings.defaultDailyCapacity?[weekdayStr] ??
                            currentSettings.hoursAvailable;

                        return ListTile(
                          key: Key('default_capacity_tile_$weekday'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(dayLabel),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDurationHours(defaultCapacity),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          onTap: () {
                            // 2026-01-05 is a Monday (weekday = 1).
                            // Thus, 2026-01-04 + weekday aligns weekdayStr with the correct index (1=Mon, ..., 7=Sun).
                            final dummyDate = DateTime(
                              2026,
                              1,
                              4 + weekday,
                            ); // Map to weekday
                            _showEditCapacityDialog(
                              context,
                              currentSettings,
                              dummyDate,
                              isOverride: false,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
