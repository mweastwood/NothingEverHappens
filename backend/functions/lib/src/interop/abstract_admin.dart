import 'dart:async';

/// Sentinel class for Firestore FieldValue operations.
class FieldValue {
  static const deleteToken = '__FIELD_VALUE_DELETE__';
  static dynamic delete() => deleteToken;
}

/// Firebase Auth error.
class FirebaseAuthException implements Exception {
  final String code;
  final String message;

  const FirebaseAuthException({required this.code, required this.message});

  @override
  String toString() => 'FirebaseAuthException($code): $message';
}

/// Decoded Firebase ID Token.
class DecodedIdToken {
  final String uid;
  final String? email;
  final bool? admin;

  const DecodedIdToken({
    required this.uid,
    this.email,
    this.admin,
  });
}

/// Abstract Firebase Auth service.
abstract class AuthService {
  Future<DecodedIdToken> verifyIdToken(String idToken);
  Future<void> deleteUser(String uid);
}

/// Abstract Firestore Database.
abstract class FirestoreDatabase {
  CollectionReference collection(String path);
  Query collectionGroup(String collectionId);
  WriteBatch batch();
  Future<void> recursiveDelete(DocumentReference ref);
}

/// Abstract Firestore Collection Reference.
abstract class CollectionReference extends Query {
  DocumentReference doc([String? id]);
}

/// Abstract Firestore Query.
abstract class Query {
  Query where(String field, String op, dynamic value);
  Query limit(int count);
  Future<QuerySnapshot> get();
}

/// Abstract Firestore Query Snapshot.
abstract class QuerySnapshot {
  bool get empty;
  int get size;
  List<DocumentSnapshot> get docs;
}

/// Abstract Firestore Document Reference.
abstract class DocumentReference {
  String get id;
  CollectionReference collection(String path);
  Future<DocumentSnapshot> get();
  Future<void> set(Map<String, dynamic> data);
  Future<void> update(Map<String, dynamic> data);
  Future<void> delete();
}

/// Abstract Firestore Document Snapshot.
abstract class DocumentSnapshot {
  String get id;
  bool get exists;
  Map<String, dynamic>? data();
  DocumentReference get ref;
}

/// Abstract Firestore WriteBatch.
abstract class WriteBatch {
  void delete(DocumentReference ref);
  Future<void> commit();
}
