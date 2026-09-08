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
    return collections.putIfAbsent(path, () => MockCollectionReference(path));
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
  final Map<String, MockDocumentReference> documents = {};

  MockCollectionReference(this.path);

  @override
  MockDocumentReference doc([String? id]) {
    final docId = id ?? 'mock_doc_${documents.length + 1}';
    return documents.putIfAbsent(
      docId,
      () => MockDocumentReference(docId, path: '$path/$docId'),
    );
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
    return MockQuerySnapshot(cannedDocs);
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
  Map<String, dynamic>? docData;
  bool isExisting = true;

  final Map<String, MockCollectionReference> subcollections = {};
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Map<String, dynamic>> setCalls = [];
  int deleteCalls = 0;

  MockDocumentReference(this.id,
      {this.path = '', this.docData, this.isExisting = true});

  @override
  MockCollectionReference collection(String path) {
    return subcollections.putIfAbsent(
        path, () => MockCollectionReference('${this.path}/$path'));
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
  final List<DocumentReference> deletedRefs = [];
  final void Function()? onCommit;
  Future<void> Function()? onCommitAsync;
  int commitCount = 0;

  MockWriteBatch({this.onCommit, this.onCommitAsync});

  @override
  void delete(DocumentReference ref) {
    deletedRefs.add(ref);
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
