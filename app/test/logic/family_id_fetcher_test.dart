// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/family_id_fetcher.dart';

void main() {
  group('FamilyIdFetcher Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      AppClock.reset();
    });

    tearDown(() {
      AppClock.reset();
    });

    test('returns null when firestore is null', () async {
      final fetcher = FamilyIdFetcher(firestore: null, userId: 'user1');
      final result = await fetcher.getFamilyId();
      expect(result, isNull);
    });

    test('returns null when userId is empty', () async {
      final fetcher = FamilyIdFetcher(firestore: fakeFirestore, userId: '');
      final result = await fetcher.getFamilyId();
      expect(result, isNull);
    });

    test('fetches familyId from Firestore and caches it', () async {
      await fakeFirestore.collection('users').doc('user1').set({
        'familyId': 'family_123',
      });

      final fetcher = FamilyIdFetcher(
        firestore: fakeFirestore,
        userId: 'user1',
      );
      expect(fetcher.cachedFamilyId, isNull);

      final familyId = await fetcher.getFamilyId();
      expect(familyId, 'family_123');
      expect(fetcher.cachedFamilyId, 'family_123');
      expect(fetcher.lastFamilyIdCheck, isNotNull);
    });

    test('uses cached familyId on subsequent calls within duration', () async {
      await fakeFirestore.collection('users').doc('user1').set({
        'familyId': 'family_123',
      });

      final fetcher = FamilyIdFetcher(
        firestore: fakeFirestore,
        userId: 'user1',
      );
      final firstFetch = await fetcher.getFamilyId();
      expect(firstFetch, 'family_123');

      // Update Firestore document directly
      await fakeFirestore.collection('users').doc('user1').set({
        'familyId': 'family_456',
      });

      // Immediate call returns cached value
      final secondFetch = await fetcher.getFamilyId();
      expect(secondFetch, 'family_123');
    });

    test(
      'caches null familyId for non-family users within cache duration',
      () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'name': 'User Without Family',
        });

        final fetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user1',
        );
        final firstFetch = await fetcher.getFamilyId();
        expect(firstFetch, isNull);
        expect(fetcher.lastFamilyIdCheck, isNotNull);

        // Update Firestore document to add familyId
        await fakeFirestore.collection('users').doc('user1').set({
          'name': 'User Without Family',
          'familyId': 'family_new',
        });

        // Call within cache window (5 seconds later) returns cached null
        AppClock.advanceTime(const Duration(seconds: 5));
        final secondFetch = await fetcher.getFamilyId();
        expect(secondFetch, isNull);
      },
    );

    test(
      'expires cached familyId (including null) after 15s using AppClock.advanceTime()',
      () async {
        // Test non-family user cache expiration
        await fakeFirestore.collection('users').doc('user1').set({
          'name': 'Non Family User',
        });

        final fetcher1 = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user1',
        );
        final fetch1 = await fetcher1.getFamilyId();
        expect(fetch1, isNull);

        await fakeFirestore.collection('users').doc('user1').set({
          'familyId': 'family_joined',
        });

        // Advance time beyond cache duration (16 seconds)
        AppClock.advanceTime(const Duration(seconds: 16));
        final fetch1AfterExpiry = await fetcher1.getFamilyId();
        expect(fetch1AfterExpiry, 'family_joined');

        // Test family user cache expiration
        await fakeFirestore.collection('users').doc('user2').set({
          'familyId': 'family_123',
        });

        final fetcher2 = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user2',
        );
        final fetch2 = await fetcher2.getFamilyId();
        expect(fetch2, 'family_123');

        await fakeFirestore.collection('users').doc('user2').set({
          'familyId': 'family_456',
        });

        // Advance time beyond cache duration (16 seconds)
        AppClock.advanceTime(const Duration(seconds: 16));
        final fetch2AfterExpiry = await fetcher2.getFamilyId();
        expect(fetch2AfterExpiry, 'family_456');
      },
    );

    test('clearCache resets cached familyId and timestamp', () async {
      await fakeFirestore.collection('users').doc('user1').set({
        'familyId': 'family_123',
      });

      final fetcher = FamilyIdFetcher(
        firestore: fakeFirestore,
        userId: 'user1',
      );
      await fetcher.getFamilyId();
      expect(fetcher.cachedFamilyId, 'family_123');

      fetcher.clearCache();
      expect(fetcher.cachedFamilyId, isNull);
      expect(fetcher.lastFamilyIdCheck, isNull);
    });

    test(
      'falls back to offline cache and reports error when network call throws',
      () async {
        final failingFirestore = _FailingNetworkFirestore();
        await failingFirestore.collection('users').doc('user1').set({
          'familyId': 'offline_family_123',
        });

        final errorHandler = ErrorHandler();
        final fetcher = FamilyIdFetcher(
          firestore: failingFirestore,
          userId: 'user1',
          errorHandler: errorHandler,
        );

        final familyId = await fetcher.getFamilyId();
        expect(familyId, 'offline_family_123');
        expect(errorHandler.history.length, 1);
        expect(
          errorHandler.history.first.error.toString(),
          contains('Network request failed'),
        );
      },
    );

    test(
      'reports errors and returns cached value when both network and cache calls throw',
      () async {
        final failingFirestore = _FailingNetworkFirestore(cacheFails: true);
        final errorHandler = ErrorHandler();
        final fetcher = FamilyIdFetcher(
          firestore: failingFirestore,
          userId: 'user1',
          errorHandler: errorHandler,
        );

        final familyId = await fetcher.getFamilyId();
        expect(familyId, isNull);
        expect(errorHandler.history.length, 2);
        expect(
          errorHandler.history[0].error.toString(),
          contains('Network request failed'),
        );
        expect(
          errorHandler.history[1].error.toString(),
          contains('Cache fetch failed'),
        );
      },
    );

    test(
      'isFamilyParent returns true for parent and false for non-parent',
      () async {
        await fakeFirestore.collection('users').doc('parent_user').set({
          'familyId': 'fam_123',
          'familyRole': 'parent',
        });
        await fakeFirestore.collection('users').doc('non_parent_user').set({
          'familyId': 'fam_123',
          'familyRole': 'non-parent',
        });

        final parentFetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'parent_user',
        );
        final nonParentFetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'non_parent_user',
        );

        expect(await parentFetcher.isFamilyParent(), isTrue);
        expect(parentFetcher.cachedFamilyRole, 'parent');

        expect(await nonParentFetcher.isFamilyParent(), isFalse);
        expect(nonParentFetcher.cachedFamilyRole, 'non-parent');
      },
    );

    test(
      'isFamilyParent resolves from family members when userDoc lacks role',
      () async {
        await fakeFirestore.collection('users').doc('user_without_role').set({
          'familyId': 'fam_doc_check',
        });
        await fakeFirestore.collection('families').doc('fam_doc_check').set({
          'name': 'Test Family',
          'members': {
            'user_without_role': {
              'userId': 'user_without_role',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
            'other_member': {
              'userId': 'other_member',
              'displayName': 'Kid User',
              'email': 'kid@example.com',
              'role': 'non-parent',
            },
          },
        });

        final fetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user_without_role',
        );

        expect(await fetcher.isFamilyParent(), isTrue);
        expect(await fetcher.isFamilyParent('other_member'), isFalse);
      },
    );

    test(
      'isFamilyParent reflects role changes after TTL expiration using AppClock.advanceTime()',
      () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'familyId': 'fam_123',
          'familyRole': 'parent',
        });

        final fetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user1',
        );

        expect(await fetcher.isFamilyParent(), isTrue);
        expect(fetcher.cachedFamilyRole, 'parent');

        // Update user doc in Firestore to non-parent
        await fakeFirestore.collection('users').doc('user1').set({
          'familyId': 'fam_123',
          'familyRole': 'non-parent',
        });

        // Within cache duration, isFamilyParent returns cached parent
        AppClock.advanceTime(const Duration(seconds: 5));
        expect(await fetcher.isFamilyParent(), isTrue);

        // Advance time beyond cache duration (16s)
        AppClock.advanceTime(const Duration(seconds: 11));
        expect(await fetcher.isFamilyParent(), isFalse);
        expect(fetcher.cachedFamilyRole, 'non-parent');
      },
    );

    test(
      'isFamilyParent reflects role changes immediately after clearCache()',
      () async {
        await fakeFirestore.collection('users').doc('user1').set({
          'familyId': 'fam_123',
          'familyRole': 'non-parent',
        });

        final fetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user1',
        );

        expect(await fetcher.isFamilyParent(), isFalse);
        expect(fetcher.cachedFamilyRole, 'non-parent');

        // Update user doc in Firestore to parent
        await fakeFirestore.collection('users').doc('user1').set({
          'familyId': 'fam_123',
          'familyRole': 'parent',
        });

        // Clear cache invalidates cached role immediately
        fetcher.clearCache();
        expect(fetcher.cachedFamilyRole, isNull);

        expect(await fetcher.isFamilyParent(), isTrue);
        expect(fetcher.cachedFamilyRole, 'parent');
      },
    );

    test(
      'isFamilyParent caches role from family members and updates when refreshed',
      () async {
        await fakeFirestore.collection('users').doc('user_without_role').set({
          'familyId': 'fam_doc_check',
        });
        await fakeFirestore.collection('families').doc('fam_doc_check').set({
          'name': 'Test Family',
          'members': {
            'user_without_role': {
              'userId': 'user_without_role',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'parent',
            },
          },
        });

        final fetcher = FamilyIdFetcher(
          firestore: fakeFirestore,
          userId: 'user_without_role',
        );

        expect(await fetcher.isFamilyParent(), isTrue);
        expect(fetcher.cachedFamilyRole, 'parent');

        // Update family document
        await fakeFirestore.collection('families').doc('fam_doc_check').set({
          'name': 'Test Family',
          'members': {
            'user_without_role': {
              'userId': 'user_without_role',
              'displayName': 'Parent User',
              'email': 'parent@example.com',
              'role': 'non-parent',
            },
          },
        });

        // Clear cache and verify updated
        fetcher.clearCache();
        expect(await fetcher.isFamilyParent(), isFalse);
        expect(fetcher.cachedFamilyRole, 'non-parent');
      },
    );
  });
}

class _FailingNetworkFirestore extends FakeFirebaseFirestore {
  final bool cacheFails;

  _FailingNetworkFirestore({this.cacheFails = false});

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FailingNetworkCollectionReference(
      super.collection(collectionPath),
      cacheFails: cacheFails,
    );
  }
}

class _FailingNetworkCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final CollectionReference<Map<String, dynamic>> _delegate;
  final bool cacheFails;

  _FailingNetworkCollectionReference(
    this._delegate, {
    required this.cacheFails,
  });

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FailingNetworkDocumentReference(
      _delegate.doc(path),
      cacheFails: cacheFails,
    );
  }
}

class _FailingNetworkDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final DocumentReference<Map<String, dynamic>> _delegate;
  final bool cacheFails;

  _FailingNetworkDocumentReference(this._delegate, {required this.cacheFails});

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    return _delegate.set(data, options);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (options?.source == Source.cache) {
      if (cacheFails) {
        throw Exception('Cache fetch failed');
      }
      return _delegate.get();
    }
    throw Exception('Network request failed');
  }
}
