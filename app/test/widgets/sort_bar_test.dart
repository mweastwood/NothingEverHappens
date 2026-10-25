import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('SortBarScrollView show/hide scroll behavior', () {
    final options = [
      const SortOption(key: 'title', label: 'Name'),
      const SortOption(key: 'due', label: 'Due Date'),
    ];

    Widget buildSortBarScrollView({
      required ProviderContainer container,
      required ScrollController controller,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: buildTestableWidget(
          child: Scaffold(
            body: SortBarScrollView(
              controller: controller,
              isSortBarVisibleProvider: showScheduleListSortBarProvider,
              leadingSlivers: const [],
              sortBar: SortBar(
                title: 'Sort by:',
                sortColumn: 'title',
                sortAscending: true,
                options: options,
                onSort: (_) {},
              ),
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SizedBox(
                      height: 80,
                      child: Text('Schedule Item $index'),
                    ),
                    childCount: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('smoothly slides down content when scrolled to top', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final container = ProviderContainer(
        overrides: [
          scheduleListSortBarOverrideProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildSortBarScrollView(container: container, controller: controller),
      );
      await tester.pumpAndSettle();

      final initialCardY = tester.getTopLeft(find.text('Schedule Item 0')).dy;

      container.read(scheduleListSortBarOverrideProvider.notifier).state = true;
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 125));
      final midCardY = tester.getTopLeft(find.text('Schedule Item 0')).dy;
      expect(midCardY, greaterThan(initialCardY));
      expect(midCardY, lessThan(initialCardY + 56.0));

      await tester.pumpAndSettle();
      final finalCardY = tester.getTopLeft(find.text('Schedule Item 0')).dy;
      expect(finalCardY, equals(initialCardY + 56.0));
    });

    testWidgets(
      'stays put when scrolled down and sort bar is shown and hidden',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final container = ProviderContainer(
          overrides: [
            scheduleListSortBarOverrideProvider.overrideWith((ref) => false),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildSortBarScrollView(container: container, controller: controller),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.text('Schedule Item 0'), const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(find.text('Schedule Item 3'), findsOneWidget);
        final item3YBeforeShow = tester
            .getTopLeft(find.text('Schedule Item 3'))
            .dy;

        container.read(scheduleListSortBarOverrideProvider.notifier).state =
            true;
        await tester.pumpAndSettle();

        final item3YAfterShow = tester
            .getTopLeft(find.text('Schedule Item 3'))
            .dy;
        expect(item3YAfterShow, equals(item3YBeforeShow));

        container.read(scheduleListSortBarOverrideProvider.notifier).state =
            false;
        await tester.pumpAndSettle();

        final item3YAfterHide = tester
            .getTopLeft(find.text('Schedule Item 3'))
            .dy;
        expect(item3YAfterHide, equals(item3YBeforeShow));
      },
    );
  });
}
