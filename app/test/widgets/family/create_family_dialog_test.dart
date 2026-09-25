import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/family/create_family_dialog.dart';
import '../../test_helper.dart';

void main() {
  group('CreateFamilyDialog', () {
    testWidgets('shows validation error when family name is empty', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CreateFamilyDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateFamilyDialog), findsOneWidget);

      // Tap confirm with empty input
      await tester.tap(find.byKey(const Key('confirm_create_family_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a family name'), findsOneWidget);
      expect(find.byType(CreateFamilyDialog), findsOneWidget);
      expect(result, isNull);

      // Enter only whitespace
      await tester.enterText(find.byKey(const Key('family_name_field')), '   ');
      await tester.tap(find.byKey(const Key('confirm_create_family_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a family name'), findsOneWidget);
      expect(find.byType(CreateFamilyDialog), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('trims input and returns family name on submit', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CreateFamilyDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('family_name_field')),
        '  The Incredibles  ',
      );
      await tester.tap(find.byKey(const Key('confirm_create_family_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateFamilyDialog), findsNothing);
      expect(result, 'The Incredibles');
    });

    testWidgets('returns null on cancel', (tester) async {
      String? result = 'initial';
      await tester.pumpWidget(
        buildTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CreateFamilyDialog.show(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('family_name_field')),
        'Some Name',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateFamilyDialog), findsNothing);
      expect(result, isNull);
    });
  });
}
