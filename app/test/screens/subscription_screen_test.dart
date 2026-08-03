import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/screens/subscription_screen.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import '../test_helper.dart';

void main() {
  testWidgets(
    'SubscriptionScreen renders all 3 tiers (Free, Individual, Family)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.free),
            ),
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$1.99'),
            ),
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$4.99'),
            ),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Current Tier'), findsOneWidget);
      expect(find.text('Free Tier'), findsWidgets);
      expect(find.text('Individual Subscription'), findsWidgets);
      expect(find.text('Family Subscription'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('upgrade_to_individual_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('subscription_screen_upgrade_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SubscriptionScreen renders explicit \$X.XX/mo fallback when prices are null',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.free),
            ),
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value(null),
            ),
            familyPlanPriceProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$X.XX/mo'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('Upgrade to Individual Subscription (\$X.XX/mo)'),
        findsOneWidget,
      );
      expect(
        find.text('Upgrade to Family Subscription (\$X.XX/mo)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SubscriptionScreen renders active status for Individual tier and hides Individual upgrade button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.standard),
            ),
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$1.99'),
            ),
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$4.99'),
            ),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Individual Subscription'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('upgrade_to_individual_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('subscription_screen_upgrade_button')),
        findsOneWidget,
      );
    },
  );

  testGoldens('SubscriptionScreen golden - Free Tier with \$X.XX fallback', (
    WidgetTester tester,
  ) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [Device.phone])
      ..addScenario(
        widget: ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.free),
            ),
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value(null),
            ),
            familyPlanPriceProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
        name: 'free_tier_fallback',
      );

    await tester.pumpDeviceBuilder(builder);
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'subscription_screen_free_tier_fallback');
  });

  testGoldens('SubscriptionScreen golden - Active Family Tier', (
    WidgetTester tester,
  ) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [Device.phone])
      ..addScenario(
        widget: ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.family),
            ),
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$1.99'),
            ),
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$4.99'),
            ),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
        name: 'family_tier_active',
      );

    await tester.pumpDeviceBuilder(builder);
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'subscription_screen_family_tier_active');
  });
}
