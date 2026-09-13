import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/app_snackbar.dart';

void main() {
  group('AppSnackBar', () {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(
        inverseSurface: Color(0xFF123456),
        onInverseSurface: Color(0xFF654321),
      ),
    );

    test('build creates a SnackBar with correct structure and styling', () {
      final snackBar = AppSnackBar.build(
        theme: theme,
        content: const Text('Test message'),
      );

      expect(snackBar.behavior, SnackBarBehavior.fixed);
      expect(snackBar.backgroundColor, Colors.transparent);
      expect(snackBar.elevation, 0);
      expect(snackBar.padding, EdgeInsets.zero);
      expect(snackBar.duration, AppSnackBar.defaultDuration);

      expect(snackBar.content, isA<Padding>());
      final outerPadding = snackBar.content as Padding;
      expect(
        outerPadding.padding,
        const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      );

      expect(outerPadding.child, isA<Material>());
      final material = outerPadding.child as Material;
      expect(material.color, const Color(0xFF123456));
      expect(material.elevation, 6.0);
      expect(
        material.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

      expect(material.child, isA<Padding>());
      final innerPadding = material.child as Padding;
      expect(
        innerPadding.padding,
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      );

      expect(innerPadding.child, isA<Row>());
      final row = innerPadding.child as Row;
      expect(row.children.length, 1);
      expect(row.children.first, isA<Expanded>());
    });

    test('build respects custom duration and action', () {
      final actionWidget = TextButton(
        onPressed: () {},
        child: const Text('Action'),
      );
      final customDuration = const Duration(seconds: 10);

      final snackBar = AppSnackBar.build(
        theme: theme,
        content: const Text('With action'),
        duration: customDuration,
        action: actionWidget,
      );

      expect(snackBar.duration, customDuration);

      final outerPadding = snackBar.content as Padding;
      final material = outerPadding.child as Material;
      final innerPadding = material.child as Padding;
      final row = innerPadding.child as Row;

      expect(row.children.length, 3);
      expect(row.children[0], isA<Expanded>());
      expect(row.children[1], isA<SizedBox>());
      expect(row.children[2], actionWidget);
    });

    testWidgets('DefaultTextStyle provides onInverseSurface color to content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.show(
                      context,
                      content: const Text('Default styled text'),
                    );
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final textFinder = find.text('Default styled text');
      expect(textFinder, findsOneWidget);

      final inheritedTextStyle = tester.widget<DefaultTextStyle>(
        find
            .ancestor(of: textFinder, matching: find.byType(DefaultTextStyle))
            .first,
      );
      expect(inheritedTextStyle.style.color, const Color(0xFF654321));
    });

    testWidgets('AppSnackBar.show displays snackbar in ambient scaffold', (
      tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.show(
                      context,
                      content: const Text('Hello AppSnackBar'),
                      action: TextButton(
                        onPressed: () {
                          actionTapped = true;
                        },
                        child: const Text('Press Me'),
                      ),
                    );
                  },
                  child: const Text('Trigger'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Hello AppSnackBar'), findsOneWidget);
      expect(find.text('Press Me'), findsOneWidget);

      await tester.tap(find.text('Press Me'));
      expect(actionTapped, isTrue);
    });

    testWidgets('AppSnackBar.show clearExisting clears existing snackbars', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        AppSnackBar.show(context, content: const Text('First'));
                      },
                      child: const Text('Show First'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        AppSnackBar.show(
                          context,
                          content: const Text('Second'),
                          clearExisting: true,
                        );
                      },
                      child: const Text('Show Second'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show First'));
      await tester.pump();
      expect(find.text('First'), findsOneWidget);

      await tester.tap(find.text('Show Second'));
      await tester.pump();
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsNothing);
    });

    testWidgets(
      'AppSnackBar.show returns null when no ScaffoldMessenger is present',
      (tester) async {
        ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    controller = AppSnackBar.show(
                      context,
                      content: const Text('No messenger'),
                    );
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        expect(controller, isNull);
      },
    );

    testWidgets('AppSnackBar.showWithMessenger displays snackbar', (
      tester,
    ) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: ScaffoldMessenger(
            child: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const Scaffold(body: Text('Body'));
              },
            ),
          ),
        ),
      );

      AppSnackBar.showWithMessenger(
        messenger: messenger,
        content: const Text('Messenger test'),
        clearExisting: true,
      );

      await tester.pumpAndSettle();
      expect(find.text('Messenger test'), findsOneWidget);
    });
  });
}
