import re

def replace_in_file(path, start_marker, end_marker, replacement, include_imports=False, imports=""):
    with open(path, 'r') as f:
        content = f.read()

    # Add imports
    if include_imports:
        content = content.replace("import 'missed_occurrence_policy_selector.dart';",
                                  "import 'missed_occurrence_policy_selector.dart';\n" + imports)

    # Find the chunk
    pattern = re.compile(re.escape(start_marker) + r'.*?' + re.escape(end_marker), re.DOTALL)
    
    if not pattern.search(content):
        print(f"NOT FOUND in {path}")
    
    content = pattern.sub(replacement, content)
    
    with open(path, 'w') as f:
        f.write(content)

monthly_path = "app/lib/widgets/monthly_fixed_scheduling_widget.dart"
yearly_path = "app/lib/widgets/yearly_fixed_scheduling_widget.dart"
weekly_path = "app/lib/widgets/weekly_scheduling_widget.dart"

imports_to_add = """import 'schedule_timing_section.dart';
import 'notification_config_section.dart';
import 'missed_occurrence_policy_section.dart';"""

start_marker = """        // Start
        Text(
          l10n.startLabel,"""

end_marker = """          MissedOccurrencePolicySelector(
            key: const Key('monthly_fixed_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],"""

monthly_replacement = """        ScheduleTimingSection(
          startController: _startController,
          dueController: _dueController,
          startKeyPrefix: 'monthly_fixed',
        ),
        NotificationConfigSection(
          showNotification: widget.showNotification,
          notificationEnabled: notificationEnabled,
          readOnly: widget.readOnly,
          notificationController: _notificationController,
          onNotificationRelativeTimeChanged: widget.onNotificationRelativeTimeChanged,
          keyPrefix: 'monthly_fixed',
        ),
        MissedOccurrencePolicySection(
          showMissedPolicy: widget.showMissedPolicy,
          missedOccurrencePolicy: widget.missedOccurrencePolicy,
          onMissedOccurrencePolicyChanged: widget.onMissedOccurrencePolicyChanged,
          keyPrefix: 'monthly_fixed',
        ),"""

replace_in_file(monthly_path, start_marker, end_marker, monthly_replacement, True, imports_to_add)

# For yearly
yearly_end_marker = """          MissedOccurrencePolicySelector(
            key: const Key('yearly_fixed_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],"""

yearly_replacement = monthly_replacement.replace('monthly_fixed', 'yearly_fixed')

replace_in_file(yearly_path, start_marker, yearly_end_marker, yearly_replacement, True, imports_to_add)

# For weekly fixed
weekly_fixed_start = """        // 3. Start Window & help text
        Text(
          l10n.startLabel,"""

weekly_fixed_end = """          MissedOccurrencePolicySelector(
            key: const Key('weekly_fixed_missed_policy'),
            policy: widget.missedOccurrencePolicy!,
            onChanged: widget.onMissedOccurrencePolicyChanged!,
          ),
        ],"""

weekly_fixed_replacement = monthly_replacement.replace('monthly_fixed', 'weekly_fixed')

replace_in_file(weekly_path, weekly_fixed_start, weekly_fixed_end, weekly_fixed_replacement, True, imports_to_add)

# For weekly completion
weekly_completion_start = """        // 2. Start
        Text(
          l10n.startLabel,"""

weekly_completion_end = """            RelativeTimeWidget(
              key: const Key(
                'weekly_completion_notification_relative_time_picker',
              ),
              constraint: RelativeTimeConstraint.unconstrained,
              controller: _notificationController,
            ),
          ],
        ],"""

weekly_completion_replacement = """        ScheduleTimingSection(
          startController: _startController,
          dueController: _dueController,
          startKeyPrefix: 'weekly_completion',
        ),
        NotificationConfigSection(
          showNotification: widget.showNotification,
          notificationEnabled: notificationEnabled,
          readOnly: widget.readOnly,
          notificationController: _notificationController,
          onNotificationRelativeTimeChanged: widget.onNotificationRelativeTimeChanged,
          keyPrefix: 'weekly_completion',
        ),"""

replace_in_file(weekly_path, weekly_completion_start, weekly_completion_end, weekly_completion_replacement, False, "")
print("Done.")
