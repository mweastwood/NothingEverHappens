import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';

class EditCapacitySheet extends ConsumerStatefulWidget {
  final UserSettings settings;
  final DateTime date;
  final bool isOverride;

  const EditCapacitySheet({
    super.key,
    required this.settings,
    required this.date,
    required this.isOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSettings settings,
    required DateTime date,
    required bool isOverride,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EditCapacitySheet(
        settings: settings,
        date: date,
        isOverride: isOverride,
      ),
    );
  }

  @override
  ConsumerState<EditCapacitySheet> createState() => _EditCapacitySheetState();
}

class _EditCapacitySheetState extends ConsumerState<EditCapacitySheet> {
  late int _selectedHours;
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    final date = widget.date;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final weekdayStr = date.weekday.toString();

    final double currentCapacity = widget.isOverride
        ? (widget.settings.dailyCapacityOverrides?[dateStr] ??
              widget.settings.defaultDailyCapacity?[weekdayStr] ??
              widget.settings.hoursAvailable)
        : (widget.settings.defaultDailyCapacity?[weekdayStr] ??
              widget.settings.hoursAvailable);

    final totalMinutes = (currentCapacity * 60).round();
    _selectedHours = totalMinutes ~/ 60;
    _selectedMinutes = totalMinutes % 60;
  }

  void _updateMinutes(int delta) {
    setState(() {
      final currentTotal = _selectedHours * 60 + _selectedMinutes + delta;
      if (currentTotal >= 0) {
        _selectedHours = currentTotal ~/ 60;
        _selectedMinutes = currentTotal % 60;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = widget.date;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final weekdayStr = date.weekday.toString();

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
            widget.isOverride ? 'Adjust Capacity' : 'Edit Default Capacity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isOverride
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
                  onPressed: () => _updateMinutes(-15),
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
                      _selectedHours > 0
                          ? '${_selectedHours}h ${_selectedMinutes}m'
                          : '${_selectedMinutes}m',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  key: const Key('capacity_increment_button'),
                  icon: const Icon(Icons.add),
                  onPressed: () => _updateMinutes(15),
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
                      (_selectedHours * 60 + _selectedMinutes) ==
                      preset.minutes;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedHours = preset.minutes ~/ 60;
                          _selectedMinutes = preset.minutes % 60;
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
              if (widget.isOverride &&
                  widget.settings.dailyCapacityOverrides?.containsKey(
                        dateStr,
                      ) ==
                      true) ...[
                TextButton(
                  key: const Key('capacity_reset_button'),
                  onPressed: () {
                    final updatedOverrides = Map<String, double>.from(
                      widget.settings.dailyCapacityOverrides ?? {},
                    );
                    updatedOverrides.remove(dateStr);
                    final updatedSettings = widget.settings.copyWith(
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
                      (_selectedHours * 60 + _selectedMinutes) / 60.0;
                  final repository = ref.read(
                    userSettingsRepositoryProvider,
                  );
                  if (repository != null) {
                    if (widget.isOverride) {
                      final updatedOverrides = Map<String, double>.from(
                        widget.settings.dailyCapacityOverrides ?? {},
                      );
                      updatedOverrides[dateStr] = newCapacity;
                      repository.updateSettings(
                        widget.settings.copyWith(
                          dailyCapacityOverrides: updatedOverrides,
                        ),
                      );
                    } else {
                      final updatedDefaults = Map<String, double>.from(
                        widget.settings.defaultDailyCapacity ?? {},
                      );
                      updatedDefaults[weekdayStr] = newCapacity;
                      repository.updateSettings(
                        widget.settings.copyWith(
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
  }
}
