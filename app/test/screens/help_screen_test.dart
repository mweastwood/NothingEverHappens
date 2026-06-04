import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/screens/help_screen.dart';
import '../test_helper.dart';

void main() {
  Widget buildTestWidget() {
    return buildTestableWidget(child: const HelpScreen());
  }

  testWidgets('HelpScreen loads with correct title', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Help & Documentation Content coming soon...'), findsOneWidget);
  });
}
