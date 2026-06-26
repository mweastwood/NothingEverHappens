import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/sort_bar.dart';
import '../test_helper.dart';

void main() {
  group('SortBar Widget and Golden Tests', () {
    final options = [
      const SortOption(key: 'title', label: 'Name'),
      const SortOption(key: 'due', label: 'Due Date'),
      const SortOption(key: 'priority', label: 'Priority'),
    ];

    testWidgets('SortBar triggers onSort when chip is selected', (
      WidgetTester tester,
    ) async {
      String? selectedKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SortBar(
              title: 'Sort by:',
              sortColumn: 'title',
              sortAscending: true,
              options: options,
              onSort: (key) {
                selectedKey = key;
              },
            ),
          ),
        ),
      );

      expect(find.text('Sort by:'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Due Date'), findsOneWidget);

      // Tap on 'Due Date'
      await tester.tap(find.text('Due Date'));
      await tester.pump();

      expect(selectedKey, 'due');
    });

    testGoldens('SortBar rendering states golden test', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Initial state (Title ascending)',
          SortBar(
            title: 'Sort by:',
            sortColumn: 'title',
            sortAscending: true,
            options: options,
            onSort: (_) {},
          ),
        )
        ..addScenario(
          'Title selected (descending)',
          SortBar(
            title: 'Sort by:',
            sortColumn: 'title',
            sortAscending: false,
            options: options,
            onSort: (_) {},
          ),
        )
        ..addScenario(
          'Priority selected (ascending)',
          SortBar(
            title: 'Sort by:',
            sortColumn: 'priority',
            sortAscending: true,
            options: options,
            onSort: (_) {},
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(500, 400),
      );

      await screenMatchesGolden(tester, 'sort_bar_states');
    });
  });
}
