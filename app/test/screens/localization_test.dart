import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/l10n_extension.dart';

void main() {
  group('AppLocalizations Tests', () {
    Widget buildTestWidget({Locale locale = const Locale('en')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  Text(
                    context.l10n?.appName ?? 'Fallback App Name',
                    key: const Key('app_name_text'),
                  ),
                  Text(
                    context.l10n?.errorOccurred ?? 'Fallback Error Occurred',
                    key: const Key('error_occurred_text'),
                  ),
                  Text(
                    context.l10n?.deleteTaskConfirmBody('Task Alpha') ??
                        'Fallback Delete Body',
                    key: const Key('delete_body_text'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    testWidgets('AppLocalizations loads English translations correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final appNameFinder = find.byKey(const Key('app_name_text'));
      final errorOccurredFinder = find.byKey(const Key('error_occurred_text'));
      final deleteBodyFinder = find.byKey(const Key('delete_body_text'));

      expect(tester.widget<Text>(appNameFinder).data, 'Nothing Ever Happens');
      expect(tester.widget<Text>(errorOccurredFinder).data, 'Error Occurred');
      expect(
        tester.widget<Text>(deleteBodyFinder).data,
        'Are you sure you want to delete "Task Alpha"? This action will permanently remove the task.',
      );
    });

    testWidgets('AppLocalizations loads Spanish translations correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('es')));
      await tester.pumpAndSettle();

      final appNameFinder = find.byKey(const Key('app_name_text'));
      final errorOccurredFinder = find.byKey(const Key('error_occurred_text'));
      final deleteBodyFinder = find.byKey(const Key('delete_body_text'));

      expect(tester.widget<Text>(appNameFinder).data, 'Nunca Pasa Nada');
      expect(tester.widget<Text>(errorOccurredFinder).data, 'Ocurrió un error');
      expect(
        tester.widget<Text>(deleteBodyFinder).data,
        '¿Estás seguro de que quieres eliminar "Task Alpha"? Esta acción eliminará permanentemente la tarea.',
      );
    });

    testWidgets('L10n fallback pattern works when localizations are absent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Text(
                  context.l10n?.appName ?? 'Fallback App Name',
                  key: const Key('fallback_text'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fallbackTextFinder = find.byKey(const Key('fallback_text'));
      expect(tester.widget<Text>(fallbackTextFinder).data, 'Fallback App Name');
    });
  });
}
