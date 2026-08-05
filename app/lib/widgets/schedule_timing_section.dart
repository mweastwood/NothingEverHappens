import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'relative_time_widget.dart';

class ScheduleTimingSection extends StatelessWidget {
  final ValueNotifier<RelativeTime> startController;
  final ValueNotifier<RelativeTime> dueController;
  final String startKeyPrefix;

  const ScheduleTimingSection({
    super.key,
    required this.startController,
    required this.dueController,
    required this.startKeyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start
        Text(
          l10n.startLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: Key('${startKeyPrefix}_start_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: startController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.taskAppearanceHelpText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Due
        Text(
          l10n.dueWithoutColon,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: Key('${startKeyPrefix}_due_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: dueController,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.dueDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
