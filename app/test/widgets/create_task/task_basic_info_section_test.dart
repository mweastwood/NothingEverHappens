import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/widgets/create_task/task_basic_info_section.dart';

void main() {
  Widget buildWidget({
    required TextEditingController titleController,
    required TextEditingController descriptionController,
    FocusNode? titleFocusNode,
    Key? titleFieldKey,
    bool readOnly = false,
    GlobalKey<FormState>? formKey,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: TaskBasicInfoSection(
              titleController: titleController,
              descriptionController: descriptionController,
              titleFocusNode: titleFocusNode,
              titleFieldKey: titleFieldKey,
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );
  }

  group('TaskBasicInfoSection', () {
    testWidgets('renders title and description fields with controller text', (
      WidgetTester tester,
    ) async {
      final titleController = TextEditingController(text: 'Initial Title');
      final descriptionController = TextEditingController(
        text: 'Initial Description',
      );

      await tester.pumpWidget(
        buildWidget(
          titleController: titleController,
          descriptionController: descriptionController,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Initial Title'), findsOneWidget);
      expect(find.text('Initial Description'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('updates controller text when user inputs text', (
      WidgetTester tester,
    ) async {
      final titleController = TextEditingController();
      final descriptionController = TextEditingController();

      await tester.pumpWidget(
        buildWidget(
          titleController: titleController,
          descriptionController: descriptionController,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'Clean Room');
      await tester.enterText(textFields.last, 'Vacuum and dust surfaces');
      await tester.pumpAndSettle();

      expect(titleController.text, 'Clean Room');
      expect(descriptionController.text, 'Vacuum and dust surfaces');
    });

    testWidgets('fails validation when title is empty', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final titleController = TextEditingController(text: '');
      final descriptionController = TextEditingController();

      await tester.pumpWidget(
        buildWidget(
          formKey: formKey,
          titleController: titleController,
          descriptionController: descriptionController,
        ),
      );
      await tester.pumpAndSettle();

      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isValid, isFalse);
      expect(find.text('Please enter a title'), findsOneWidget);
    });

    testWidgets('fails validation when title is only whitespace', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final titleController = TextEditingController(text: '   \t\n  ');
      final descriptionController = TextEditingController();

      await tester.pumpWidget(
        buildWidget(
          formKey: formKey,
          titleController: titleController,
          descriptionController: descriptionController,
        ),
      );
      await tester.pumpAndSettle();

      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isValid, isFalse);
      expect(find.text('Please enter a title'), findsOneWidget);
    });

    testWidgets('passes validation when title contains non-empty text', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final titleController = TextEditingController(text: 'Buy Groceries');
      final descriptionController = TextEditingController();

      await tester.pumpWidget(
        buildWidget(
          formKey: formKey,
          titleController: titleController,
          descriptionController: descriptionController,
        ),
      );
      await tester.pumpAndSettle();

      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(isValid, isTrue);
      expect(find.text('Please enter a title'), findsNothing);
    });

    testWidgets(
      'disables fields and suppresses autofocus when readOnly is true',
      (WidgetTester tester) async {
        final titleController = TextEditingController(text: 'Read-only Title');
        final descriptionController = TextEditingController(
          text: 'Read-only Desc',
        );

        await tester.pumpWidget(
          buildWidget(
            titleController: titleController,
            descriptionController: descriptionController,
            readOnly: true,
          ),
        );
        await tester.pumpAndSettle();

        final textFields = tester.widgetList<TextField>(find.byType(TextField));
        final titleField = textFields.first;
        final descField = textFields.last;

        expect(titleField.enabled, isFalse);
        expect(titleField.autofocus, isFalse);
        expect(descField.enabled, isFalse);
      },
    );

    testWidgets(
      'enables fields and sets autofocus on title when readOnly is false',
      (WidgetTester tester) async {
        final titleController = TextEditingController();
        final descriptionController = TextEditingController();

        await tester.pumpWidget(
          buildWidget(
            titleController: titleController,
            descriptionController: descriptionController,
            readOnly: false,
          ),
        );
        await tester.pumpAndSettle();

        final textFields = tester.widgetList<TextField>(find.byType(TextField));
        final titleField = textFields.first;
        final descField = textFields.last;

        expect(titleField.enabled, isTrue);
        expect(titleField.autofocus, isTrue);
        expect(descField.enabled, isTrue);
      },
    );

    testWidgets('attaches titleFocusNode and titleFieldKey to title field', (
      WidgetTester tester,
    ) async {
      final titleController = TextEditingController();
      final descriptionController = TextEditingController();
      final focusNode = FocusNode();
      const customKey = Key('task_title_custom_key');

      await tester.pumpWidget(
        buildWidget(
          titleController: titleController,
          descriptionController: descriptionController,
          titleFocusNode: focusNode,
          titleFieldKey: customKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(customKey), findsOneWidget);
      final textField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(customKey),
          matching: find.byType(TextField),
        ),
      );
      expect(textField.focusNode, same(focusNode));

      focusNode.dispose();
    });
  });
}
