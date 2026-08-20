import 'package:flutter/material.dart';
import '../../logic/family.dart';
import '../../logic/family_task_completion_mode.dart';
import '../../logic/l10n_extension.dart';
import '../standard_choice_chip.dart';

/// Section widget for family/personal task assignment toggle in CreateTaskScreen.
class TaskFamilyAssignmentSection extends StatelessWidget {
  final bool isFamily;
  final ValueChanged<bool>? onFamilyToggled;
  final FamilyCompletionMode familyCompletionMode;
  final ValueChanged<FamilyCompletionMode>? onFamilyCompletionModeChanged;
  final bool readOnly;
  final List<FamilyMember> members;
  final String? assignedUserId;
  final ValueChanged<String?>? onAssignedUserChanged;
  final String? currentUserId;

  const TaskFamilyAssignmentSection({
    super.key,
    required this.isFamily,
    this.onFamilyToggled,
    this.familyCompletionMode = FamilyCompletionMode.anyone,
    this.onFamilyCompletionModeChanged,
    this.readOnly = false,
    this.members = const [],
    this.assignedUserId,
    this.onAssignedUserChanged,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.familyTab,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  StandardChoiceChip(
                    key: const Key('personal_task_chip'),
                    label: context.l10n.personalTaskToggleLabel,
                    selected: !isFamily,
                    onSelected: readOnly
                        ? null
                        : (selected) {
                            if (selected) {
                              onFamilyToggled?.call(false);
                            }
                          },
                  ),
                  StandardChoiceChip(
                    key: const Key('is_family_toggle'),
                    label: context.l10n.familyTaskToggleLabel,
                    selected: isFamily,
                    onSelected: readOnly
                        ? null
                        : (selected) {
                            if (selected) {
                              onFamilyToggled?.call(true);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isFamily
                    ? context.l10n.familyTaskHelper
                    : context.l10n.personalTaskHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isFamily) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.familyCompletionModeLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    StandardChoiceChip(
                      key: const Key('completion_mode_anyone_chip'),
                      label: context.l10n.completionModeAnyoneLabel,
                      selected:
                          familyCompletionMode == FamilyCompletionMode.anyone,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onFamilyCompletionModeChanged?.call(
                                  FamilyCompletionMode.anyone,
                                );
                              }
                            },
                    ),
                    StandardChoiceChip(
                      key: const Key('completion_mode_individual_chip'),
                      label: context.l10n.completionModeIndividualLabel,
                      selected:
                          familyCompletionMode ==
                          FamilyCompletionMode.individual,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onFamilyCompletionModeChanged?.call(
                                  FamilyCompletionMode.individual,
                                );
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  familyCompletionMode == FamilyCompletionMode.anyone
                      ? context.l10n.completionModeAnyoneHelper
                      : context.l10n.completionModeIndividualHelper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isFamily && members.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.assignToLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    StandardChoiceChip(
                      key: const Key('unassigned_member_chip'),
                      label: context.l10n.unassignedMemberLabel,
                      selected: assignedUserId == null,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onAssignedUserChanged?.call(null);
                              }
                            },
                    ),
                    for (final member in members)
                      StandardChoiceChip(
                        key: Key('member_chip_${member.userId}'),
                        avatar: Icon(
                          member.role == FamilyRole.parent
                              ? Icons.supervisor_account
                              : Icons.person,
                          size: 16,
                          color: assignedUserId == member.userId
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        label:
                            (currentUserId != null &&
                                member.userId == currentUserId)
                            ? 'You'
                            : (member.displayName.isNotEmpty
                                  ? member.displayName
                                  : (member.email.isNotEmpty
                                        ? member.email
                                        : 'Member')),
                        selected: assignedUserId == member.userId,
                        onSelected: readOnly
                            ? null
                            : (selected) {
                                if (selected) {
                                  onAssignedUserChanged?.call(member.userId);
                                }
                              },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
