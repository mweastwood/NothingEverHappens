import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/auth_repository.dart';
import '../logic/error_handler.dart';
import '../logic/family_repository.dart';
import '../logic/l10n_extension.dart';
import '../logic/label_repository.dart';
import '../logic/task_label.dart';
import 'save_discard_bar.dart';

class LabelEditDialog extends ConsumerStatefulWidget {
  final TaskLabel? existingLabel;
  final TaskLabelScope scope;
  final int nextOrder;

  const LabelEditDialog({
    super.key,
    this.existingLabel,
    required this.scope,
    this.nextOrder = 0,
  });

  static Future<void> show(
    BuildContext context, {
    TaskLabel? existingLabel,
    required TaskLabelScope scope,
    int nextOrder = 0,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => LabelEditDialog(
        existingLabel: existingLabel,
        scope: scope,
        nextOrder: nextOrder,
      ),
    );
  }

  @override
  ConsumerState<LabelEditDialog> createState() => _LabelEditDialogState();
}

class _LabelEditDialogState extends ConsumerState<LabelEditDialog> {
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
          if (userId.isEmpty) {
            throw StateError('User is not authenticated');
          }
          await repo.savePersonalLabel(userId, updatedLabel);
        } else {
          final familyProfile = ref.read(familyProfileStreamProvider).value;
          final familyId = familyProfile?.familyId ?? '';
          if (familyId.isEmpty) {
            throw StateError('Family ID cannot be resolved');
          }
          await repo.saveFamilyLabel(familyId, updatedLabel);
        }
      } else {
        final newLabel = TaskLabel.create(
          name: labelName,
          colorKey: _selectedColorKey,
          iconKey: _selectedIconKey,
          scope: widget.scope,
          order: widget.nextOrder,
        );

        if (widget.scope == TaskLabelScope.personal) {
          final userId = ref.read(authStateProvider).value?.uid ?? '';
          if (userId.isEmpty) {
            throw StateError('User is not authenticated');
          }
          await repo.savePersonalLabel(userId, newLabel);
        } else {
          final familyProfile = ref.read(familyProfileStreamProvider).value;
          final familyId = familyProfile?.familyId ?? '';
          if (familyId.isEmpty) {
            throw StateError('Family ID cannot be resolved');
          }
          await repo.saveFamilyLabel(familyId, newLabel);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
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
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 8.0),
      actionsPadding: EdgeInsets.zero,
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
                    return Tooltip(
                      message: colorItem.name,
                      child: InkWell(
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
                              ? Icon(
                                  Icons.check,
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                            color,
                                          ) ==
                                          Brightness.light
                                      ? Colors.black87
                                      : Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
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
                    return Tooltip(
                      message: iconItem.name,
                      child: InkWell(
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
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
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
        SaveDiscardBar(
          saveButtonKey: const Key('save_label_button'),
          onSave: _save,
          isSaving: _isSaving,
          includeSafeArea: false,
        ),
      ],
    );
  }
}
