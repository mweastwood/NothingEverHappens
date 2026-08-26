import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/family_id_fetcher.dart';

void main() {
  group('FamilyIdFetcher Unit Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
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
  });
}
