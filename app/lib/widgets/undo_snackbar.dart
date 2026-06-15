import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/undo_notifier.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class UndoSnackBar {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required UndoableAction action,
    required TaskRepository repository,
  }) {
    ref.read(undoNotifierProvider.notifier).register(action);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final theme = Theme.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          action.message,
          style: TextStyle(color: theme.colorScheme.onInverseSurface),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.colorScheme.inverseSurface,
        elevation: 6,
        action: SnackBarAction(
          label: context.l10n.undoButton,
          textColor: theme.colorScheme.inversePrimary,
          onPressed: () async {
            final success = await ref
                .read(undoNotifierProvider.notifier)
                .undo(repository);

            if (success && context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.actionUndone),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
