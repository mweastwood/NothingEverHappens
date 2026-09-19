import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/sort_bar.dart';
import '../test_helper.dart';

void main() {
  group('SortBar with Filters Tests', () {
    final options = [
      const SortOption(key: 'title', label: 'Title'),
      const SortOption(key: 'due', label: 'Due'),
      const SortOption(key: 'priority', label: 'Priority'),
    ];

    testWidgets('Displays filter button and triggers callback', (
      WidgetTester tester,
    ) async {
      bool openedFilter = false;

      await tester.pumpWidget(
        l10nMaterialAppWrapper()(
          Scaffold(
            body: SortBar(
              title: 'Sort by:',
              sortColumn: 'title',
              sortAscending: true,
              options: options,
              onSort: (_) {},
              onOpenFilterSheet: () {
                openedFilter = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Filter'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      await tester.tap(find.text('Filter'), warnIfMissed: false);
      await tester.pump();

      expect(openedFilter, isTrue);
    });

    testWidgets(
      'Displays active count and clear button when activeFilterCount > 0',
      (WidgetTester tester) async {
        bool cleared = false;

        await tester.pumpWidget(
          l10nMaterialAppWrapper()(
            Scaffold(
              body: SortBar(
                title: 'Sort by:',
                sortColumn: 'title',
                sortAscending: true,
                options: options,
                onSort: (_) {},
                activeFilterCount: 3,
                onOpenFilterSheet: () {},
                onClearFilters: () {
                  cleared = true;
                },
                filterChips: const [
                  Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text('Work'),
                      selected: true,
                      onSelected: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Filter (3)'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Clear'), findsOneWidget);

        await tester.tap(find.text('Clear'), warnIfMissed: false);
        await tester.pump();

        expect(cleared, isTrue);
      },
    );

    testGoldens('SortBar with filters golden test', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Sort bar with filter button (0 active)',
          SortBar(
            title: 'Sort by:',
            sortColumn: 'title',
            sortAscending: true,
            options: options,
            onSort: (_) {},
            onOpenFilterSheet: () {},
            filterChips: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: const Text('Work'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: const Text('Home'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
        )
        ..addScenario(
          'Sort bar with active filters & chips',
          SortBar(
            title: 'Sort by:',
            sortColumn: 'due',
            sortAscending: true,
            options: options,
            onSort: (_) {},
            activeFilterCount: 2,
            onOpenFilterSheet: () {},
            onClearFilters: () {},
            filterChips: [
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  avatar: Icon(Icons.alarm_off, size: 14),
                  label: Text('Overdue'),
                  selected: true,
                  onSelected: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: const Text('Work'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 300),
      );

      await screenMatchesGolden(tester, 'sort_bar_filters_states');
    });
  });
}
