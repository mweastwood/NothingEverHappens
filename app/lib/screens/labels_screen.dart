import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/auth_repository.dart';
import '../logic/error_handler.dart';
import '../logic/family_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/label_repository.dart';
import '../logic/task_label.dart';
import '../logic/utils/layout_breakpoints.dart';
import '../widgets/label_edit_dialog.dart';
import '../widgets/label_item_card.dart';
import 'family_screen.dart';

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  Future<void> _openEditDialog(
    BuildContext context, {
    TaskLabel? existingLabel,
    required TaskLabelScope scope,
    int nextOrder = 0,
  }) {
    return LabelEditDialog.show(
      context,
      existingLabel: existingLabel,
      scope: scope,
      nextOrder: nextOrder,
    );
  }

  Future<void> _runWithErrorDialog(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
      }
    }
  }

  Future<void> _reorderLabels(
    List<TaskLabel> currentLabels,
    int oldIndex,
    int newIndex,
    Future<void> Function(List<TaskLabel> reordered) onPersist,
  ) {
    final reordered = List<TaskLabel>.from(currentLabels);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    return _runWithErrorDialog(() => onPersist(reordered));
  }

  Future<void> _onReorderPersonal(
    List<TaskLabel> currentLabels,
    int oldIndex,
    int newIndex,
  ) {
    return _reorderLabels(currentLabels, oldIndex, newIndex, (reordered) async {
      final userId = ref.read(authStateProvider).value?.uid ?? '';
      if (userId.isEmpty) {
        throw StateError('User is not authenticated');
      }
      await ref
          .read(labelRepositoryProvider)
          .reorderPersonalLabels(userId, reordered);
    });
  }

  Future<void> _onReorderFamily(
    List<TaskLabel> currentLabels,
    int oldIndex,
    int newIndex,
  ) {
    return _reorderLabels(currentLabels, oldIndex, newIndex, (reordered) async {
      final familyProfile = ref.read(familyProfileStreamProvider).value;
      final familyId = familyProfile?.familyId ?? '';
      if (familyId.isEmpty) {
        throw StateError('Family ID cannot be resolved');
      }
      await ref
          .read(labelRepositoryProvider)
          .reorderFamilyLabels(familyId, reordered);
    });
  }

  Future<void> _confirmDelete(TaskLabel label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteLabelConfirmTitle),
        content: Text(context.l10n.deleteLabelConfirmMessage(label.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const Key('confirm_delete_label_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.deleteButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _runWithErrorDialog(() async {
        final repo = ref.read(labelRepositoryProvider);
        if (label.scope == TaskLabelScope.personal) {
          final userId = ref.read(authStateProvider).value?.uid ?? '';
          if (userId.isEmpty) {
            throw StateError('User is not authenticated');
          }
          await repo.deletePersonalLabel(userId, label.id);
        } else {
          final familyProfile = ref.read(familyProfileStreamProvider).value;
          final familyId = familyProfile?.familyId ?? '';
          if (familyId.isEmpty) {
            throw StateError('Family ID cannot be resolved');
          }
          await repo.deleteFamilyLabel(familyId, label.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = isWideScreen(context);
    final personalLabelsAsync = ref.watch(personalLabelsStreamProvider);
    final familyProfileAsync = ref.watch(familyProfileStreamProvider);
    final familyId = familyProfileAsync.value?.familyId ?? '';
    final familyLabelsAsync = ref.watch(familyLabelsStreamProvider);
    final isParent = ref.watch(canEditFamilyLabelsProvider);
    final inFamily = familyId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.labelsTitle)),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPersonalSection(
                    context,
                    personalLabelsAsync,
                    isScrollable: true,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: _buildFamilySection(
                    context,
                    familyLabelsAsync,
                    inFamily: inFamily,
                    isParent: isParent,
                    isScrollable: true,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              children: [
                _buildPersonalSection(
                  context,
                  personalLabelsAsync,
                  isScrollable: false,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(height: 1, thickness: 1),
                ),
                _buildFamilySection(
                  context,
                  familyLabelsAsync,
                  inFamily: inFamily,
                  isParent: isParent,
                  isScrollable: false,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Key? addButtonKey,
    VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onAdd != null)
            FilledButton.tonalIcon(
              key: addButtonKey,
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.addLabelButton),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.label_off_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapSection({
    required Widget header,
    required Widget content,
    required bool isScrollable,
  }) {
    if (isScrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(height: 1, thickness: 1),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, content],
    );
  }

  Widget _buildLabelItem(
    BuildContext context, {
    required TaskLabel label,
    int? index,
    required bool canEdit,
  }) {
    return LabelItemCard(
      key: ValueKey(label.id),
      label: label,
      index: index,
      canEdit: canEdit,
      onEdit: () =>
          _openEditDialog(context, existingLabel: label, scope: label.scope),
      onDelete: () => _confirmDelete(label),
    );
  }

  Widget _buildPersonalSection(
    BuildContext context,
    AsyncValue<List<TaskLabel>> personalLabelsAsync, {
    required bool isScrollable,
  }) {
    final header = _buildSectionHeader(
      context,
      icon: Icons.person_outline,
      title: context.l10n.personalLabelsSection,
      subtitle: context.l10n.personalLabelsSubtitle,
      addButtonKey: const Key('add_personal_label_button'),
      onAdd: () => _openEditDialog(
        context,
        scope: TaskLabelScope.personal,
        nextOrder: personalLabelsAsync.value?.length ?? 0,
      ),
    );

    final content = personalLabelsAsync.when(
      data: (labels) {
        if (labels.isEmpty) {
          final emptyCard = _buildEmptyStateCard(
            context,
            context.l10n.noPersonalLabels,
          );
          return isScrollable
              ? SingleChildScrollView(child: emptyCard)
              : emptyCard;
        }

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: !isScrollable,
          physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: labels.length,
          onReorderItem: (oldIndex, newIndex) =>
              _onReorderPersonal(labels, oldIndex, newIndex),
          itemBuilder: (context, index) => _buildLabelItem(
            context,
            label: labels[index],
            index: index,
            canEdit: true,
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading personal labels: $error'),
        ),
      ),
    );

    return _wrapSection(
      header: header,
      content: content,
      isScrollable: isScrollable,
    );
  }

  Widget _buildFamilySection(
    BuildContext context,
    AsyncValue<List<TaskLabel>> familyLabelsAsync, {
    required bool inFamily,
    required bool isParent,
    required bool isScrollable,
  }) {
    final header = _buildSectionHeader(
      context,
      icon: Icons.people_outline,
      title: context.l10n.familyLabelsSection,
      subtitle: context.l10n.familyLabelsSubtitle,
      addButtonKey: const Key('add_family_label_button'),
      onAdd: (inFamily && isParent)
          ? () => _openEditDialog(
              context,
              scope: TaskLabelScope.family,
              nextOrder: familyLabelsAsync.value?.length ?? 0,
            )
          : null,
    );

    Widget content;

    if (!inFamily) {
      final notInFamilyCard = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.notInFamilyLabelsNotice,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const Key('go_to_family_button'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FamilyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: Text(context.l10n.goToFamilyButton),
                ),
              ],
            ),
          ),
        ),
      );
      content = isScrollable
          ? SingleChildScrollView(child: notInFamilyCard)
          : notInFamilyCard;
    } else {
      content = familyLabelsAsync.when(
        data: (labels) {
          Widget? banner;
          if (!isParent) {
            banner = Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.onlyParentsCanManageFamilyLabels,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (labels.isEmpty) {
            final emptyCard = _buildEmptyStateCard(
              context,
              isParent
                  ? context.l10n.noFamilyLabels
                  : context.l10n.noFamilyLabelsNonParent,
            );
            final emptyContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [?banner, emptyCard],
            );
            return isScrollable
                ? SingleChildScrollView(child: emptyContent)
                : emptyContent;
          }

          final listView = isParent
              ? ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  shrinkWrap: !isScrollable,
                  physics: isScrollable
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: labels.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _onReorderFamily(labels, oldIndex, newIndex),
                  itemBuilder: (context, index) => _buildLabelItem(
                    context,
                    label: labels[index],
                    index: index,
                    canEdit: true,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: !isScrollable,
                  physics: isScrollable
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: labels.length,
                  itemBuilder: (context, index) => _buildLabelItem(
                    context,
                    label: labels[index],
                    canEdit: false,
                  ),
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?banner,
              if (isScrollable) Expanded(child: listView) else listView,
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading family labels: $error'),
          ),
        ),
      );
    }

    return _wrapSection(
      header: header,
      content: content,
      isScrollable: isScrollable,
    );
  }
}
