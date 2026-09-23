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
    return JsFirestoreDatabase(jsDb, _admin);
  }
  _dbInstance ??= _admin.callMethod('firestore') as js.JsObject;
  return JsFirestoreDatabase(_dbInstance!, _admin);
}

AuthService getFirebaseAdminAuth() {
  initializeFirebaseAdmin();
  _authInstance ??= _admin.callMethod('auth') as js.JsObject;
  return JsAuthService(_authInstance!);
}

void _ensureJsBridge() {
  if (js_util.hasProperty(
          js_util.globalThis, '__antigravity_store_unwrapped') ||
      js.context.hasProperty('__antigravity_store_unwrapped')) {
    return;
  }
  js.context.callMethod('eval', [
    '''
    (function() {
      var g = typeof globalThis !== 'undefined' ? globalThis : (typeof self !== 'undefined' ? self : global);
      g.__antigravity_unwrapped = null;
      g.__antigravity_store_unwrapped = function(target) {
        g.__antigravity_unwrapped = target;
      };
      g.__antigravity_json_stringify = function(target) {
        return JSON.stringify(target);
      };
    })();
    '''
  ]);
}

dynamic _unwrapJsObject(dynamic obj) {
  if (obj is! js.JsObject) return obj;

  if (js_util.hasProperty(obj, '_jsObject')) {
    final raw = js_util.getProperty(obj, '_jsObject');
    if (raw != null) return raw;
  }

  _ensureJsBridge();
  if (js.context.hasProperty('__antigravity_store_unwrapped')) {
    js.context.callMethod('__antigravity_store_unwrapped', [obj]);
  } else if (js_util.hasProperty(
      js_util.globalThis, '__antigravity_store_unwrapped')) {
    js_util
        .callMethod(js_util.globalThis, '__antigravity_store_unwrapped', [obj]);
  }
  final unwrapped =
      js_util.getProperty(js_util.globalThis, '__antigravity_unwrapped') ??
          (js.context.hasProperty('__antigravity_unwrapped')
              ? js.context['__antigravity_unwrapped']
              : null);
  js_util.setProperty(js_util.globalThis, '__antigravity_unwrapped', null);
  if (js.context.hasProperty('__antigravity_unwrapped')) {
    js.context['__antigravity_unwrapped'] = null;
  }
  return unwrapped ?? obj;
}

bool _isThenable(dynamic obj) {
  if (obj == null) return false;
  if (obj is String || obj is num || obj is bool) return false;
  try {
    if (obj is js.JsObject) {
      return obj.hasProperty('then');
    }
    return js_util.hasProperty(obj, 'then');
  } catch (_) {
    return false;
  }
}

Future<T> _safePromiseToFuture<T>(dynamic jsPromiseOrObject) {
  if (jsPromiseOrObject is Future<T>) return jsPromiseOrObject;
  if (jsPromiseOrObject is Future) return jsPromiseOrObject.then((v) => v as T);

  final unwrapped = _unwrapJsObject(jsPromiseOrObject);

  if (!_isThenable(unwrapped) && !_isThenable(jsPromiseOrObject)) {
    throw StateError(
      'Expected a JavaScript Promise/thenable but received object without a "then" method: $unwrapped',
    );
  }

  final target = _isThenable(unwrapped) && unwrapped is! js.JsObject
      ? unwrapped
      : _unwrapJsObject(jsPromiseOrObject);

  return js_util.promiseToFuture<T>(target);
}

Future<T> safePromiseToFuture<T>(dynamic jsPromiseOrObject) =>
    _safePromiseToFuture<T>(jsPromiseOrObject);

class JsFirestoreDatabase implements FirestoreDatabase {
  final dynamic _db;
  final js.JsObject _adminRef;

  JsFirestoreDatabase(this._db, this._adminRef);

  @override
  CollectionReference collection(String path) {
    final col = _db is js.JsObject
        ? _db.callMethod('collection', [path])
        : js_util.callMethod(_db, 'collection', [path]);
    return JsCollectionReference(col, _adminRef);
  }

  @override
  Query collectionGroup(String collectionId) {
    final q = _db is js.JsObject
        ? _db.callMethod('collectionGroup', [collectionId])
        : js_util.callMethod(_db, 'collectionGroup', [collectionId]);
    return JsQuery(q, _adminRef);
  }

  @override
  WriteBatch batch() {
    final b = _db is js.JsObject
        ? _db.callMethod('batch')
        : js_util.callMethod(_db, 'batch', []);
    return JsWriteBatch(b, _adminRef);
  }

  @override
  Future<void> recursiveDelete(DocumentReference ref) async {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    if (js_util.hasProperty(_db, 'recursiveDelete')) {
      final promise = _db is js.JsObject
          ? _db.callMethod('recursiveDelete', [jsRef])
          : js_util.callMethod(_db, 'recursiveDelete', [jsRef]);
      await _safePromiseToFuture(promise);
    } else {
      await ref.delete();
    }
  }
}

class JsCollectionReference extends JsQuery implements CollectionReference {
  JsCollectionReference(super.rawQuery, super.adminRef);

  @override
  DocumentReference doc([String? id]) {
    final docRef = id != null
        ? (rawQuery is js.JsObject
            ? rawQuery.callMethod('doc', [id])
            : js_util.callMethod(rawQuery, 'doc', [id]))
        : (rawQuery is js.JsObject
            ? rawQuery.callMethod('doc')
            : js_util.callMethod(rawQuery, 'doc', []));
    return JsDocumentReference(docRef, adminRef);
  }
}

class JsQuery implements Query {
  final dynamic rawQuery;
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
    final nextQ = rawQuery is js.JsObject
        ? rawQuery.callMethod('where', [field, op, jsVal])
        : js_util.callMethod(rawQuery, 'where', [field, op, jsVal]);
    return JsQuery(nextQ, adminRef);
  }

  @override
  Query limit(int count) {
    final nextQ = rawQuery is js.JsObject
        ? rawQuery.callMethod('limit', [count])
        : js_util.callMethod(rawQuery, 'limit', [count]);
    return JsQuery(nextQ, adminRef);
  }

  @override
  Future<QuerySnapshot> get() async {
    final promise = rawQuery is js.JsObject
        ? rawQuery.callMethod('get')
        : js_util.callMethod(rawQuery, 'get', []);
    final snap = await _safePromiseToFuture(promise);
    return JsQuerySnapshot(snap, adminRef);
  }
}

class JsQuerySnapshot implements QuerySnapshot {
  final dynamic _snap;
  final js.JsObject _adminRef;

  JsQuerySnapshot(this._snap, this._adminRef);

  @override
  bool get empty {
    if (_snap is js.JsObject) return (_snap['empty'] as bool?) ?? true;
    return (js_util.getProperty(_snap, 'empty') as bool?) ?? true;
  }

  @override
  int get size {
    if (_snap is js.JsObject) return (_snap['size'] as num?)?.toInt() ?? 0;
    return (js_util.getProperty(_snap, 'size') as num?)?.toInt() ?? 0;
  }

  @override
  List<DocumentSnapshot> get docs {
    final dynamic rawDocs = _snap is js.JsObject
        ? _snap['docs']
        : js_util.getProperty(_snap, 'docs');
    final docsList = rawDocs as List?;
    if (docsList == null) return [];
    return docsList.map((d) => JsDocumentSnapshot(d, _adminRef)).toList();
  }
}

class JsDocumentReference implements DocumentReference {
  final dynamic rawJsRef;
  final js.JsObject adminRef;

  JsDocumentReference(this.rawJsRef, this.adminRef);

  @override
  String get id {
    if (rawJsRef is js.JsObject) return (rawJsRef['id'] as String?) ?? '';
    return (js_util.getProperty(rawJsRef, 'id') as String?) ?? '';
  }

  @override
  CollectionReference collection(String path) {
    final col = rawJsRef is js.JsObject
        ? rawJsRef.callMethod('collection', [path])
        : js_util.callMethod(rawJsRef, 'collection', [path]);
    return JsCollectionReference(col, adminRef);
  }

  @override
  Future<DocumentSnapshot> get() async {
    final promise = rawJsRef is js.JsObject
        ? rawJsRef.callMethod('get')
        : js_util.callMethod(rawJsRef, 'get', []);
    final snap = await _safePromiseToFuture(promise);
    return JsDocumentSnapshot(snap, adminRef);
  }

  @override
  Future<void> set(Map<String, dynamic> data) async {
    final converted = _convertMapForJs(data, adminRef);
    final promise = rawJsRef is js.JsObject
        ? rawJsRef.callMethod('set', [converted])
        : js_util.callMethod(rawJsRef, 'set', [converted]);
    await _safePromiseToFuture(promise);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    final converted = _convertMapForJs(data, adminRef);
    final promise = rawJsRef is js.JsObject
        ? rawJsRef.callMethod('update', [converted])
        : js_util.callMethod(rawJsRef, 'update', [converted]);
    await _safePromiseToFuture(promise);
  }

  @override
  Future<void> delete() async {
    final promise = rawJsRef is js.JsObject
        ? rawJsRef.callMethod('delete')
        : js_util.callMethod(rawJsRef, 'delete', []);
    await _safePromiseToFuture(promise);
  }
}

class JsDocumentSnapshot implements DocumentSnapshot {
  final dynamic _snap;
  final js.JsObject _adminRef;

  JsDocumentSnapshot(this._snap, this._adminRef);

  @override
  String get id {
    if (_snap is js.JsObject) return (_snap['id'] as String?) ?? '';
    return (js_util.getProperty(_snap, 'id') as String?) ?? '';
  }

  @override
  bool get exists {
    if (_snap is js.JsObject) return (_snap['exists'] as bool?) ?? false;
    return (js_util.getProperty(_snap, 'exists') as bool?) ?? false;
  }

  @override
  DocumentReference get ref {
    final rawRef =
        _snap is js.JsObject ? _snap['ref'] : js_util.getProperty(_snap, 'ref');
    return JsDocumentReference(rawRef, _adminRef);
  }

  @override
  Map<String, dynamic>? data() {
    final rawData = _snap is js.JsObject
        ? _snap.callMethod('data')
        : js_util.callMethod(_snap, 'data', []);
    if (rawData == null) return null;
    final unwrapped = _unwrapJsObject(rawData);
    _ensureJsBridge();
    final jsonStr = js_util.hasProperty(
            js_util.globalThis, '__antigravity_json_stringify')
        ? js_util.callMethod(
            js_util.globalThis,
            '__antigravity_json_stringify',
            [unwrapped],
          ) as String?
        : (js.context.hasProperty('__antigravity_json_stringify')
            ? js.context.callMethod('__antigravity_json_stringify', [unwrapped])
                as String?
            : js.context['JSON'].callMethod('stringify', [unwrapped])
                as String?);
    if (jsonStr == null) return null;
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      if (decoded.length == 1 &&
          decoded.containsKey('o') &&
          decoded['o'] is Map) {
        return Map<String, dynamic>.from(decoded['o'] as Map);
      }
      return decoded;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map.length == 1 && map.containsKey('o') && map['o'] is Map) {
        return Map<String, dynamic>.from(map['o'] as Map);
      }
      return map;
    }
    return null;
  }
}

class JsWriteBatch implements WriteBatch {
  final dynamic _batch;
  final js.JsObject _adminRef;

  JsWriteBatch(this._batch, this._adminRef);

  @override
  void set(DocumentReference ref, Map<String, dynamic> data) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    final converted = _convertMapForJs(data, _adminRef);
    if (_batch is js.JsObject) {
      _batch.callMethod('set', [jsRef, converted]);
    } else {
      js_util.callMethod(_batch, 'set', [jsRef, converted]);
    }
  }

  @override
  void update(DocumentReference ref, Map<String, dynamic> data) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    final converted = _convertMapForJs(data, _adminRef);
    if (_batch is js.JsObject) {
      _batch.callMethod('update', [jsRef, converted]);
    } else {
      js_util.callMethod(_batch, 'update', [jsRef, converted]);
    }
  }

  @override
  void delete(DocumentReference ref) {
    final jsRef = (ref as JsDocumentReference).rawJsRef;
    if (_batch is js.JsObject) {
      _batch.callMethod('delete', [jsRef]);
    } else {
      js_util.callMethod(_batch, 'delete', [jsRef]);
    }
  }

  @override
  Future<void> commit() async {
    final promise = _batch is js.JsObject
        ? _batch.callMethod('commit')
        : js_util.callMethod(_batch, 'commit', []);
    await _safePromiseToFuture(promise);
  }
}

class JsAuthService implements AuthService {
  final dynamic _auth;

  JsAuthService(this._auth);

  @override
  Future<DecodedIdToken> verifyIdToken(String idToken) async {
    final promise = _auth is js.JsObject
        ? _auth.callMethod('verifyIdToken', [idToken])
        : js_util.callMethod(_auth, 'verifyIdToken', [idToken]);
    final decoded = await _safePromiseToFuture(promise);
    final uid = decoded is js.JsObject
        ? (decoded['uid'] as String?) ?? ''
        : (js_util.getProperty(decoded, 'uid') as String?) ?? '';
    final email = decoded is js.JsObject
        ? decoded['email'] as String?
        : js_util.getProperty(decoded, 'email') as String?;
    final admin = decoded is js.JsObject
        ? decoded['admin'] as bool?
        : js_util.getProperty(decoded, 'admin') as bool?;
    return DecodedIdToken(
      uid: uid,
      email: email,
      admin: admin,
    );
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      final promise = _auth is js.JsObject
          ? _auth.callMethod('deleteUser', [uid])
          : js_util.callMethod(_auth, 'deleteUser', [uid]);
      await _safePromiseToFuture(promise);
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

dynamic _convertValueForJs(
  dynamic value,
  js.JsObject adminRef,
  js.JsObject fieldValueClass,
  js.JsObject timestampClass,
) {
  if (value == null) {
    return null;
  } else if (value is String || value is num || value is bool) {
    return value;
  } else if (value == FieldValue.deleteToken) {
    return fieldValueClass.callMethod('delete');
  } else if (value is DateTime) {
    return timestampClass
        .callMethod('fromMillis', [value.millisecondsSinceEpoch]);
  } else if (value is Map<String, dynamic>) {
    return _convertMapForJs(value, adminRef);
  } else if (value is Map) {
    return _convertMapForJs(Map<String, dynamic>.from(value), adminRef);
  } else if (value is Iterable) {
    return js.JsArray.from(value.map(
      (item) =>
          _convertValueForJs(item, adminRef, fieldValueClass, timestampClass),
    ));
  } else {
    return js.JsObject.jsify(value);
  }
}

dynamic _convertMapForJs(Map<String, dynamic> map, js.JsObject adminRef) {
  final firestoreClass = adminRef['firestore'] as js.JsObject;
  final fieldValueClass = firestoreClass['FieldValue'] as js.JsObject;
  final timestampClass = firestoreClass['Timestamp'] as js.JsObject;
  final jsObj = js.JsObject(js.context['Object']);

  for (final entry in map.entries) {
    jsObj[entry.key] = _convertValueForJs(
      entry.value,
      adminRef,
      fieldValueClass,
      timestampClass,
    );
  }
  return jsObj;
}
