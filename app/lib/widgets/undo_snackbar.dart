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
    String? undoneLabel,
  }) {
    final notifier = ref.read(undoNotifierProvider.notifier);
    notifier.register(action);

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final undoLabel = context.l10n.undoButton;
    final finalUndoneLabel = undoneLabel ?? context.l10n.actionUndone;

    _showSnackBar(
      notifier: notifier,
      messenger: messenger,
      theme: theme,
      action: action,
      repository: repository,
      undoLabel: undoLabel,
      undoneLabel: finalUndoneLabel,
    );
  }

  /// Show an undo snackbar using a pre-captured [ScaffoldMessengerState] and [UndoNotifier].
  /// Use this variant inside async callbacks where [BuildContext] may no longer
  /// be valid after an await gap. Capture the messenger, undo notifier, and any
  /// localized strings from [context] *before* the first await, then call this method.
  static void showWithMessenger({
    required ScaffoldMessengerState messenger,
    required UndoNotifier notifier,
    required UndoableAction action,
    required TaskRepository repository,
    String undoLabel = 'Undo',
    String undoneLabel = 'Undone',
  }) {
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

  static SnackBar _buildCustomSnackBar({
    required ThemeData theme,
    required Widget content,
    required Duration duration,
    Widget? action,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: duration,
      content: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: Material(
          color: theme.colorScheme.inverseSurface,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Row(
              children: [
                Expanded(child: content),
                if (action != null) ...[const SizedBox(width: 8.0), action],
              ],
            ),
          ),
        ),
      ),
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
      _buildCustomSnackBar(
        theme: theme,
        duration: const Duration(seconds: 4),
        content: Text(
          action.message,
          style: TextStyle(color: theme.colorScheme.onInverseSurface),
        ),
        action: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () async {
            final success = await notifier.undo(repository);

            if (success) {
              messenger.clearSnackBars();
              messenger.showSnackBar(
                _buildCustomSnackBar(
                  theme: theme,
                  duration: const Duration(seconds: 2),
                  content: Text(
                    undoneLabel,
                    style: TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
                ),
              );
            }
          },
          child: Text(
            undoLabel,
            style: TextStyle(
              color: theme.colorScheme.inversePrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
