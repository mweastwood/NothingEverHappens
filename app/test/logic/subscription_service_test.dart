import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class MockAuthRepository extends Mock implements AuthRepository {
  final fb_auth.User? _mockUser;
  MockAuthRepository(this._mockUser);

  @override
  fb_auth.User? get currentUser => _mockUser;

  @override
  Stream<fb_auth.User?> get authStateChanges => Stream.value(_mockUser);
}

class MockUser extends Mock implements fb_auth.User {
  @override
  String get uid => 'test-user-123';
}

class TestSubscriptionService extends SubscriptionService {
  TestSubscriptionService(super.ref, {required super.firestore});

  void triggerListenToFirestore(String uid) {
    listenToUserSubscriptionInFirestore(uid);
  }
}

void main() {
  group('SubscriptionService Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockUser = MockUser();
      mockAuthRepository = MockAuthRepository(mockUser);
    });

    test('starts with free tier by default', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          firestoreProvider.overrideWithValue(fakeFirestore),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(subscriptionServiceProvider);
      expect(state.tier, SubscriptionTier.free);
      expect(state.isActivePremium, isFalse);
      expect(state.isFamilyPlan, isFalse);
    });

    test('updates subscription tier when Firestore document changes', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          firestoreProvider.overrideWithValue(fakeFirestore),
        ],
      );
      addTearDown(container.dispose);

      late Ref ref;
      container.read(
        Provider((r) {
          ref = r;
          return null;
        }),
      );

      final service = TestSubscriptionService(ref, firestore: fakeFirestore);

      // Initially free
      expect(service.state.tier, SubscriptionTier.free);

      // Start listening to the mock user doc
      service.triggerListenToFirestore('test-user-123');
      await Future.delayed(Duration.zero);

      // Write 'family' tier to user doc
      await fakeFirestore.collection('users').doc('test-user-123').set({
        'subscriptionTier': 'family',
      });
      await Future.delayed(Duration.zero);
      expect(service.state.tier, SubscriptionTier.family);
      expect(service.state.isActivePremium, isTrue);
      expect(service.state.isFamilyPlan, isTrue);

      // Write 'standard' tier to user doc
      await fakeFirestore.collection('users').doc('test-user-123').set({
        'subscriptionTier': 'standard',
      });
      await Future.delayed(Duration.zero);
      expect(service.state.tier, SubscriptionTier.standard);
      expect(service.state.isActivePremium, isTrue);
      expect(service.state.isFamilyPlan, isFalse);

      // Delete the document - should fallback to free
      await fakeFirestore.collection('users').doc('test-user-123').delete();
      await Future.delayed(Duration.zero);
      expect(service.state.tier, SubscriptionTier.free);
    });

    test(
      'updates subscription tier to family when user document has familyId set',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
        );
        addTearDown(container.dispose);

        late Ref ref;
        container.read(
          Provider((r) {
            ref = r;
            return null;
          }),
        );

        final service = TestSubscriptionService(ref, firestore: fakeFirestore);

        service.triggerListenToFirestore('test-user-123');
        await Future.delayed(Duration.zero);

        await fakeFirestore.collection('users').doc('test-user-123').set({
          'familyId': 'fam-abc-123',
          'familyRole': 'non-parent',
        });
        await Future.delayed(Duration.zero);
        expect(service.state.tier, SubscriptionTier.family);
        expect(service.state.isFamilyPlan, isTrue);
      },
    );

    test(
      'individualPlanPriceProvider and familyPlanPriceProvider can be read and overridden',
      () async {
        final container = ProviderContainer(
          overrides: [
            individualPlanPriceProvider.overrideWith(
              (ref) => Future.value(r'$1.99'),
            ),
            familyPlanPriceProvider.overrideWith(
              (ref) => Future.value(r'$4.99'),
            ),
          ],
        );
        addTearDown(container.dispose);

        final indPrice = await container.read(
          individualPlanPriceProvider.future,
        );
        final famPrice = await container.read(familyPlanPriceProvider.future);

        expect(indPrice, r'$1.99');
        expect(famPrice, r'$4.99');
      },
    );
  });
}
