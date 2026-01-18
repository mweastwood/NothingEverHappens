import 'package:flutter_test/flutter_test.dart';

import 'package:nothing_ever_happens/main.dart';

void main() {
  testWidgets('Task list smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our title is present
    expect(find.text('Nothing Ever Happens'), findsOneWidget);

    // Verify that we have some fake tasks
    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('Walk the dog'), findsOneWidget);
    expect(find.text('Weekly meeting'), findsOneWidget);
  });
}
