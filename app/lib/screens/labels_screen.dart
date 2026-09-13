import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/auth_repository.dart';
import '../logic/family_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/label_repository.dart';
import '../logic/task_label.dart';
import '../logic/utils/layout_breakpoints.dart';
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
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _LabelEditDialog(existingLabel: existingLabel, scope: scope),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TaskLabel label) async {
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
      final repo = ref.read(labelRepositoryProvider);
      if (label.scope == TaskLabelScope.personal) {
        final userId = ref.read(authStateProvider).value?.uid ?? '';
        if (userId.isNotEmpty) {
          await repo.deletePersonalLabel(userId, label.id);
        }
      } else {
        final familyProfile = ref.read(familyProfileStreamProvider).value;
        final familyId = familyProfile?.familyId ?? '';
        if (familyId.isNotEmpty) {
          await repo.deleteFamilyLabel(familyId, label.id);
        }
      }
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

  Widget _buildPersonalSection(
    BuildContext context,
    AsyncValue<List<TaskLabel>> personalLabelsAsync, {
    required bool isScrollable,
  }) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.person_outline,
            size: 26,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.personalLabelsSection,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  context.l10n.personalLabelsSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const Key('add_personal_label_button'),
            onPressed: () =>
                _openEditDialog(context, scope: TaskLabelScope.personal),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.addLabelButton),
          ),
        ],
      ),
    );

    final content = personalLabelsAsync.when(
      data: (labels) {
        if (labels.isEmpty) {
          return Padding(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
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
                        context.l10n.noPersonalLabels,
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

        return ListView.builder(
          shrinkWrap: !isScrollable,
          physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: labels.length,
          itemBuilder: (context, index) {
            final label = labels[index];
            return _buildLabelCard(context, label: label, canEdit: true);
          },
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

    if (isScrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(height: 1, thickness: 1),
          Expanded(child: content),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, content],
      );
    }
  }

  Widget _buildFamilySection(
    BuildContext context,
    AsyncValue<List<TaskLabel>> familyLabelsAsync, {
    required bool inFamily,
    required bool isParent,
    required bool isScrollable,
  }) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 26,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.familyLabelsSection,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  context.l10n.familyLabelsSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (inFamily && isParent)
            FilledButton.tonalIcon(
              key: const Key('add_family_label_button'),
              onPressed: () =>
                  _openEditDialog(context, scope: TaskLabelScope.family),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.addLabelButton),
            ),
        ],
      ),
    );

    Widget content;

    if (!inFamily) {
      content = Padding(
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
    } else {
      content = familyLabelsAsync.when(
        data: (labels) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isParent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.6),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 32.0,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.label_off_outlined,
                              size: 40,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isParent
                                  ? context.l10n.noFamilyLabels
                                  : context.l10n.noFamilyLabelsNonParent,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: !isScrollable,
                  physics: isScrollable
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: labels.length,
                  itemBuilder: (context, index) {
                    final label = labels[index];
                    return _buildLabelCard(
                      context,
                      label: label,
                      canEdit: isParent,
                    );
                  },
                ),
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

    if (isScrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(height: 1, thickness: 1),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, content],
      );
    }
  }

  Widget _buildLabelCard(
    BuildContext context, {
    required TaskLabel label,
    required bool canEdit,
  }) {
    final color = LabelPalette.getColor(label.colorKey, context);
    final icon = LabelIcons.getIcon(label.iconKey);

    return Card(
      key: Key('label_item_${label.id}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('edit_label_${label.id}'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _openEditDialog(
                      context,
                      existingLabel: label,
                      scope: label.scope,
                    ),
                  ),
                  IconButton(
                    key: Key('delete_label_${label.id}'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.deleteButton,
                    onPressed: () => _confirmDelete(context, label),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _LabelEditDialog extends ConsumerStatefulWidget {
  final TaskLabel? existingLabel;
  final TaskLabelScope scope;

  const _LabelEditDialog({this.existingLabel, required this.scope});

  @override
  ConsumerState<_LabelEditDialog> createState() => _LabelEditDialogState();
}

class _LabelEditDialogState extends ConsumerState<_LabelEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedColorKey;
  late String _selectedIconKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingLabel?.name ?? '',
    );
    _selectedColorKey = widget.existingLabel?.colorKey ?? 'coral';
    _selectedIconKey = widget.existingLabel?.iconKey ?? 'tag';
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(labelRepositoryProvider);
      final labelName = _nameController.text.trim();

      if (widget.existingLabel != null) {
        final updatedLabel = widget.existingLabel!.copyWith(
          name: labelName,
          colorKey: _selectedColorKey,
          iconKey: _selectedIconKey,
          updatedAt: DateTime.now().toUtc(),
        );

        if (widget.scope == TaskLabelScope.personal) {
          final userId = ref.read(authStateProvider).value?.uid ?? '';
          if (userId.isNotEmpty) {
            await repo.savePersonalLabel(userId, updatedLabel);
          }
        } else {
          final familyProfile = ref.read(familyProfileStreamProvider).value;
          final familyId = familyProfile?.familyId ?? '';
          if (familyId.isNotEmpty) {
            await repo.saveFamilyLabel(familyId, updatedLabel);
          }
        }
      } else {
        final newLabel = TaskLabel.create(
          name: labelName,
          colorKey: _selectedColorKey,
          iconKey: _selectedIconKey,
          scope: widget.scope,
        );

        if (widget.scope == TaskLabelScope.personal) {
          final userId = ref.read(authStateProvider).value?.uid ?? '';
          if (userId.isNotEmpty) {
            await repo.savePersonalLabel(userId, newLabel);
          }
        } else {
          final familyProfile = ref.read(familyProfileStreamProvider).value;
          final familyId = familyProfile?.familyId ?? '';
          if (familyId.isNotEmpty) {
            await repo.saveFamilyLabel(familyId, newLabel);
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existingLabel == null;
    final isPersonal = widget.scope == TaskLabelScope.personal;
    final title = isNew
        ? (isPersonal
              ? context.l10n.newPersonalLabel
              : context.l10n.newFamilyLabel)
        : (isPersonal
              ? context.l10n.editPersonalLabel
              : context.l10n.editFamilyLabel);

    final activeColor = LabelPalette.getColor(_selectedColorKey, context);
    final activeIcon = LabelIcons.getIcon(_selectedIconKey);
    final displayName = _nameController.text.trim().isEmpty
        ? context.l10n.labelPreview
        : _nameController.text.trim();

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview chip
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(activeIcon, size: 18, color: activeColor),
                        const SizedBox(width: 8),
                        Text(
                          displayName,
                          style: TextStyle(
                            color: activeColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Name field
                TextFormField(
                  key: const Key('label_name_field'),
                  controller: _nameController,
                  autofocus: isNew,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: context.l10n.labelNameField,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.labelNameRequired;
                    }
                    if (value.trim().length > 24) {
                      return context.l10n.labelNameTooLong;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Color picker
                Text(
                  context.l10n.labelColorPickerLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: LabelPalette.all.map((colorItem) {
                    final isSelected = colorItem.key == _selectedColorKey;
                    final color = colorItem.getColor(context);
                    return InkWell(
                      key: Key('color_picker_${colorItem.key}'),
                      onTap: () {
                        setState(() {
                          _selectedColorKey = colorItem.key;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Icon picker
                Text(
                  context.l10n.labelIconPickerLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: LabelIcons.all.map((iconItem) {
                    final isSelected = iconItem.key == _selectedIconKey;
                    return InkWell(
                      key: Key('icon_picker_${iconItem.key}'),
                      onTap: () {
                        setState(() {
                          _selectedIconKey = iconItem.key;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          iconItem.icon,
                          size: 22,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('save_label_button'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.saveLabelButton),
        ),
      ],
    );
  }
}
