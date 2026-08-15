import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/app_clock.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/task_repository.dart';
import '../logic/utils/format_utils.dart';
import '../widgets/weekly_capacity_chart.dart';

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
    final theme = Theme.of(context);
    final settingsVal = ref.watch(userSettingsProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final instancesVal = ref.watch(taskInstancesProvider);

    if (settingsVal.isLoading ||
        schedulesVal.isLoading ||
        instancesVal.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (settingsVal.hasError ||
        schedulesVal.hasError ||
        instancesVal.hasError) {
      final err = settingsVal.error ?? schedulesVal.error ?? instancesVal.error;
      return Scaffold(
        body: Center(child: Text('${context.l10n.errorOccurred}: $err')),
      );
    }

    final settings =
        settingsVal.value ?? const UserSettings(hoursAvailable: 8.0);
    final plannedMinutesPerDay = ref.watch(plannedMinutesPerDayProvider);

    final today = AppClock.now;
    final currentWeekId = _getWeekIdentifier(today);
    final isConfirmed = settings.lastCapacityConfirmedWeek == currentWeekId;

    // Upcoming 7 days (today + next 6 days)
    final upcomingDays = List.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dashboardTab)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isConfirmed) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_turned_in,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confirm capacity for this week',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review and confirm your available chore hours to clear this task.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            key: const Key('confirm_capacity_button'),
                            onPressed: () =>
                                _confirmCapacity(settings, currentWeekId),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              foregroundColor:
                                  theme.colorScheme.primaryContainer,
                            ),
                            child: const Text('Confirm Capacity'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Weekly Capacity Graph Card
            Builder(
              builder: (context) {
                final daysData = upcomingDays.map((date) {
                  final capacity = settings.getCapacityForDate(date);
                  final day = CivilDay.fromDateTime(date);
                  final plannedMinutes = plannedMinutesPerDay[day] ?? 0.0;
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final isOverridden =
                      settings.dailyCapacityOverrides?.containsKey(dateStr) ??
                      false;
                  return DailyCapacityData(
                    date: date,
                    capacityHours: capacity,
                    plannedMinutes: plannedMinutes,
                    isOverridden: isOverridden,
                  );
                }).toList();

                return WeeklyCapacityChart(
                  daysData: daysData,
                  onDayTap: (date) => _showEditCapacityDialog(
                    context,
                    settings,
                    date,
                    isOverride: true,
                  ),
                  onEditDefaultCapacity: () =>
                      _showDefaultCapacityTemplateDialog(context, settings),
                );
              },
            ),
            const SizedBox(height: 16),

            // Statistics Card (Placeholder)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Statistics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Completion rate, daily activity trends, and historic chore logs will appear here soon.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
