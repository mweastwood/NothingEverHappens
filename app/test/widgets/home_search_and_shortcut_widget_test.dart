import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nothing_ever_happens/widgets/home_search_and_shortcut_widget.dart';
import '../test_helper.dart';

void main() {
  Widget createWidget({
    required int currentIndex,
    required Widget Function(BuildContext, bool, PreferredSizeWidget) builder,
  }) {
    return ProviderScope(
      child: buildTestableWidget(
        child: HomeSearchAndShortcutWidget(
          currentIndex: currentIndex,
          builder: builder,
        ),
      ),
    );
  }

  testWidgets('HomeSearchAndShortcutWidget starts with search closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWidget(
        currentIndex: 0,
        builder: (context, isSearching, appBar) {
          return Scaffold(appBar: appBar, body: const SizedBox());
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('HomeSearchAndShortcutWidget opens search on search button tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWidget(
        currentIndex: 0,
        builder: (context, isSearching, appBar) {
          return Scaffold(appBar: appBar, body: const SizedBox());
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });
}
