import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/utils/format_utils.dart';
import 'edit_capacity_sheet.dart';

class DefaultCapacityTemplateSheet extends ConsumerWidget {
  final UserSettings settings;

  const DefaultCapacityTemplateSheet({super.key, required this.settings});

  static Future<void> show(
    BuildContext context, {
    required UserSettings settings,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DefaultCapacityTemplateSheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              separatorBuilder: (context, index) => const Divider(height: 1),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                    EditCapacitySheet.show(
                      context,
                      settings: currentSettings,
                      date: dummyDate,
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
  }
}
