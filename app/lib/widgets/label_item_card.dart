import 'package:flutter/material.dart';

import '../logic/l10n_extension.dart';
import '../logic/task_label.dart';

class LabelItemCard extends StatelessWidget {
  final TaskLabel label;
  final int? index;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LabelItemCard({
    super.key,
    required this.label,
    this.index,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                    tooltip: context.l10n.editButton,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    key: Key('delete_label_${label.id}'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.deleteButton,
                    onPressed: onDelete,
                  ),
                  if (index != null)
                    ReorderableDragStartListener(
                      index: index!,
                      child: IconButton(
                        key: Key('drag_handle_${label.id}'),
                        icon: const Icon(Icons.drag_handle),
                        onPressed: null,
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
