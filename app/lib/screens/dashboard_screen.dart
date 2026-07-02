import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/app_clock.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/civil_day.dart';
import '../logic/task_instance.dart';
import '../logic/task_schedule.dart';
import '../logic/task_repository.dart';
import '../logic/auth_repository.dart';

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
        SnackBar(content: Text('Weekly capacity confirmed successfully')),
      );
    }
  }

  String _formatDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) {
      return '${h}h ${m}m';
    } else if (h > 0) {
      return '${h}h';
    } else {
      return '${m}m';
    }
  }

  String _formatForecastLabel(double plannedHours, double capacityHours) {
    if (plannedHours == 0) {
      return _formatDuration(capacityHours);
    }
    return '${_formatDuration(plannedHours)}/${_formatDuration(capacityHours)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsVal = ref.watch(userSettingsProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final instancesVal = ref.watch(taskInstancesProvider);
    final currentUserId = ref.watch(authStateProvider).value?.uid;

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
    final schedules = schedulesVal.value ?? const <TaskSchedule>[];
    final instances = instancesVal.value ?? const <TaskInstance>[];
    final scheduleMap = {for (final s in schedules) s.id: s};

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Capacity Forecast',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap a bar to override capacity for that specific calendar day.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('edit_default_capacity_button'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showDefaultCapacityTemplateDialog(
                            context,
                            settings,
                          ),
                          tooltip: 'Edit Default Capacity Template',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: upcomingDays.map((date) {
                          final capacity = settings.getCapacityForDate(date);
                          final dateStr =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          final isOverridden =
                              settings.dailyCapacityOverrides?.containsKey(
                                dateStr,
                              ) ??
                              false;
                          final isToday =
                              date.day == today.day &&
                              date.month == today.month &&
                              date.year == today.year;

                          final day = CivilDay.fromDateTime(date);
                          double plannedMinutes = 0.0;
                          for (final inst in instances) {
                            if (inst.scheduledDate == day &&
                                inst.status != 'skipped') {
                              if (inst.assignedUserId != null &&
                                  inst.assignedUserId != currentUserId) {
                                continue;
                              }
                              final schedule = scheduleMap[inst.scheduleId];
                              if (schedule != null &&
                                  schedule.estimatedDuration != null) {
                                plannedMinutes += schedule
                                    .estimatedDuration!
                                    .inMinutes
                                    .toDouble();
                              }
                            }
                          }
                          final capacityMinutes = capacity * 60.0;

                          // Peak capacity to scale height (let's assume max scale is 8 hours)
                          final double scaleMax = 8.0;
                          final double barHeight = capacity > 0
                              ? (capacity / scaleMax * 120.0).clamp(8.0, 120.0)
                              : 0.0;
                          final double fillHeight = plannedMinutes > 0
                              ? (plannedMinutes / 60.0 / scaleMax * 120.0)
                                    .clamp(8.0, 120.0)
                              : 0.0;

                          final List<String> weekdays = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          final dayLabel = weekdays[date.weekday - 1];

                          return Expanded(
                            child: GestureDetector(
                              key: Key('capacity_bar_$dateStr'),
                              onTap: () => _showEditCapacityDialog(
                                context,
                                settings,
                                date,
                                isOverride: true,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatForecastLabel(
                                      plannedMinutes / 60.0,
                                      capacity,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 120,
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        // Solid fill (planned tasks)
                                        if (fillHeight > 0)
                                          Container(
                                            height: fillHeight,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors:
                                                    plannedMinutes >
                                                        capacityMinutes
                                                    ? [
                                                        theme.colorScheme.error,
                                                        theme.colorScheme.error
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ]
                                                    : isOverridden
                                                    ? [
                                                        theme
                                                            .colorScheme
                                                            .tertiary,
                                                        theme
                                                            .colorScheme
                                                            .tertiary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ]
                                                    : [
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                        theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        // Dashed outline (capacity)
                                        if (barHeight > 0)
                                          Container(
                                            height: barHeight,
                                            width: double.infinity,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: CustomPaint(
                                              painter: DashedRectPainter(
                                                color: isToday
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : isOverridden
                                                    ? theme.colorScheme.tertiary
                                                    : theme.colorScheme.primary,
                                                strokeWidth: 2.0,
                                                borderRadius: 6.0,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    dayLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isToday
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${date.day}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 12,
                          child: CustomPaint(
                            painter: DashedRectPainter(
                              color: theme.colorScheme.outlineVariant,
                              strokeWidth: 1.5,
                              borderRadius: 3.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Capacity',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(
                          width: 16,
                          height: 12,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Planned Work',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                                _formatDuration(defaultCapacity),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          onTap: () {
                            final dummyDate = DateTime(
                              2026,
                              1,
                              weekday,
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

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 4.0,
    this.borderRadius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashLength;
        dashPath.addPath(
          metric.extractPath(
            distance,
            (distance + length).clamp(0.0, metric.length),
          ),
          Offset.zero,
        );
        distance += length + gap;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
