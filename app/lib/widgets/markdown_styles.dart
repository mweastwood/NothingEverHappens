import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Helper utilities for creating consistent [MarkdownStyleSheet] instances across the app.
class MarkdownStyles {
  /// Default block spacing between elements (paragraphs, list items, etc.) in descriptions.
  static const double descriptionBlockSpacing = 3.0;

  /// Creates a [MarkdownStyleSheet] for task descriptions with reduced vertical spacing
  /// between bullet points and list elements.
  static MarkdownStyleSheet taskDescription(
    BuildContext context, {
    TextStyle? textStyle,
    double blockSpacing = descriptionBlockSpacing,
  }) {
    return taskDescriptionFromTheme(
      Theme.of(context),
      textStyle: textStyle,
      blockSpacing: blockSpacing,
    );
  }

  /// Creates a [MarkdownStyleSheet] for task descriptions from [ThemeData] with reduced vertical spacing
  /// between bullet points and list elements.
  static MarkdownStyleSheet taskDescriptionFromTheme(
    ThemeData theme, {
    TextStyle? textStyle,
    double blockSpacing = descriptionBlockSpacing,
  }) {
    final baseStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    final baseTextStyle = textStyle ?? theme.textTheme.bodyMedium;

    return baseStyleSheet.copyWith(
      p: baseTextStyle,
      listBullet: baseTextStyle,
      pPadding: EdgeInsets.zero,
      blockSpacing: blockSpacing,
    );
  }
}
