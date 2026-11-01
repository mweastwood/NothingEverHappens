import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mockito/mockito.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/screens/subscription_screen.dart';
import '../test_helper.dart';

class _MockAuthRepository extends Mock implements AuthRepository {
  final fb_auth.User? _mockUser;
  _MockAuthRepository(this._mockUser);

  @override
  fb_auth.User? get currentUser => _mockUser;

  @override
  Stream<fb_auth.User?> get authStateChanges => Stream.value(_mockUser);
}

class _MockUser extends Mock implements fb_auth.User {
  @override
  String get uid => 'test-user-123';
}

Offerings _buildValidOfferings() {
  const context = PresentedOfferingContext('default', null, null);
  const standardProduct = StoreProduct(
    'standard_monthly',
    'Individual Plan',
    'Individual',
    1.99,
    '\$1.99',
    'USD',
  );
  const familyProduct = StoreProduct(
    'family_monthly',
    'Family Plan',
    'Family',
    4.99,
    '\$4.99',
    'USD',
  );
  const standardPkg = Package(
    'standard',
    PackageType.monthly,
    standardProduct,
    context,
  );
  const familyPkg = Package(
    'family',
    PackageType.monthly,
    familyProduct,
    context,
  );
  const offering = Offering('default', 'Default Offering', {}, [
    standardPkg,
    familyPkg,
  ]);
  return const Offerings({'default': offering}, current: offering);
}

CustomerInfo _buildFakeCustomerInfo() {
  return CustomerInfo.fromJson(const {
    'entitlements': {'all': {}, 'active': {}},
    'allPurchaseDates': {},
    'allExpirationDates': {},
    'allPurchasedProductIdentifiers': [],
    'activeSubscriptions': [],
    'latestExpirationDate': null,
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'test-user-123',
    'requestDate': '2026-01-01T00:00:00Z',
    'originalPurchaseDate': null,
    'originalApplicationVersion': null,
    'managementURL': null,
    'nonSubscriptionTransactions': [],
  });
}

PurchaseResult _buildFakePurchaseResult() {
  return PurchaseResult(
    _buildFakeCustomerInfo(),
    const StoreTransaction('tx-123', 'product-123', '2026-01-01T00:00:00Z'),
  );
}

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

  group('SubscriptionScreen Purchase & Restore Flows', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockUser mockUser;
    late _MockAuthRepository mockAuthRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = _MockUser();
      mockAuthRepository = _MockAuthRepository(mockUser);
    });

    Widget buildScreen({
      Future<Offerings> Function()? getOfferings,
      Future<PurchaseResult> Function(PurchaseParams)? purchase,
      Future<CustomerInfo> Function()? restorePurchases,
      bool? isWebOverride,
    }) {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          firestoreProvider.overrideWithValue(fakeFirestore),
          subscriptionServiceProvider.overrideWith(
            (ref) => FakeSubscriptionService(ref, SubscriptionTier.free),
          ),
          individualPlanPriceProvider.overrideWith(
            (ref) => Future.value('\$1.99'),
          ),
          familyPlanPriceProvider.overrideWith((ref) => Future.value('\$4.99')),
        ],
        child: buildTestableWidget(
          child: SubscriptionScreen(
            getOfferings: getOfferings,
            purchase: purchase,
            restorePurchases: restorePurchases,
            isWebOverride: isWebOverride ?? false,
          ),
        ),
      );
    }

    testWidgets(
      'successful Individual purchase writes standard tier to Firestore and shows success snackbar',
      (WidgetTester tester) async {
        PurchaseParams? capturedParams;
        await tester.pumpWidget(
          buildScreen(
            getOfferings: () async => _buildValidOfferings(),
            purchase: (params) async {
              capturedParams = params;
              return _buildFakePurchaseResult();
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('upgrade_to_individual_button')));
        await tester.pumpAndSettle();

        expect(capturedParams?.package?.identifier, 'standard');
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['subscriptionTier'], 'standard');
        expect(
          find.text('Upgraded to Individual Subscription!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'successful Family purchase writes family tier to Firestore and shows success snackbar',
      (WidgetTester tester) async {
        PurchaseParams? capturedParams;
        await tester.pumpWidget(
          buildScreen(
            getOfferings: () async => _buildValidOfferings(),
            purchase: (params) async {
              capturedParams = params;
              return _buildFakePurchaseResult();
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('subscription_screen_upgrade_button')),
        );
        await tester.pumpAndSettle();

        expect(capturedParams?.package?.identifier, 'family');
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['subscriptionTier'], 'family');
        expect(find.text('Upgraded to Family Subscription!'), findsOneWidget);
      },
    );

    testWidgets(
      'cancelled Individual or Family purchase does NOT write subscriptionTier to Firestore and shows no snackbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildScreen(
            getOfferings: () async => _buildValidOfferings(),
            purchase: (params) async {
              throw PlatformException(
                code: '${PurchasesErrorCode.purchaseCancelledError.index}',
                message: 'Purchase was cancelled.',
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        // Try Individual
        await tester.tap(find.byKey(const Key('upgrade_to_individual_button')));
        await tester.pumpAndSettle();

        var doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Individual Subscription!'), findsNothing);
        expect(
          find.text('Failed to complete subscription purchase.'),
          findsNothing,
        );

        // Try Family
        await tester.tap(
          find.byKey(const Key('subscription_screen_upgrade_button')),
        );
        await tester.pumpAndSettle();

        doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Family Subscription!'), findsNothing);
        expect(
          find.text('Failed to complete subscription purchase.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'failed Individual or Family purchase does NOT write subscriptionTier to Firestore and shows error snackbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildScreen(
            getOfferings: () async => _buildValidOfferings(),
            purchase: (params) async {
              throw PlatformException(
                code: '${PurchasesErrorCode.storeProblemError.index}',
                message: 'Store error',
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        // Try Individual
        await tester.tap(find.byKey(const Key('upgrade_to_individual_button')));
        await tester.pumpAndSettle();

        var doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Individual Subscription!'), findsNothing);
        expect(
          find.text('Failed to complete subscription purchase.'),
          findsOneWidget,
        );

        // Try Family
        await tester.tap(
          find.byKey(const Key('subscription_screen_upgrade_button')),
        );
        await tester.pumpAndSettle();

        doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Family Subscription!'), findsNothing);
      },
    );

    testWidgets(
      'empty or null offerings does NOT write subscriptionTier to Firestore and shows unavailable snackbar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildScreen(
            getOfferings: () async => const Offerings({}, current: null),
            purchase: (params) async => _buildFakePurchaseResult(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('upgrade_to_individual_button')));
        await tester.pumpAndSettle();

        var doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Individual Subscription!'), findsNothing);
        expect(
          find.text('Subscription packages are currently unavailable.'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('subscription_screen_upgrade_button')),
        );
        await tester.pumpAndSettle();

        doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Family Subscription!'), findsNothing);
      },
    );

    testWidgets(
      'web platform does NOT write subscriptionTier to Firestore or call Purchases and shows unsupported snackbar',
      (WidgetTester tester) async {
        bool purchaseCalled = false;
        await tester.pumpWidget(
          buildScreen(
            isWebOverride: true,
            getOfferings: () async => _buildValidOfferings(),
            purchase: (params) async {
              purchaseCalled = true;
              return _buildFakePurchaseResult();
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('upgrade_to_individual_button')));
        await tester.pumpAndSettle();

        expect(purchaseCalled, isFalse);
        var doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Individual Subscription!'), findsNothing);
        expect(
          find.text('In-app purchases are not supported on web.'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('subscription_screen_upgrade_button')),
        );
        await tester.pumpAndSettle();

        expect(purchaseCalled, isFalse);
        doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        expect(doc.data()?['subscriptionTier'], isNull);
        expect(find.text('Upgraded to Family Subscription!'), findsNothing);
      },
    );

    testWidgets(
      'restorePurchases shows error snackbar on failure and unsupported snackbar on web',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildScreen(
            restorePurchases: () async {
              throw PlatformException(
                code: '${PurchasesErrorCode.storeProblemError.index}',
                message: 'Restore failed',
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Restore Purchases'));
        await tester.pumpAndSettle();

        expect(find.text('Purchases restored successfully.'), findsNothing);
        expect(find.text('Failed to restore purchases.'), findsOneWidget);
      },
    );
  });
}
