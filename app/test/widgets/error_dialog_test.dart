import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';

void main() {
  group('ErrorHandler Dialog Golden Test', () {
    testGoldens('Error dialog renders correctly', (WidgetTester tester) async {
      final errorHandler = ErrorHandler();
      final report = ErrorReport(
        code: 'ERR123',
        error: 'Exception: Failed to load tasks from server',
        timestamp: DateTime(2026, 10, 26),
      );

      await tester.pumpWidgetBuilder(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('show_dialog_button'),
                  onPressed: () {
                    errorHandler.showErrorDialog(context, report);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            );
          },
        ),
        wrapper: materialAppWrapper(
          theme: ThemeData.light(useMaterial3: true).copyWith(
            shadowColor: Colors.transparent,
            textTheme: ThemeData.light(
              useMaterial3: true,
            ).textTheme.apply(fontFamily: 'Ahem'),
          ),
          platform: TargetPlatform.android,
        ),
        surfaceSize: const Size(800, 600),
      );

      // Tap to trigger the error dialog
      await tester.tap(find.byKey(const Key('show_dialog_button')));
      await tester.pumpAndSettle();

      // Verify the dialog elements render
      expect(find.text('Error Occurred'), findsOneWidget);
      expect(find.text('ERR123'), findsOneWidget);
      expect(
        find.text('Exception: Failed to load tasks from server'),
        findsOneWidget,
      );

      // Match the golden screen image
      await screenMatchesGolden(tester, 'error_dialog');
    });
  });
}
