import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      overrides: defaultTestOverrides,
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

  testWidgets('pressing slash key focuses the search input', (
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

    final node = Focus.of(tester.element(find.byType(Scaffold).first));
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final textFieldFocus = tester
        .widget<TextField>(find.byType(TextField))
        .focusNode;
    expect(textFieldFocus?.hasFocus, isTrue);
  });

  testWidgets('pressing Escape key collapses the search input', (
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

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('system back button collapses the search input', (
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

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    final bool handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });
}
