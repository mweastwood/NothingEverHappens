import 'dart:async';
import 'package:functions/src/interop/firebase_admin.dart';

class MockAuthService implements AuthService {
  Future<DecodedIdToken> Function(String idToken)? onVerifyIdToken;
  Future<void> Function(String uid)? onDeleteUser;

  final List<String> verifiedTokens = [];
  final List<String> deletedUserIds = [];

  @override
  Future<DecodedIdToken> verifyIdToken(String idToken) async {
    verifiedTokens.add(idToken);
    if (onVerifyIdToken != null) {
      return onVerifyIdToken!(idToken);
    }
    return DecodedIdToken(uid: idToken);
  }

  @override
  Future<void> deleteUser(String uid) async {
    deletedUserIds.add(uid);
    if (onDeleteUser != null) {
      await onDeleteUser!(uid);
    }
  }
}

class MockFirestoreDatabase implements FirestoreDatabase {
  final Map<String, MockCollectionReference> collections = {};
  final List<DocumentReference> recursiveDeletedRefs = [];
  MockQuery Function(String collectionId)? onCollectionGroup;
  WriteBatch Function()? onBatch;

  @override
  MockCollectionReference collection(String path) {
    final cleanPath = path.replaceAll(RegExp(r'^/+|/+$'), '');
    return collections.putIfAbsent(
        cleanPath, () => MockCollectionReference(cleanPath, this));
  }

  @override
  Query collectionGroup(String collectionId) {
    if (onCollectionGroup != null) {
      return onCollectionGroup!(collectionId);
    }
    return MockQuery();
  }

  MockWriteBatch currentBatch = MockWriteBatch();
  final List<MockWriteBatch> committedBatches = [];

  @override
  WriteBatch batch() {
    if (onBatch != null) {
      final b = onBatch!();
      if (b is MockWriteBatch) committedBatches.add(b);
      return b;
    }
    currentBatch = MockWriteBatch(onCommit: () {
      committedBatches.add(currentBatch);
    });
    return currentBatch;
  }

  @override
  Future<void> recursiveDelete(DocumentReference ref) async {
    recursiveDeletedRefs.add(ref);
  }
}

class MockCollectionReference extends MockQuery implements CollectionReference {
  final String path;
  final MockFirestoreDatabase? db;
  final Map<String, MockDocumentReference> documents = {};

  MockCollectionReference(this.path, [this.db]);

  @override
  MockDocumentReference doc([String? id]) {
    final docId = id ?? 'mock_doc_${documents.length + 1}';
    return documents.putIfAbsent(
      docId,
      () => MockDocumentReference(docId, path: '$path/$docId', db: db),
    );
  }

  @override
  MockQuery limit(int count) {
    final q = MockQuery();
    q.whereConditions.addAll(whereConditions);
    q.limitCount = count;
    q.onGet = onGet ??
        () async {
          final allDocsSnap = await get();
          return MockQuerySnapshot(allDocsSnap.docs.take(count).toList());
        };
    q.cannedDocs = cannedDocs;
    return q;
  }

  @override
  Future<QuerySnapshot> get() async {
    if (onGet != null) {
      return onGet!();
    }
    if (cannedDocs.isNotEmpty) {
      return MockQuerySnapshot(cannedDocs);
    }
    var docs = documents.values
        .where((d) => d.isExisting && d.docData != null)
        .map((d) => MockDocumentSnapshot(d.id, d.docData, true, d))
        .toList();
    if (limitCount != null && limitCount! >= 0 && docs.length > limitCount!) {
      docs = docs.take(limitCount!).toList();
    }
    return MockQuerySnapshot(docs);
  }
}

class MockQuery implements Query {
  final List<Map<String, dynamic>> whereConditions = [];
  int? limitCount;
  Future<QuerySnapshot> Function()? onGet;
  List<MockDocumentSnapshot> cannedDocs = [];

  @override
  MockQuery where(String field, String op, dynamic value) {
    final q = MockQuery();
    q.whereConditions.addAll(whereConditions);
    q.whereConditions.add({'field': field, 'op': op, 'value': value});
    q.limitCount = limitCount;
    q.onGet = onGet;
    q.cannedDocs = cannedDocs;
    return q;
  }

  @override
  MockQuery limit(int count) {
    final q = MockQuery();
    q.whereConditions.addAll(whereConditions);
    q.limitCount = count;
    q.onGet = onGet;
    q.cannedDocs = cannedDocs;
    return q;
  }

  @override
  Future<QuerySnapshot> get() async {
    if (onGet != null) {
      return onGet!();
    }
    var docs = cannedDocs;
    if (limitCount != null && limitCount! >= 0 && docs.length > limitCount!) {
      docs = docs.take(limitCount!).toList();
    }
    return MockQuerySnapshot(docs);
  }
}

class MockQuerySnapshot implements QuerySnapshot {
  @override
  final List<DocumentSnapshot> docs;

  MockQuerySnapshot(this.docs);

  @override
  bool get empty => docs.isEmpty;

  @override
  int get size => docs.length;
}

class MockDocumentReference implements DocumentReference {
  @override
  final String id;
  final String path;
  final MockFirestoreDatabase? db;
  Map<String, dynamic>? docData;
  bool isExisting = true;

  final Map<String, MockCollectionReference> subcollections = {};
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Map<String, dynamic>> setCalls = [];
  int deleteCalls = 0;

  MockDocumentReference(this.id,
      {this.path = '', this.db, this.docData, this.isExisting = true});

  @override
  MockCollectionReference collection(String subPath) {
    if (db != null) {
      final fullPath = path.isEmpty ? subPath : '$path/$subPath';
      return db!.collection(fullPath);
    }
    return subcollections.putIfAbsent(
        subPath, () => MockCollectionReference('${this.path}/$subPath'));
  }

  @override
  Future<DocumentSnapshot> get() async {
    return MockDocumentSnapshot(id, docData, isExisting, this);
  }

  @override
  Future<void> set(Map<String, dynamic> data) async {
    setCalls.add(data);
    docData = Map<String, dynamic>.from(data);
    isExisting = true;
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    updateCalls.add(data);
    docData ??= {};
    for (final entry in data.entries) {
      if (entry.value == FieldValue.deleteToken) {
        docData!.remove(entry.key);
      } else {
        docData![entry.key] = entry.value;
      }
    }
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    isExisting = false;
    docData = null;
  }
}

class MockDocumentSnapshot implements DocumentSnapshot {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  final bool _exists;
  @override
  final DocumentReference ref;

  MockDocumentSnapshot(this.id, this._data, this._exists, this.ref);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;
}

class MockWriteBatch implements WriteBatch {
  final Map<DocumentReference, Map<String, dynamic>> setOperations = {};
  final Map<DocumentReference, Map<String, dynamic>> updateOperations = {};
  final List<DocumentReference> deletedRefs = [];
  final void Function()? onCommit;
  Future<void> Function()? onCommitAsync;
  int commitCount = 0;

  MockWriteBatch({this.onCommit, this.onCommitAsync});

  @override
  void set(DocumentReference ref, Map<String, dynamic> data) {
    setOperations[ref] = Map<String, dynamic>.from(data);
    if (ref is MockDocumentReference) {
      ref.set(data);
    }
  }

  @override
  void update(DocumentReference ref, Map<String, dynamic> data) {
    updateOperations[ref] = Map<String, dynamic>.from(data);
    if (ref is MockDocumentReference) {
      ref.update(data);
    }
  }

  @override
  void delete(DocumentReference ref) {
    deletedRefs.add(ref);
    if (ref is MockDocumentReference) {
      ref.delete();
    }
  }

  @override
  Future<void> commit() async {
    commitCount++;
    if (onCommitAsync != null) {
      await onCommitAsync!();
    }
    onCommit?.call();
  }
}
