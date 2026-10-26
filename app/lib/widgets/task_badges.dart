import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/family_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/user_profile_provider.dart';

/// Reusable lightweight badge component for tasks.
class TaskBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double fontSize;

  const TaskBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (constraints.maxWidth >= 16) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A dedicated badge that watches family stream providers to isolate rebuilds
/// from the parent `TaskWidget`.
class FamilyTaskProgressBadge extends ConsumerWidget {
  final TaskInstance instance;

  const FamilyTaskProgressBadge({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyProfile = ref.watch(familyProfileStreamProvider).value;
    final familyId = familyProfile?.familyId ?? '';
    final family = familyId.isNotEmpty
        ? ref.watch(familyStreamProvider(familyId)).value
        : null;
    final totalMembers = family?.members.length ?? 0;
    final completedCount = instance.completedByUserIds.length;
    final label = totalMembers > 0
        ? context.l10n.completionProgressBadge(completedCount, totalMembers)
        : context.l10n.completionModeIndividualLabel;

    return TaskBadge(
      icon: Icons.checklist,
      label: label,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

/// A dedicated badge that watches [userNameProvider] to isolate rebuilds
/// from the parent `TaskWidget`.
class TaskAssigneeBadge extends ConsumerWidget {
  final String userId;
  final double fontSize;

  const TaskAssigneeBadge({
    super.key,
    required this.userId,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(userNameProvider(userId));
    final String label;
    if (nameAsync.hasError) {
      label = context.l10n.assignedBadge;
    } else if (nameAsync.hasValue) {
      label = context.l10n.assignedTo(nameAsync.value as String);
    } else {
      label = context.l10n.loadingBadge;
    }

    return TaskBadge(
      icon: Icons.assignment_ind,
      label: label,
      color: Theme.of(context).colorScheme.primary,
      fontSize: fontSize,
    );
  }
}
