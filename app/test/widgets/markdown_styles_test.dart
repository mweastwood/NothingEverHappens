import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/markdown_styles.dart';
import '../test_helper.dart';

void main() {
  group('MarkdownStyles', () {
    testWidgets(
      'taskDescription creates stylesheet with reduced bullet/block spacing',
      (WidgetTester tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final expectedBody = Theme.of(capturedContext).textTheme.bodyMedium;
        final styleSheet = MarkdownStyles.taskDescription(capturedContext);

        expect(
          styleSheet.blockSpacing,
          equals(MarkdownStyles.descriptionBlockSpacing),
        );
        expect(styleSheet.blockSpacing, equals(3.0));
        expect(styleSheet.pPadding, equals(EdgeInsets.zero));
        expect(styleSheet.p, equals(expectedBody));
        expect(styleSheet.listBullet, equals(expectedBody));
      },
    );

    testWidgets('taskDescription respects custom textStyle and blockSpacing', (
      WidgetTester tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const customStyle = TextStyle(fontSize: 12, color: Colors.amber);
      final styleSheet = MarkdownStyles.taskDescription(
        capturedContext,
        textStyle: customStyle,
        blockSpacing: 2.0,
      );

      expect(styleSheet.blockSpacing, equals(2.0));
      expect(styleSheet.pPadding, equals(EdgeInsets.zero));
      expect(styleSheet.p, equals(customStyle));
      expect(styleSheet.listBullet, equals(customStyle));
    });

    testWidgets(
      'taskDescriptionFromTheme configures styles correctly from ThemeData',
      (WidgetTester tester) async {
        late ThemeData capturedTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                capturedTheme = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final styleSheet = MarkdownStyles.taskDescriptionFromTheme(
          capturedTheme,
        );

        expect(styleSheet.blockSpacing, equals(3.0));
        expect(styleSheet.pPadding, equals(EdgeInsets.zero));
        expect(styleSheet.p, equals(capturedTheme.textTheme.bodyMedium));
        expect(
          styleSheet.listBullet,
          equals(capturedTheme.textTheme.bodyMedium),
        );
      },
    );

    testGoldens('MarkdownStyles compact vertical line spacing golden scenarios', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Bullet List (Compact Spacing)',
          Container(
            width: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) => MarkdownBody(
                data:
                    '- Buy groceries at supermarket\n- Water the houseplants\n- Take out recycling bin',
                styleSheet: MarkdownStyles.taskDescription(context),
              ),
            ),
          ),
        )
        ..addScenario(
          'Numbered List (Compact Spacing)',
          Container(
            width: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) => MarkdownBody(
                data:
                    '1. Preheat oven to 375°F\n2. Mix ingredients in large bowl\n3. Bake for 25 minutes until golden',
                styleSheet: MarkdownStyles.taskDescription(context),
              ),
            ),
          ),
        )
        ..addScenario(
          'Mixed Paragraphs & Bullets',
          Container(
            width: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) => MarkdownBody(
                data:
                    'Weekly review tasks:\n- Review sprint backlog and tickets\n- Submit expense reports\nAll tasks must be finalized before Friday.',
                styleSheet: MarkdownStyles.taskDescription(context),
              ),
            ),
          ),
        )
        ..addScenario(
          'Formatted Bullets (Bold, Italic, Code)',
          Container(
            width: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) => MarkdownBody(
                data:
                    '- Task with **bold text** formatting\n- Task with *italic emphasis* notes\n- Task with `code_identifier` details',
                styleSheet: MarkdownStyles.taskDescription(context),
              ),
            ),
          ),
        )
        ..addScenario(
          'Dark Theme Bullet List',
          Theme(
            data: ThemeData.dark(),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Builder(
                builder: (context) => MarkdownBody(
                  data:
                      '- Dark theme item one\n- Dark theme item two with *italics*\n- Dark theme item three with **bold**',
                  styleSheet: MarkdownStyles.taskDescription(context),
                ),
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 1000),
      );

      await screenMatchesGolden(
        tester,
        'markdown_styles_compact_spacing_golden',
      );
    });
  });
}
