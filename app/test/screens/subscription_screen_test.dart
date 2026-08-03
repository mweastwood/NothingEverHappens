import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
