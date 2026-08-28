import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/subscription_paywall_widget.dart';
import '../test_helper.dart';

void main() {
  group('SubscriptionPaywallWidget', () {
    testWidgets('renders default component hierarchy and theme styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SubscriptionPaywallWidget(
            onUpgrade: () {},
            priceString: r'$4.99/mo',
          ),
        ),
      );

      // AppBar title
      expect(find.text('Family Groups'), findsOneWidget);

      // Icon container
      expect(find.byIcon(Icons.people_outline), findsOneWidget);

      // Headline and body text
      expect(find.text('Unlock Family Groups'), findsOneWidget);
      expect(
        find.text(
          'Collaborate, delegate, and sync task progress with up to 10 family members in real-time.',
        ),
        findsOneWidget,
      );

      // Upgrade CTA button with star icon
      expect(find.byKey(const Key('upgrade_to_family_button')), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsOneWidget);

      // Restore Purchases button
      expect(find.text('Restore Purchases'), findsOneWidget);
    });

    group('Pricing String Formatting', () {
      testWidgets('formats placeholder price when priceString is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(
              onUpgrade: () {},
              priceString: null,
            ),
          ),
        );

        expect(find.text('Upgrade to Family Plan (\$X.XX/mo)'), findsOneWidget);
      });

      testWidgets('formats placeholder price when priceString is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(onUpgrade: () {}, priceString: ''),
          ),
        );

        expect(find.text('Upgrade to Family Plan (\$X.XX/mo)'), findsOneWidget);
      });

      testWidgets(
        'renders custom priceString unchanged when it already contains /mo',
        (tester) async {
          await tester.pumpWidget(
            buildTestableWidget(
              child: SubscriptionPaywallWidget(
                onUpgrade: () {},
                priceString: r'$4.99/mo',
              ),
            ),
          );

          expect(
            find.text('Upgrade to Family Plan (\$4.99/mo)'),
            findsOneWidget,
          );
        },
      );

      testWidgets('appends /mo to priceString when /mo is missing', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(
              onUpgrade: () {},
              priceString: r'$4.99',
            ),
          ),
        );

        expect(find.text('Upgrade to Family Plan (\$4.99/mo)'), findsOneWidget);
      });
    });

    testWidgets('tapping upgrade button invokes onUpgrade callback', (
      tester,
    ) async {
      bool upgraded = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: SubscriptionPaywallWidget(
            onUpgrade: () => upgraded = true,
            priceString: r'$4.99/mo',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('upgrade_to_family_button')));
      await tester.pump();

      expect(upgraded, isTrue);
    });

    testWidgets(
      'shows CircularProgressIndicator and hides CTA when isProcessing is true',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(
              onUpgrade: () {},
              isProcessing: true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const Key('upgrade_to_family_button')), findsNothing);
      },
    );

    group('Restore Purchases Behavior', () {
      testWidgets('invokes custom onRestore callback when provided', (
        tester,
      ) async {
        bool restored = false;

        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(
              onUpgrade: () {},
              onRestore: () => restored = true,
            ),
          ),
        );

        await tester.tap(find.text('Restore Purchases'));
        await tester.pump();

        expect(restored, isTrue);
      });

      testWidgets('shows fallback snackbar when onRestore callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: SubscriptionPaywallWidget(onUpgrade: () {}, onRestore: null),
          ),
        );

        await tester.tap(find.text('Restore Purchases'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Purchases restored successfully.'), findsOneWidget);
      });
    });

    testGoldens(
      'SubscriptionPaywallWidget renders correctly in idle and processing states',
      (tester) async {
        final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 0.52)
          ..addScenario(
            'Default Idle State',
            SizedBox(
              width: 380,
              height: 620,
              child: SubscriptionPaywallWidget(
                onUpgrade: () {},
                priceString: r'$4.99/mo',
              ),
            ),
          )
          ..addScenario(
            'Processing State',
            SizedBox(
              width: 380,
              height: 620,
              child: SubscriptionPaywallWidget(
                onUpgrade: () {},
                isProcessing: true,
              ),
            ),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: l10nMaterialAppWrapper(),
          surfaceSize: const Size(820, 800),
        );

        await screenMatchesGolden(
          tester,
          'subscription_paywall_widget_golden',
          customPump: (tester) async {
            await tester.pump();
          },
        );
      },
    );
  });
}
