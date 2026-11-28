import 'package:material_ui/material_ui.dart';
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
    final bodyMedium = theme.textTheme.bodyMedium;
    final baseTextStyle = textStyle ?? bodyMedium;

    return MarkdownStyleSheet(
      a: const TextStyle(color: Colors.blue),
      p: baseTextStyle,
      pPadding: EdgeInsets.zero,
      code: bodyMedium?.copyWith(
        backgroundColor: theme.cardTheme.color,
        fontFamily: 'monospace',
        fontSize: bodyMedium.fontSize != null
            ? bodyMedium.fontSize! * 0.85
            : null,
      ),
      h1: theme.textTheme.headlineSmall,
      h1Padding: EdgeInsets.zero,
      h2: theme.textTheme.titleLarge,
      h2Padding: EdgeInsets.zero,
      h3: theme.textTheme.titleMedium,
      h3Padding: EdgeInsets.zero,
      h4: theme.textTheme.bodyLarge,
      h4Padding: EdgeInsets.zero,
      h5: theme.textTheme.bodyLarge,
      h5Padding: EdgeInsets.zero,
      h6: theme.textTheme.bodyLarge,
      h6Padding: EdgeInsets.zero,
      em: const TextStyle(fontStyle: FontStyle.italic),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      del: const TextStyle(decoration: TextDecoration.lineThrough),
      blockquote: bodyMedium,
      img: bodyMedium,
      checkbox: bodyMedium?.copyWith(color: theme.primaryColor),
      blockSpacing: blockSpacing,
      listIndent: 24.0,
      listBullet: baseTextStyle,
      listBulletPadding: const EdgeInsets.only(right: 4),
      tableHead: const TextStyle(fontWeight: FontWeight.w600),
      tableBody: bodyMedium,
      tableHeadAlign: TextAlign.center,
      tablePadding: const EdgeInsets.only(bottom: 4.0),
      tableBorder: TableBorder.all(color: theme.dividerColor),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      tableCellsDecoration: const BoxDecoration(),
      blockquotePadding: const EdgeInsets.all(8.0),
      blockquoteDecoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(2.0),
      ),
      codeblockPadding: const EdgeInsets.all(8.0),
      codeblockDecoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(2.0),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(width: 5.0, color: theme.dividerColor)),
      ),
    );
  }
}
