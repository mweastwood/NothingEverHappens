import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@visibleForTesting
bool? isWebOverrideForTesting;

bool get _isWeb => isWebOverrideForTesting ?? kIsWeb;

/// Extension providing safe single-shot fetch operations on [DocumentReference].
extension FirestoreDocFetchExtension<T> on DocumentReference<T> {
  /// Fetches the document snapshot safely across platforms.
  ///
  /// On Web ([kIsWeb]), calling standard `get()` creates transient watch targets
  /// in the Firebase JS SDK WebChannel connection that can race against active
  /// stream subscriptions (`snapshots().listen`) during cold start, triggering
  /// fatal `WatchChangeAggregator` assertion crashes (`pendingResponses < 0`).
  /// To prevent this race condition, on Web this method resolves the snapshot
  /// from [snapshots] using `snapshots().timeout(timeout).first`, attaching
  /// the timeout directly to the stream so the subscription cancels on timeout.
  ///
  /// **Note on [options]**: The [options] parameter is passed to [get] on
  /// non-web platforms (mobile/desktop). On Web, snapshot streams are used
  /// instead, so [options] is not applicable and is ignored.
  Future<DocumentSnapshot<T>> safeGet({
    GetOptions? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isWeb) {
      return snapshots().timeout(timeout).first;
    }
    return get(options).timeout(timeout);
  }
}

/// Extension providing safe single-shot fetch operations on [Query].
extension FirestoreQueryFetchExtension<T> on Query<T> {
  /// Fetches the query snapshot safely across platforms.
  ///
  /// On Web ([kIsWeb]), calling standard `get()` creates transient watch targets
  /// in the Firebase JS SDK WebChannel connection that can race against active
  /// stream subscriptions (`snapshots().listen`) during cold start, triggering
  /// fatal `WatchChangeAggregator` assertion crashes (`pendingResponses < 0`).
  /// To prevent this race condition, on Web this method resolves the snapshot
  /// from [snapshots] using `snapshots().timeout(timeout).first`, attaching
  /// the timeout directly to the stream so the subscription cancels on timeout.
  ///
  /// **Note on [options]**: The [options] parameter is passed to [get] on
  /// non-web platforms (mobile/desktop). On Web, snapshot streams are used
  /// instead, so [options] is not applicable and is ignored.
  Future<QuerySnapshot<T>> safeGet({
    GetOptions? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isWeb) {
      return snapshots().timeout(timeout).first;
    }
    return get(options).timeout(timeout);
  }
}
