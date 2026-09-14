import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/save_discard_bar.dart';

import '../test_helper.dart';

void main() {
  group('SaveDiscardBar', () {
    testWidgets('renders default labels and triggers callbacks', (
      tester,
    ) async {
      bool saveCalled = false;
      bool discardCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: SaveDiscardBar(
              onSave: () => saveCalled = true,
              onDiscard: () => discardCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(discardCalled, isTrue);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saveCalled, isTrue);
    });

    testWidgets('defaults onDiscard to popping navigator when omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const Scaffold(body: SaveDiscardBar(onSave: null)),
                      ),
                    );
                  },
                  child: const Text('Open Page'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();

      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Open Page'), findsOneWidget);
    });

    testWidgets('renders custom labels and keys', (tester) async {
      const saveKey = Key('my_save_key');
      const discardKey = Key('my_discard_key');

      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SaveDiscardBar(
              onSave: null,
              saveButtonKey: saveKey,
              discardButtonKey: discardKey,
              saveLabel: 'Submit Form',
              discardLabel: 'Cancel Edit',
            ),
          ),
        ),
      );

      expect(find.byKey(saveKey), findsOneWidget);
      expect(find.byKey(discardKey), findsOneWidget);
      expect(find.text('Submit Form'), findsOneWidget);
      expect(find.text('Cancel Edit'), findsOneWidget);
    });

    testWidgets(
      'disables buttons and shows CircularProgressIndicator when isSaving is true',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(
              body: SaveDiscardBar(
                onSave: null,
                isSaving: true,
                debugDisableAnimations: true,
              ),
            ),
          ),
        );

        final discardButton = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(discardButton.onPressed, isNull);

        final saveButton = tester.widget<FilledButton>(
          find.byType(FilledButton),
        );
        expect(saveButton.onPressed, isNull);

        final progressIndicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progressIndicator.value, 0.8);
        expect(progressIndicator.color, Colors.white);
        expect(progressIndicator.strokeWidth, 2.0);
      },
    );

    testWidgets('respects includeSafeArea flag', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SaveDiscardBar(onSave: null, includeSafeArea: true),
          ),
        ),
      );
      expect(find.byType(SafeArea), findsOneWidget);

      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SaveDiscardBar(onSave: null, includeSafeArea: false),
          ),
        ),
      );
      expect(find.byType(SafeArea), findsNothing);
    });

    testWidgets('applies custom padding and spacing', (tester) async {
      const customPadding = EdgeInsets.all(24.0);
      const customSpacing = 32.0;

      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SaveDiscardBar(
              onSave: null,
              includeSafeArea: false,
              padding: customPadding,
              spacing: customSpacing,
            ),
          ),
        ),
      );

      final paddingFinder = find.descendant(
        of: find.byType(SaveDiscardBar),
        matching: find.byType(Padding),
      );
      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      expect(paddingWidget.padding, customPadding);

      // Verify the horizontal spacer between buttons
      final spacerFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == customSpacing,
      );
      expect(spacerFinder, findsOneWidget);
    });
  });
}
