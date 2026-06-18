import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/undo_notifier.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class UndoSnackBar {
  /// Show an undo snackbar from a synchronous context where [BuildContext] is
  /// still valid (e.g. button tap handlers, animation completion callbacks).
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required UndoableAction action,
    required TaskRepository repository,
  }) {
    final notifier = ref.read(undoNotifierProvider.notifier);
    notifier.register(action);

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final undoLabel = context.l10n.undoButton;
    final undoneLabel = context.l10n.actionUndone;

    _showSnackBar(
      notifier: notifier,
      messenger: messenger,
      theme: theme,
      action: action,
      repository: repository,
      undoLabel: undoLabel,
      undoneLabel: undoneLabel,
    );
  }

  /// Show an undo snackbar using a pre-captured [ScaffoldMessengerState].
  /// Use this variant inside async callbacks where [BuildContext] may no longer
  /// be valid after an await gap. Capture the messenger and any localized
  /// strings from [context] *before* the first await, then call this method.
  static void showWithMessenger({
    required ScaffoldMessengerState messenger,
    required WidgetRef ref,
    required UndoableAction action,
    required TaskRepository repository,
    String undoLabel = 'Undo',
    String undoneLabel = 'Undone',
  }) {
    final notifier = ref.read(undoNotifierProvider.notifier);
    notifier.register(action);

    _showSnackBar(
      notifier: notifier,
      messenger: messenger,
      theme: Theme.of(messenger.context),
      action: action,
      repository: repository,
      undoLabel: undoLabel,
      undoneLabel: undoneLabel,
    );
  }

  static void _showSnackBar({
    required UndoNotifier notifier,
    required ScaffoldMessengerState messenger,
    required ThemeData theme,
    required UndoableAction action,
    required TaskRepository repository,
    required String undoLabel,
    required String undoneLabel,
  }) {
    messenger.clearSnackBars();

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
          label: undoLabel,
          textColor: theme.colorScheme.inversePrimary,
          onPressed: () async {
            final success = await notifier.undo(repository);

            if (success) {
              messenger.clearSnackBars();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(undoneLabel),
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
