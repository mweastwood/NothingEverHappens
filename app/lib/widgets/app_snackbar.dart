import 'package:flutter/material.dart';

class AppSnackBar {
  /// Default duration matching standard snack bars.
  static const Duration defaultDuration = Duration(seconds: 4);

  /// Builds a [SnackBar] with the application's signature floating card style.
  static SnackBar build({
    required ThemeData theme,
    required Widget content,
    Duration duration = defaultDuration,
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
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: theme.colorScheme.onInverseSurface),
                    child: content,
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8.0), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Displays an [AppSnackBar] using the ambient [BuildContext].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context, {
    required Widget content,
    Duration duration = defaultDuration,
    Widget? action,
    bool clearExisting = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    if (clearExisting) {
      messenger.clearSnackBars();
    }

    return messenger.showSnackBar(
      build(
        theme: Theme.of(context),
        content: content,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Displays an [AppSnackBar] using a pre-captured [ScaffoldMessengerState].
  /// Useful in async contexts where [BuildContext] may be invalidated across await gaps.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  showWithMessenger({
    required ScaffoldMessengerState messenger,
    required Widget content,
    Duration duration = defaultDuration,
    Widget? action,
    bool clearExisting = false,
  }) {
    if (clearExisting) {
      messenger.clearSnackBars();
    }

    return messenger.showSnackBar(
      build(
        theme: Theme.of(messenger.context),
        content: content,
        duration: duration,
        action: action,
      ),
    );
  }
}
