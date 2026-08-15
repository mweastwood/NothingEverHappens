// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/firestore_extensions.dart';

class DelayedDocRef<T> extends Fake implements DocumentReference<T> {
  final Duration delay;
  final DocumentSnapshot<T>? result;
  final Object? error;
  GetOptions? capturedOptions;

  DelayedDocRef({
    this.delay = const Duration(milliseconds: 50),
    this.result,
    this.error,
  });

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    capturedOptions = options;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (error != null) {
      throw error!;
    }
    return result!;
  }
}

class DelayedQuery<T> extends Fake implements Query<T> {
  final Duration delay;
  final QuerySnapshot<T>? result;
  final Object? error;
  GetOptions? capturedOptions;

  DelayedQuery({
    this.delay = const Duration(milliseconds: 50),
    this.result,
    this.error,
  });

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    capturedOptions = options;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (error != null) {
      throw error!;
    }
    return result!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('FirestoreDocFetchExtension (safeGet on DocumentReference)', () {
    test(
      'resolves DocumentSnapshot successfully for existing document',
      () async {
        final docRef = fakeFirestore.collection('users').doc('user1');
        await docRef.set({'name': 'Alice', 'role': 'admin'});

        final snapshot = await docRef.safeGet();

        expect(snapshot.exists, isTrue);
        expect(snapshot.data(), {'name': 'Alice', 'role': 'admin'});
      },
    );

    test('resolves DocumentSnapshot for non-existent document', () async {
      final docRef = fakeFirestore.collection('users').doc('nonexistent');

      final snapshot = await docRef.safeGet();

      expect(snapshot.exists, isFalse);
      expect(snapshot.data(), isNull);
    });

    test('passes options parameter through to get()', () async {
      final docRef = fakeFirestore.collection('users').doc('user1');
      await docRef.set({'name': 'Alice'});
      final realSnap = await docRef.get();

      final fakeDocRef = DelayedDocRef<Map<String, dynamic>>(
        delay: Duration.zero,
        result: realSnap,
      );

      const options = GetOptions(source: Source.server);
      final snap = await fakeDocRef.safeGet(options: options);

      expect(snap.exists, isTrue);
      expect(fakeDocRef.capturedOptions?.source, Source.server);
    });

    test('throws TimeoutException when operation exceeds timeout', () async {
      final fakeDocRef = DelayedDocRef<Map<String, dynamic>>(
        delay: const Duration(milliseconds: 200),
      );

      expect(
        () => fakeDocRef.safeGet(timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('propagates error when underlying get throws', () async {
      final fakeDocRef = DelayedDocRef<Map<String, dynamic>>(
        delay: Duration.zero,
        error: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      expect(
        () => fakeDocRef.safeGet(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });

  group('FirestoreQueryFetchExtension (safeGet on Query)', () {
    test('resolves QuerySnapshot successfully with items', () async {
      final collection = fakeFirestore.collection('tasks');
      await collection.doc('task1').set({'title': 'Task 1', 'done': false});
      await collection.doc('task2').set({'title': 'Task 2', 'done': true});

      final query = collection.where('done', isEqualTo: false);
      final snapshot = await query.safeGet();

      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.id, 'task1');
      expect(snapshot.docs.first.data()['title'], 'Task 1');
    });

    test('resolves empty QuerySnapshot when no matches', () async {
      final collection = fakeFirestore.collection('tasks');
      await collection.doc('task1').set({'title': 'Task 1', 'done': true});

      final query = collection.where('done', isEqualTo: false);
      final snapshot = await query.safeGet();

      expect(snapshot.docs.isEmpty, isTrue);
    });

    test('passes options parameter through to get()', () async {
      final collection = fakeFirestore.collection('tasks');
      await collection.doc('task1').set({'title': 'Task 1'});
      final realQuerySnap = await collection.get();

      final fakeQuery = DelayedQuery<Map<String, dynamic>>(
        delay: Duration.zero,
        result: realQuerySnap,
      );

      const options = GetOptions(source: Source.cache);
      final snap = await fakeQuery.safeGet(options: options);

      expect(snap.docs.length, 1);
      expect(fakeQuery.capturedOptions?.source, Source.cache);
    });

    test(
      'throws TimeoutException when query operation exceeds timeout',
      () async {
        final fakeQuery = DelayedQuery<Map<String, dynamic>>(
          delay: const Duration(milliseconds: 200),
        );

        expect(
          () => fakeQuery.safeGet(timeout: const Duration(milliseconds: 20)),
          throwsA(isA<TimeoutException>()),
        );
      },
    );

    test('propagates error when underlying query throws', () async {
      final fakeQuery = DelayedQuery<Map<String, dynamic>>(
        delay: Duration.zero,
        error: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'The service is currently unavailable.',
        ),
      );

      expect(
        () => fakeQuery.safeGet(),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
    });
  });
}
