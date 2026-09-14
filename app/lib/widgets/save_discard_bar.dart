import 'package:flutter/material.dart';

import '../logic/l10n_extension.dart';

/// A standardized bottom action bar featuring Discard and Save buttons.
///
/// Ensures consistent layout, typography, button variants (OutlinedButton for Discard,
/// FilledButton for Save), spacing, and loading spinner behavior across both full screens
/// and modal dialogs.
class SaveDiscardBar extends StatelessWidget {
  /// Callback invoked when the save button is tapped. If null, the button is disabled.
  final VoidCallback? onSave;

  /// Callback invoked when the discard button is tapped.
  /// If omitted, defaults to popping the current route via [Navigator.pop].
  final VoidCallback? onDiscard;

  /// Whether a save operation is in progress.
  /// When true, both buttons are disabled and a progress indicator is displayed on Save.
  final bool isSaving;

  /// Optional widget key for the save button.
  final Key? saveButtonKey;

  /// Optional widget key for the discard button.
  final Key? discardButtonKey;

  /// Text displayed on the save button. Defaults to [context.l10n.saveButton] ('Save').
  final String? saveLabel;

  /// Text displayed on the discard button. Defaults to [context.l10n.discardButton] ('Discard').
  final String? discardLabel;

  /// Padding surrounding the button row. Defaults to 16px horizontal and 8px vertical.
  final EdgeInsetsGeometry padding;

  /// Horizontal spacing between the discard and save buttons. Defaults to 16px.
  final double spacing;

  /// Whether to wrap the bar in a bottom [SafeArea]. Defaults to true.
  /// Set to false when used inside dialogs or containers that already manage insets.
  final bool includeSafeArea;

  /// Whether animations should be frozen at a fixed progress value for deterministic golden tests.
  final bool debugDisableAnimations;

  const SaveDiscardBar({
    super.key,
    required this.onSave,
    this.onDiscard,
    this.isSaving = false,
    this.saveButtonKey,
    this.discardButtonKey,
    this.saveLabel,
    this.discardLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.spacing = 16.0,
    this.includeSafeArea = true,
    this.debugDisableAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDiscard = onDiscard ?? () => Navigator.of(context).pop();

    final bar = Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            key: discardButtonKey,
            onPressed: isSaving ? null : effectiveDiscard,
            child: Text(discardLabel ?? context.l10n.discardButton),
          ),
          SizedBox(width: spacing),
          FilledButton(
            key: saveButtonKey,
            onPressed: isSaving ? null : onSave,
            child: isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: debugDisableAnimations ? 0.8 : null,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(saveLabel ?? context.l10n.saveButton),
          ),
        ],
      ),
    );

    if (includeSafeArea) {
      return SafeArea(top: false, child: bar);
    }
    return bar;
  }
}
