import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/l10n_extension.dart';

void main() {
  group('AppLocalizations Strict Enforcement & Templating Tests', () {
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
                  Text(context.l10n.appName, key: const Key('app_name_text')),
                  Text(
                    context.l10n.errorOccurred,
                    key: const Key('error_occurred_text'),
                  ),
                  Text(
                    context.l10n.deleteTaskConfirmBody('Task Alpha'),
                    key: const Key('delete_body_text'),
                  ),
                  Text(
                    context.l10n.everyNDays(3),
                    key: const Key('every_n_days_text'),
                  ),
                  Text(
                    context.l10n.everyNWeeks(4),
                    key: const Key('every_n_weeks_text'),
                  ),
                  Text(
                    context.l10n.startingDate('2026-05-29'),
                    key: const Key('starting_date_text'),
                  ),
                  Text(
                    context.l10n.onDaysOfWeek('Mon, Wed'),
                    key: const Key('on_days_text'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    testWidgets(
      'AppLocalizations loads English translations and templates correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.byKey(const Key('app_name_text'))).data,
          'Nothing Ever Happens',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('error_occurred_text')))
              .data,
          'Error Occurred',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('delete_body_text'))).data,
          'Are you sure you want to delete "Task Alpha"? This action will permanently remove the task.',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('every_n_days_text'))).data,
          'Every 3 days',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('every_n_weeks_text'))).data,
          'Every 4 weeks',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('starting_date_text'))).data,
          'Starting: 2026-05-29',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('on_days_text'))).data,
          'On: Mon, Wed',
        );
      },
    );

    testWidgets(
      'AppLocalizations loads Spanish translations and templates correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget(locale: const Locale('es')));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.byKey(const Key('app_name_text'))).data,
          'Nunca Pasa Nada',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('error_occurred_text')))
              .data,
          'Ocurrió un error',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('delete_body_text'))).data,
          '¿Estás seguro de que quieres eliminar "Task Alpha"? Esta acción eliminará permanentemente la tarea.',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('every_n_days_text'))).data,
          'Cada 3 días',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('every_n_weeks_text'))).data,
          'Cada 4 semanas',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('starting_date_text'))).data,
          'Comenzando: 2026-05-29',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('on_days_text'))).data,
          'En: Mon, Wed',
        );
      },
    );

    testWidgets(
      'Strict enforcement throws an exception when localizations are absent',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Accessing context.l10n should throw a null assertion/type error
                  // because localizations are not provided in this tree.
                  final _ = context.l10n.appName;
                  return const Text('Should not render');
                },
              ),
            ),
          ),
        );

        // Verify that building the widget threw an assertion or type error
        expect(tester.takeException(), isNotNull);
      },
    );
  });
}
