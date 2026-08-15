import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

extension FirestoreDocFetchExtension<T> on DocumentReference<T> {
  Future<DocumentSnapshot<T>> safeGet({
    GetOptions? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) {
      return snapshots().first.timeout(timeout);
    }
    return get(options).timeout(timeout);
  }
}

extension FirestoreQueryFetchExtension<T> on Query<T> {
  Future<QuerySnapshot<T>> safeGet({
    GetOptions? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) {
      return snapshots().first.timeout(timeout);
    }
    return get(options).timeout(timeout);
  }
}
