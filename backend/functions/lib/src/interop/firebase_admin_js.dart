export 'abstract_admin.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'abstract_admin.dart';

js.JsObject? _adminInstance;
js.JsObject? _dbInstance;
js.JsObject? _authInstance;

js.JsObject get _admin {
  if (_adminInstance == null) {
    final require = js.context['require'];
    if (require == null) {
      throw StateError(
          "Node 'require' is not available in current environment");
    }
    _adminInstance =
        js.context.callMethod('require', ['firebase-admin']) as js.JsObject;
  }
  return _adminInstance!;
}

void initializeFirebaseAdmin() {
  final apps = _admin['apps'] as List?;
  if (apps == null || apps.isEmpty) {
    _admin.callMethod('initializeApp');
  }
}

FirestoreDatabase getFirebaseAdminDb([dynamic jsDb]) {
  initializeFirebaseAdmin();
  if (jsDb != null) {
    return JsFirestoreDatabase(jsDb as js.JsObject, _admin);
  }
  _dbInstance ??= _admin.callMethod('firestore') as js.JsObject;
  return JsFirestoreDatabase(_dbInstance!, _admin);
}

AuthService getFirebaseAdminAuth() {
  initializeFirebaseAdmin();
  _authInstance ??= _admin.callMethod('auth') as js.JsObject;
  return JsAuthService(_authInstance!);
}

class JsFirestoreDatabase implements FirestoreDatabase {
  final js.JsObject _db;
  final js.JsObject _adminRef;

  JsFirestoreDatabase(this._db, this._adminRef);

  @override
  CollectionReference collection(String path) {
    final col = _db.callMethod('collection', [path]) as js.JsObject;
    return JsCollectionReference(col, _adminRef);
  }

  @override
  Query collectionGroup(String collectionId) {
    final q = _db.callMethod('collectionGroup', [collectionId]) as js.JsObject;
    return JsQuery(q, _adminRef);
  }

  @override
  WriteBatch batch() {
    final b = _db.callMethod('batch') as js.JsObject;
    return JsWriteBatch(b, _adminRef);
  }

  @override
  Future<void> recursiveDelete(DocumentReference ref) async {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    if (js_util.hasProperty(_db, 'recursiveDelete')) {
      final promise = _db.callMethod('recursiveDelete', [jsRef]);
      await js_util.promiseToFuture(promise);
    } else {
      await ref.delete();
    }
  }
}

class JsCollectionReference extends JsQuery implements CollectionReference {
  JsCollectionReference(super.rawQuery, super.adminRef);

  @override
  DocumentReference doc([String? id]) {
    final docRef = (id != null
        ? rawQuery.callMethod('doc', [id])
        : rawQuery.callMethod('doc')) as js.JsObject;
    return JsDocumentReference(docRef, adminRef);
  }
}

class JsQuery implements Query {
  final js.JsObject rawQuery;
  final js.JsObject adminRef;

  JsQuery(this.rawQuery, this.adminRef);

  @override
  Query where(String field, String op, dynamic value) {
    dynamic jsVal = value;
    if (value is DateTime) {
      final firestoreClass = adminRef['firestore'] as js.JsObject;
      final timestampClass = firestoreClass['Timestamp'] as js.JsObject;
      final dateObj =
          js.JsObject(js.context['Date'], [value.toUtc().toIso8601String()]);
      jsVal = timestampClass.callMethod('fromDate', [dateObj]);
    }
    final nextQ =
        rawQuery.callMethod('where', [field, op, jsVal]) as js.JsObject;
    return JsQuery(nextQ, adminRef);
  }

  @override
  Query limit(int count) {
    final nextQ = rawQuery.callMethod('limit', [count]) as js.JsObject;
    return JsQuery(nextQ, adminRef);
  }

  @override
  Future<QuerySnapshot> get() async {
    final promise = rawQuery.callMethod('get');
    final snap = await js_util.promiseToFuture(promise) as js.JsObject;
    return JsQuerySnapshot(snap, adminRef);
  }
}

class JsQuerySnapshot implements QuerySnapshot {
  final js.JsObject _snap;
  final js.JsObject _adminRef;

  JsQuerySnapshot(this._snap, this._adminRef);

  @override
  bool get empty => (_snap['empty'] as bool?) ?? true;

  @override
  int get size => (_snap['size'] as num?)?.toInt() ?? 0;

  @override
  List<DocumentSnapshot> get docs {
    final docsList = _snap['docs'] as List?;
    if (docsList == null) return [];
    return docsList
        .map((d) => JsDocumentSnapshot(d as js.JsObject, _adminRef))
        .toList();
  }
}

class JsDocumentReference implements DocumentReference {
  final js.JsObject rawJsRef;
  final js.JsObject adminRef;

  JsDocumentReference(this.rawJsRef, this.adminRef);

  @override
  String get id => (rawJsRef['id'] as String?) ?? '';

  @override
  CollectionReference collection(String path) {
    final col = rawJsRef.callMethod('collection', [path]) as js.JsObject;
    return JsCollectionReference(col, adminRef);
  }

  @override
  Future<DocumentSnapshot> get() async {
    final promise = rawJsRef.callMethod('get');
    final snap = await js_util.promiseToFuture(promise) as js.JsObject;
    return JsDocumentSnapshot(snap, adminRef);
  }

  @override
  Future<void> set(Map<String, dynamic> data) async {
    final converted = _convertMapForJs(data, adminRef);
    final promise = rawJsRef.callMethod('set', [converted]);
    await js_util.promiseToFuture(promise);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    final converted = _convertMapForJs(data, adminRef);
    final promise = rawJsRef.callMethod('update', [converted]);
    await js_util.promiseToFuture(promise);
  }

  @override
  Future<void> delete() async {
    final promise = rawJsRef.callMethod('delete');
    await js_util.promiseToFuture(promise);
  }
}

class JsDocumentSnapshot implements DocumentSnapshot {
  final js.JsObject _snap;
  final js.JsObject _adminRef;

  JsDocumentSnapshot(this._snap, this._adminRef);

  @override
  String get id => (_snap['id'] as String?) ?? '';

  @override
  bool get exists => (_snap['exists'] as bool?) ?? false;

  @override
  DocumentReference get ref =>
      JsDocumentReference(_snap['ref'] as js.JsObject, _adminRef);

  @override
  Map<String, dynamic>? data() {
    final rawData = _snap.callMethod('data');
    if (rawData == null) return null;
    final jsonStr =
        js.context['JSON'].callMethod('stringify', [rawData]) as String?;
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>?;
  }
}

class JsWriteBatch implements WriteBatch {
  final js.JsObject _batch;
  final js.JsObject _adminRef;

  JsWriteBatch(this._batch, this._adminRef);

  @override
  void set(DocumentReference ref, Map<String, dynamic> data) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    final converted = _convertMapForJs(data, _adminRef);
    _batch.callMethod('set', [jsRef, converted]);
  }

  @override
  void update(DocumentReference ref, Map<String, dynamic> data) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    final converted = _convertMapForJs(data, _adminRef);
    _batch.callMethod('update', [jsRef, converted]);
  }

  @override
  void delete(DocumentReference ref) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    _batch.callMethod('delete', [jsRef]);
  }

  @override
  Future<void> commit() async {
    final promise = _batch.callMethod('commit');
    await js_util.promiseToFuture(promise);
  }
}

class JsAuthService implements AuthService {
  final js.JsObject _auth;

  JsAuthService(this._auth);

  @override
  Future<DecodedIdToken> verifyIdToken(String idToken) async {
    final promise = _auth.callMethod('verifyIdToken', [idToken]);
    final decoded = await js_util.promiseToFuture(promise) as js.JsObject;
    return DecodedIdToken(
      uid: (decoded['uid'] as String?) ?? '',
      email: decoded['email'] as String?,
      admin: decoded['admin'] as bool?,
    );
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      final promise = _auth.callMethod('deleteUser', [uid]);
      await js_util.promiseToFuture(promise);
    } catch (e) {
      final code = js_util.getProperty(e, 'code');
      if (code == 'auth/user-not-found') {
        throw const FirebaseAuthException(
          code: 'auth/user-not-found',
          message: 'User not found',
        );
      }
      rethrow;
    }
  }
}

dynamic _convertMapForJs(Map<String, dynamic> map, js.JsObject adminRef) {
  final firestoreClass = adminRef['firestore'] as js.JsObject;
  final fieldValueClass = firestoreClass['FieldValue'] as js.JsObject;
  final jsObj = js.JsObject(js.context['Object']);

  for (final entry in map.entries) {
    if (entry.value == FieldValue.deleteToken) {
      jsObj[entry.key] = fieldValueClass.callMethod('delete');
    } else if (entry.value is Map<String, dynamic>) {
      jsObj[entry.key] =
          _convertMapForJs(entry.value as Map<String, dynamic>, adminRef);
    } else {
      jsObj[entry.key] = js.JsObject.jsify(entry.value);
    }
  }
  return jsObj;
}
