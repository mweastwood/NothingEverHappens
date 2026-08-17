import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/markdown_styles.dart';

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
  });
}
