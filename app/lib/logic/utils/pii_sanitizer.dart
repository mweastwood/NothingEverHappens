import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../civil_day.dart';
import '../relative_time.dart';

/// Utility class providing PII masking and JSON-safe data sanitization.
class PiiSanitizer {
  static const Set<String> _roleAndStatusValues = {
    'admin',
    'owner',
    'member',
    'parent',
    'non-parent',
    'viewer',
    'editor',
    'creator',
    'active',
    'pending',
    'accepted',
    'declined',
    'inactive',
  };

  static const List<String> _piiKeywords = [
    'displayname',
    'display_name',
    'fullname',
    'full_name',
    'firstname',
    'first_name',
    'lastname',
    'last_name',
    'username',
    'user_name',
    'phonenumber',
    'phone_number',
    'phone',
    'photourl',
    'photo_url',
    'photo',
    'avatar',
    'picture',
    'address',
    'street',
    'zipcode',
    'postalcode',
    'bio',
    'sender',
    'recipient',
    'inviter',
    'invitee',
    'profile',
  ];

  /// Masks an email address by keeping the first character of the local part.
  /// Example: 'john.doe@example.com' -> 'j***@example.com'
  static String? maskEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split('@');
    if (parts.length != 2) return '***';
    final local = parts[0];
    final domain = parts[1];
    if (local.isEmpty) return '***@$domain';
    return '${local[0]}***@$domain';
  }

  /// Masks a general PII string by keeping the first character.
  /// Example: 'John Doe' -> 'J***'
  static String? maskPii(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0]}***';
  }

  static bool _isNonPiiKey(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('email')) return false;
    if (lowerKey == 'id' ||
        lowerKey == 'ids' ||
        lowerKey == 'uid' ||
        lowerKey == 'uids' ||
        lowerKey == 'role' ||
        lowerKey == 'status' ||
        lowerKey == 'appversion' ||
        lowerKey == 'app_version' ||
        lowerKey == 'modifiedbyappversion' ||
        lowerKey == 'lastmodifiedbyappversion' ||
        lowerKey == 'modified_by_app_version' ||
        lowerKey == 'last_modified_by_app_version' ||
        lowerKey == 'platform' ||
        lowerKey == 'modifiedbyplatform' ||
        lowerKey == 'lastmodifiedbyplatform' ||
        lowerKey == 'modified_by_platform' ||
        lowerKey == 'last_modified_by_platform' ||
        lowerKey.endsWith('platform') ||
        lowerKey.endsWith('appversion') ||
        lowerKey.endsWith('app_version') ||
        lowerKey == 'lastseenat' ||
        lowerKey == 'last_seen_at' ||
        lowerKey == 'version' ||
        lowerKey == 'statusreason' ||
        lowerKey == 'status_reason') {
      return true;
    }
    if (lowerKey.endsWith('_id') ||
        lowerKey.endsWith('_ids') ||
        lowerKey.endsWith('-id') ||
        lowerKey.endsWith('-ids') ||
        lowerKey.endsWith('_uid') ||
        lowerKey.endsWith('_uids') ||
        lowerKey.endsWith('-uid') ||
        lowerKey.endsWith('-uids')) {
      return true;
    }
    if (key.endsWith('Id') ||
        key.endsWith('Ids') ||
        key.endsWith('ID') ||
        key.endsWith('IDS') ||
        key.endsWith('Uid') ||
        key.endsWith('Uids')) {
      return true;
    }
    return false;
  }

  static bool _isPiiKey(String key) {
    if (_isNonPiiKey(key)) return false;
    final lowerKey = key.toLowerCase();
    if (_piiKeywords.any((k) => lowerKey.contains(k))) return true;
    if (lowerKey == 'name' || lowerKey == 'member' || lowerKey == 'members') {
      return true;
    }
    return false;
  }

  static bool _isRoleOrStatusValue(String value) {
    final lower = value.trim().toLowerCase();
    return _roleAndStatusValues.contains(lower);
  }

  /// Recursively transforms [value] into a JSON-encodable structure while
  /// masking emails and PII fields.
  static dynamic sanitize(
    dynamic value, {
    bool isEmailKey = false,
    bool isPiiKey = false,
  }) {
    if (value == null) return null;
    if (value is num || value is bool) return value;

    if (value is String) {
      if (isEmailKey) return maskEmail(value);
      if (isPiiKey) {
        if (_isRoleOrStatusValue(value)) return value;
        return maskPii(value);
      }
      return value;
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is CivilDay) {
      return sanitize(
        value.toJson(),
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is RelativeTime) {
      return sanitize(
        value.toJson(),
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is TimeOfDay) {
      return sanitize(
        {'hour': value.hour, 'minute': value.minute},
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is Enum) {
      return value.name;
    }

    if (value is Duration) {
      return value.inMilliseconds;
    }

    if (value is GeoPoint) {
      return sanitize(
        {'latitude': value.latitude, 'longitude': value.longitude},
        isEmailKey: isEmailKey,
        isPiiKey: isPiiKey,
      );
    }

    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((k, v) {
        final keyStr = k.toString();
        final lowerKey = keyStr.toLowerCase();
        final entryIsEmailKey = isEmailKey || lowerKey.contains('email');
        final entryIsPiiKey =
            !_isNonPiiKey(keyStr) && (isPiiKey || _isPiiKey(keyStr));
        result[keyStr] = sanitize(
          v,
          isEmailKey: entryIsEmailKey,
          isPiiKey: entryIsPiiKey,
        );
      });
      return result;
    }

    if (value is Iterable) {
      return value
          .map((e) => sanitize(e, isEmailKey: isEmailKey, isPiiKey: isPiiKey))
          .toList();
    }

    try {
      final dynamic json = (value as dynamic).toJson();
      return sanitize(json, isEmailKey: isEmailKey, isPiiKey: isPiiKey);
    } catch (_) {
      final str = value.toString();
      if (isEmailKey) return maskEmail(str);
      if (isPiiKey) return maskPii(str);
      return str;
    }
  }

  /// Backward-compatible alias for [sanitize].
  static dynamic sanitizeForJson(
    dynamic value, {
    bool isEmailKey = false,
    bool isPiiKey = false,
  }) => sanitize(value, isEmailKey: isEmailKey, isPiiKey: isPiiKey);
}
