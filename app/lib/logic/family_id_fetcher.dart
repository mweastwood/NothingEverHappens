import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_clock.dart';
import 'error_handler.dart';

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

  FamilyIdFetcher({
    required FirebaseFirestore? firestore,
    required String userId,
    ErrorHandler? errorHandler,
  }) : _firestore = firestore,
       _userId = userId,
       _errorHandler = errorHandler;

  String? get cachedFamilyId => _cachedFamilyId;
  DateTime? get lastFamilyIdCheck => _lastFamilyIdCheck;

  void clearCache() {
    _cachedFamilyId = null;
    _lastFamilyIdCheck = null;
  }

  Future<String?> getFamilyId() async {
    if (_firestore == null || _userId.isEmpty) return null;

    if (_lastFamilyIdCheck != null &&
        AppClock.now.difference(_lastFamilyIdCheck!) < familyIdCacheDuration) {
      return _cachedFamilyId;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
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
            .collection('users')
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
}
