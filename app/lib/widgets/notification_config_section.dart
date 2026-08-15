import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'relative_time_widget.dart';

class NotificationConfigSection extends StatelessWidget {
  final bool showNotification;
  final bool notificationEnabled;
  final bool readOnly;
  final ValueNotifier<RelativeTime> notificationController;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;
  final String keyPrefix;

  const NotificationConfigSection({
    super.key,
    required this.showNotification,
    required this.notificationEnabled,
    required this.readOnly,
    required this.notificationController,
    required this.onNotificationRelativeTimeChanged,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    if (!showNotification) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        CheckboxListTile(
          key: Key('${keyPrefix}_notification_checkbox'),
          title: Text(
            l10n.enableNotificationReminderLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          value: notificationEnabled,
          onChanged: readOnly
              ? null
              : (enabled) {
                  if (enabled == true) {
                    onNotificationRelativeTimeChanged(
                      notificationController.value,
                    );
                  } else {
                    onNotificationRelativeTimeChanged(null);
                  }
                },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (notificationEnabled) ...[
          Text(
            l10n.notificationWindowLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          RelativeTimeWidget(
            key: Key('${keyPrefix}_notification_relative_time_picker'),
            constraint: RelativeTimeConstraint.unconstrained,
            controller: notificationController,
          ),
        ],
      ],
    );
  }
}
