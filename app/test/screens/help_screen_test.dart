import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/screens/help_screen.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget() {
    return buildTestableWidget(child: const HelpScreen());
  }

  testWidgets('HelpScreen loads with correct title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Help Content coming soon...'), findsOneWidget);
  });

  testGoldens('HelpScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidgetBuilder(
      const HelpScreen(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'help_screen_base');
  });
}
