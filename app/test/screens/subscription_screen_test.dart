import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nothing_ever_happens/screens/subscription_screen.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import '../test_helper.dart';

void main() {
  testWidgets('SubscriptionScreen renders current tier and available plans', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyPlanPriceProvider.overrideWith((ref) => Future.value('\$1.00')),
        ],
        child: buildTestableWidget(child: const SubscriptionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Current Tier'), findsOneWidget);
    expect(find.text('Free Tier'), findsWidgets);
    expect(find.text('Family Plan'), findsWidgets);
    expect(
      find.byKey(const Key('subscription_screen_upgrade_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'SubscriptionScreen renders explicit \$X.XX/mo fallback when price is null',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyPlanPriceProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$X.XX/mo'), findsWidgets);
      expect(find.text('Upgrade to Family Plan (\$X.XX/mo)'), findsOneWidget);
    },
  );

  testWidgets(
    'SubscriptionScreen renders active status when user is on Family Plan',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => FakeSubscriptionService(ref, SubscriptionTier.family),
            ),
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$1.00'),
            ),
          ],
          child: buildTestableWidget(child: const SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(
        find.byKey(const Key('subscription_screen_upgrade_button')),
        findsNothing,
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
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value('\$1.00'),
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
