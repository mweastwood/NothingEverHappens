import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/task_sync_service.dart';

class UnsyncedDetailsSheet extends ConsumerWidget {
  const UnsyncedDetailsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const UnsyncedDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final unsyncedTasks = ref.watch(unsyncedTasksProvider);
    final unsyncedInstances = ref.watch(unsyncedInstancesProvider);
    final isSyncing = ref.watch(isSyncingProvider).value ?? false;
    final totalCount = unsyncedTasks.length + unsyncedInstances.length;

    final amberColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
    final amberBg = isDark
        ? Colors.amber.shade900.withValues(alpha: 0.3)
        : Colors.amber.shade100;

    return SafeArea(
      child: Container(
        key: const Key('unsynced_details_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: amberBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    color: amberColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pendingCloudSyncTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalCount > 0
                            ? '$totalCount pending change${totalCount > 1 ? 's' : ''}'
                            : l10n.pendingCloudSyncEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.pendingCloudSyncSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Flexible(
              child: totalCount == 0
                  ? _buildEmptyState(context)
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (unsyncedTasks.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            l10n.unsyncedScheduleTag,
                            unsyncedTasks.length,
                          ),
                          ...unsyncedTasks.map(
                            (task) => _buildTaskScheduleTile(context, task),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (unsyncedInstances.isNotEmpty) ...[
                          _buildSectionHeader(
                            context,
                            l10n.unsyncedInstanceTag,
                            unsyncedInstances.length,
                          ),
                          ...unsyncedInstances.map(
                            (instance) =>
                                _buildTaskInstanceTile(context, instance),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('unsynced_sync_now_button'),
              onPressed: isSyncing
                  ? null
                  : () async {
                      try {
                        await ref.read(taskSyncServiceProvider).sync();
                      } catch (_) {}
                    },
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(
                isSyncing ? l10n.syncingInProgress : l10n.syncNowButton,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.pendingCloudSyncEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTaskScheduleTile(BuildContext context, TaskSchedule task) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_repeat,
            size: 20,
            color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.isEmpty ? 'Untitled Task' : task.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.unsyncedScheduleTag,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInstanceTile(BuildContext context, TaskInstance instance) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;

    final isCompleted = instance.status == TaskStatus.completed;
    final isSkipped = instance.status == TaskStatus.skipped;

    final IconData statusIcon;
    final Color iconColor;
    final String statusLabel;

    if (isCompleted) {
      statusIcon = Icons.check_circle;
      iconColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
      statusLabel = l10n.unsyncedCompletedTag;
    } else if (isSkipped) {
      statusIcon = Icons.remove_circle_outline;
      iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      statusLabel = l10n.unsyncedDismissedTag;
    } else {
      statusIcon = Icons.task_alt;
      iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
      statusLabel = l10n.pendingBadge;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instance.title.isEmpty ? 'Untitled Task' : instance.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${instance.scheduledDate.year}-${instance.scheduledDate.month.toString().padLeft(2, '0')}-${instance.scheduledDate.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isCompleted
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade900)
                    : (isDark ? Colors.amber.shade300 : Colors.amber.shade900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
