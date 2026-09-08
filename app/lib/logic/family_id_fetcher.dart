import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_clock.dart';
import 'error_handler.dart';
import 'family.dart';
import 'firestore_paths.dart';

/// Helper class for querying and caching the user's family ID from Firestore.
class FamilyIdFetcher {
  /// Cache duration for family ID to avoid excessive DB reads.
  static const Duration familyIdCacheDuration = Duration(seconds: 15);

  /// Timeout for fetching family ID from the network.
  static const Duration familyIdFetchTimeout = Duration(seconds: 2);

  final FirebaseFirestore? _firestore;
  final String _userId;
  final ErrorHandler? _errorHandler;

  String? _cachedFamilyId;
  DateTime? _lastFamilyIdCheck;
  Family? _cachedFamily;
  DateTime? _lastFamilyCheck;

  FamilyIdFetcher({
    required FirebaseFirestore? firestore,
    required String userId,
    ErrorHandler? errorHandler,
  }) : _firestore = firestore,
       _userId = userId,
       _errorHandler = errorHandler;

  String? get cachedFamilyId => _cachedFamilyId;
  DateTime? get lastFamilyIdCheck => _lastFamilyIdCheck;
  Family? get cachedFamily => _cachedFamily;
  DateTime? get lastFamilyCheck => _lastFamilyCheck;

  void clearCache() {
    _cachedFamilyId = null;
    _lastFamilyIdCheck = null;
    _cachedFamily = null;
    _lastFamilyCheck = null;
  }

  Future<String?> getFamilyId() async {
    if (_firestore == null || _userId.isEmpty) return null;

    if (_lastFamilyIdCheck != null &&
        AppClock.now.difference(_lastFamilyIdCheck!) < familyIdCacheDuration) {
      return _cachedFamilyId;
    }

    try {
      final userDoc = await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(familyIdFetchTimeout);
      _cachedFamilyId = userDoc.data()?['familyId'] as String?;
      _lastFamilyIdCheck = AppClock.now;
      return _cachedFamilyId;
    } catch (e, st) {
      // Expected if offline, fallback to cache
      _errorHandler?.report(e, stackTrace: st);
      try {
        final cacheDoc = await _firestore
            .collection(FirestorePaths.users)
            .doc(_userId)
            .get(const GetOptions(source: Source.cache));
        _cachedFamilyId = cacheDoc.data()?['familyId'] as String?;
        _lastFamilyIdCheck = AppClock.now;
        return _cachedFamilyId;
      } catch (e2, st2) {
        _errorHandler?.report(e2, stackTrace: st2);
        return _cachedFamilyId;
      }
    }
  }

  Future<Family?> getFamily() async {
    if (_firestore == null || _userId.isEmpty) return null;
    final familyId = await getFamilyId();
    if (familyId == null || familyId.isEmpty) return null;

    if (_lastFamilyCheck != null &&
        _cachedFamily != null &&
        AppClock.now.difference(_lastFamilyCheck!) < familyIdCacheDuration) {
      return _cachedFamily;
    }

    try {
      final doc = await _firestore
          .collection(FirestorePaths.families)
          .doc(familyId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(familyIdFetchTimeout);
      if (doc.exists && doc.data() != null) {
        _cachedFamily = Family.fromJson(doc.data()!, doc.id);
        _lastFamilyCheck = AppClock.now;
        return _cachedFamily;
      }
    } catch (e, st) {
      _errorHandler?.report(e, stackTrace: st);
      try {
        final cacheDoc = await _firestore
            .collection(FirestorePaths.families)
            .doc(familyId)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && cacheDoc.data() != null) {
          _cachedFamily = Family.fromJson(cacheDoc.data()!, cacheDoc.id);
          _lastFamilyCheck = AppClock.now;
          return _cachedFamily;
        }
      } catch (e2, st2) {
        _errorHandler?.report(e2, stackTrace: st2);
      }
    }
    return _cachedFamily;
  }

  Future<bool> isFamilyLeader([String? targetUserId]) async {
    final uid = targetUserId ?? _userId;
    final family = await getFamily();
    if (family == null) return false;
    return family.isFamilyLeader(uid);
  }
}
