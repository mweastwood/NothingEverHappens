import '../interop/firebase_admin.dart';
import '../interop/node_interop.dart';

/// Extracts the first matching header value from [headers] (case-insensitive),
/// unwrapping single/multi-value list headers if present.
String? extractHeader(Map<String, dynamic> headers, List<String> targetNames) {
  for (final name in targetNames) {
    if (headers.containsKey(name)) {
      final val = headers[name];
      return val is List
          ? (val.isNotEmpty ? val.first.toString() : null)
          : val?.toString();
    }
  }
  final lowerTargets = targetNames.map((n) => n.toLowerCase()).toSet();
  for (final entry in headers.entries) {
    if (lowerTargets.contains(entry.key.toLowerCase())) {
      final val = entry.value;
      return val is List
          ? (val.isNotEmpty ? val.first.toString() : null)
          : val?.toString();
    }
  }
  return null;
}

/// Extracts a non-empty Bearer token from the `Authorization` header, or null if absent.
String? extractBearerToken(Map<String, dynamic> headers) {
  final authHeader = extractHeader(headers, ['authorization']);
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  final token = authHeader.substring(7).trim();
  return token.isEmpty ? null : token;
}

/// Checks whether [headers] contain a valid service secret matching [envSecret],
/// `TASK_HUB_SECRET`, or `SERVICE_SECRET`.
bool hasValidServiceSecret(Map<String, dynamic> headers, {String? envSecret}) {
  final secret =
      envSecret ?? getEnv('TASK_HUB_SECRET') ?? getEnv('SERVICE_SECRET');
  if (secret == null || secret.isEmpty) {
    return false;
  }
  final authHeader = extractHeader(headers, ['authorization']);
  final serviceKey = extractHeader(headers, ['x-service-secret', 'x-api-key']);
  return serviceKey == secret || authHeader == 'Bearer $secret';
}

/// Outcome of verifying a Bearer Firebase ID token from request headers.
class BearerTokenVerification {
  final bool hasToken;
  final DecodedIdToken? decodedToken;
  final Object? error;

  const BearerTokenVerification({
    required this.hasToken,
    this.decodedToken,
    this.error,
  });

  bool get isValid => decodedToken != null;
}

/// Extracts a Bearer token from [headers] and verifies it using [auth] (or default Firebase Admin Auth).
Future<BearerTokenVerification> verifyBearerIdToken(
  Map<String, dynamic> headers, {
  AuthService? auth,
}) async {
  final idToken = extractBearerToken(headers);
  if (idToken == null) {
    return const BearerTokenVerification(hasToken: false);
  }
  try {
    final firebaseAuth = auth ?? getFirebaseAdminAuth();
    final decoded = await firebaseAuth.verifyIdToken(idToken);
    return BearerTokenVerification(hasToken: true, decodedToken: decoded);
  } catch (e) {
    return BearerTokenVerification(hasToken: true, error: e);
  }
}

/// Parses a flexible timestamp representation into a UTC [DateTime], or returns [fallback] if unparseable.
///
/// Supports:
/// - `DateTime`
/// - `num` (milliseconds since epoch)
/// - `String` (numeric milliseconds since epoch or ISO-8601 string)
/// - `Map` with `seconds` or `_seconds` (and optional `nanoseconds` / `_nanoseconds`)
/// - JS `Date` or Firestore `Timestamp` objects exposing `.toDate()`, `.toMillis()`, or `.toISOString()`.
DateTime? parseFlexibleTimestamp(dynamic raw, {DateTime? fallback}) {
  if (raw == null) return fallback;
  if (raw is DateTime) return raw.toUtc();
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  if (raw is String) {
    final str = raw.trim();
    if (str.isEmpty) return fallback;
    final asInt = int.tryParse(str);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    final asNum = num.tryParse(str);
    if (asNum != null) {
      return DateTime.fromMillisecondsSinceEpoch(asNum.toInt(), isUtc: true);
    }
    return DateTime.tryParse(str)?.toUtc() ?? fallback;
  }
  if (raw is Map) {
    final seconds = raw['seconds'] ?? raw['_seconds'];
    if (seconds is num) {
      final nanos = (raw['nanoseconds'] ?? raw['_nanoseconds'] ?? 0) as num;
      final ms = (seconds * 1000).toInt() + (nanos ~/ 1000000);
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
  }
  try {
    final dynamic millis = (raw as dynamic).toMillis();
    if (millis is num) {
      return DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true);
    }
  } catch (_) {}
  try {
    final dynamic date = (raw as dynamic).toDate();
    if (date != null && !identical(date, raw)) {
      final parsed = parseFlexibleTimestamp(date);
      if (parsed != null) return parsed;
    }
  } catch (_) {}
  try {
    final dynamic iso = (raw as dynamic).toISOString();
    if (iso is String) {
      final parsed = DateTime.tryParse(iso)?.toUtc();
      if (parsed != null) return parsed;
    }
  } catch (_) {}
  final str = raw.toString().trim();
  if (str.isNotEmpty) {
    final asInt = int.tryParse(str);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    final parsed = DateTime.tryParse(str)?.toUtc();
    if (parsed != null) return parsed;
  }
  return fallback;
}
