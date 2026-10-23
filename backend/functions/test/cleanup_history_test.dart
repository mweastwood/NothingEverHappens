import 'package:functions/src/handlers/cleanup_history.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('processHistoryCleanup', () {
    test(
        'queries collectionGroup("instances") for resolved instances older than 90 days and deletes in batches',
        () async {
      final mockDb = MockFirestoreDatabase();
      final ref1 = MockDocumentReference('d1', path: 'users/u1/instances/d1');
      final ref2 =
          MockDocumentReference('d2', path: 'families/f1/instances/d2');
      final mockDocs = [
        MockDocumentSnapshot('d1', {'status': 'completed'}, true, ref1),
        MockDocumentSnapshot('d2', {'status': 'skipped'}, true, ref2),
      ];

      final capturedWhere = <Map<String, dynamic>>[];
      final mockQuery = MockQuery();
      mockQuery.cannedDocs = mockDocs;
      mockQuery.onWhere = (field, op, value) {
        capturedWhere.add({'field': field, 'op': op, 'value': value});
      };

      mockDb.onCollectionGroup = (name) {
        expect(name, equals('instances'));
        return mockQuery;
      };

      final testNow = DateTime.parse('2026-08-31T00:00:00Z');
      final expectedCutoff =
          testNow.subtract(const Duration(days: defaultHistoryRetentionDays));
      final result = await processHistoryCleanup(mockDb, testNow, 500);

      expect(result.success, isTrue);
      expect(result.totalDeleted, equals(2));
      expect(result.batchesProcessed, equals(1));
      expect(result.durationMs, greaterThanOrEqualTo(0));
      expect(mockDb.committedBatches.length, equals(1));
      expect(
          mockDb.committedBatches.first.deletedRefs, containsAll([ref1, ref2]));

      expect(capturedWhere.length, equals(2));
      expect(
        capturedWhere[0],
        equals({
          'field': 'status',
          'op': 'in',
          'value': const ['completed', 'skipped'],
        }),
      );
      expect(
        capturedWhere[1],
        equals({
          'field': 'updatedAt',
          'op': '<=',
          'value': expectedCutoff,
        }),
      );
    });

    test(
        'handles pagination / multi-batch deletion when expired documents exceed single batch limit',
        () async {
      final mockDb = MockFirestoreDatabase();
      final firstBatchDocs = List.generate(
        500,
        (i) => MockDocumentSnapshot(
          'doc_b1_$i',
          {'status': 'completed'},
          true,
          MockDocumentReference('doc_b1_$i',
              path: 'users/u1/instances/doc_b1_$i'),
        ),
      );
      final secondBatchDocs = List.generate(
        250,
        (i) => MockDocumentSnapshot(
          'doc_b2_$i',
          {'status': 'skipped'},
          true,
          MockDocumentReference('doc_b2_$i',
              path: 'users/u2/instances/doc_b2_$i'),
        ),
      );

      var callCount = 0;
      final mockQuery = MockQuery();
      mockQuery.onGet = () async {
        callCount++;
        if (callCount == 1) {
          return MockQuerySnapshot(firstBatchDocs);
        } else if (callCount == 2) {
          return MockQuerySnapshot(secondBatchDocs);
        }
        return MockQuerySnapshot([]);
      };

      mockDb.onCollectionGroup = (name) => mockQuery;

      final testNow = DateTime.now().toUtc();
      final result = await processHistoryCleanup(mockDb, testNow, 500);

      expect(callCount, equals(2));
      expect(result.success, isTrue);
      expect(result.totalDeleted, equals(750));
      expect(result.batchesProcessed, equals(2));
      expect(mockDb.committedBatches.length, equals(2));
    });

    test('never deletes pending instances even if returned by mock query',
        () async {
      final mockDb = MockFirestoreDatabase();
      final pendingRef =
          MockDocumentReference('p1', path: 'users/u1/instances/p1');
      final completedRef =
          MockDocumentReference('c1', path: 'users/u1/instances/c1');

      final mockQuery = MockQuery();
      mockQuery.cannedDocs = [
        MockDocumentSnapshot('p1', {'status': 'pending'}, true, pendingRef),
        MockDocumentSnapshot('c1', {'status': 'completed'}, true, completedRef),
      ];
      mockDb.onCollectionGroup = (name) => mockQuery;

      final testNow = DateTime.parse('2026-08-31T00:00:00Z');
      final result = await processHistoryCleanup(mockDb, testNow, 500);

      expect(result.success, isTrue);
      expect(result.totalDeleted, equals(1));
      expect(mockDb.committedBatches.length, equals(1));
      expect(mockDb.committedBatches.first.deletedRefs, equals([completedRef]));
    });

    test('handles no-op scenario when no documents have expired', () async {
      final mockDb = MockFirestoreDatabase();
      final mockQuery = MockQuery();
      mockQuery.cannedDocs = [];
      mockDb.onCollectionGroup = (name) => mockQuery;

      final testNow = DateTime.now().toUtc();
      final result = await processHistoryCleanup(mockDb, testNow, 500);

      expect(result.success, isTrue);
      expect(result.totalDeleted, equals(0));
      expect(result.batchesProcessed, equals(0));
      expect(mockDb.committedBatches, isEmpty);
    });

    test('respects maxBatches limit to prevent unbounded loops', () async {
      final mockDb = MockFirestoreDatabase();
      final fullBatchDocs = List.generate(
        100,
        (i) => MockDocumentSnapshot(
          'doc_$i',
          {'status': 'completed'},
          true,
          MockDocumentReference('doc_$i', path: 'users/u1/instances/doc_$i'),
        ),
      );

      var callCount = 0;
      final mockQuery = MockQuery();
      mockQuery.onGet = () async {
        callCount++;
        return MockQuerySnapshot(fullBatchDocs);
      };

      mockDb.onCollectionGroup = (name) => mockQuery;

      final testNow = DateTime.now().toUtc();
      final result = await processHistoryCleanup(mockDb, testNow, 100, 3);

      expect(callCount, equals(3));
      expect(result.success, isTrue);
      expect(result.totalDeleted, equals(300));
      expect(result.batchesProcessed, equals(3));
      expect(mockDb.committedBatches.length, equals(3));
    });

    test('handles and logs error when batch commit fails', () async {
      final mockDb = MockFirestoreDatabase();
      final mockDocs = [
        MockDocumentSnapshot(
          'd1',
          {'status': 'completed'},
          true,
          MockDocumentReference('d1', path: 'users/u1/instances/d1'),
        ),
      ];

      final mockQuery = MockQuery();
      mockQuery.cannedDocs = mockDocs;
      mockDb.onCollectionGroup = (name) => mockQuery;

      // Make batch commit fail
      final batch = MockWriteBatch(onCommitAsync: () async {
        throw Exception(
            'Firestore batch commit failed due to connection error');
      });
      mockDb.onBatch = () => batch;

      final testNow = DateTime.now().toUtc();
      expect(
        () async => await processHistoryCleanup(mockDb, testNow, 500),
        throwsA(isA<Exception>()),
      );
    });
  });
}
