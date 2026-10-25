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
bool hasValidServiceSecret(
  Map<String, dynamic> headers, {
  String? envSecret,
}) {
  final secret =
      envSecret ?? getEnv('TASK_HUB_SECRET') ?? getEnv('SERVICE_SECRET');
  if (secret == null || secret.isEmpty) {
    return false;
  }
  final authHeader = extractHeader(headers, ['authorization']);
  final serviceKey = extractHeader(headers, ['x-service-secret', 'x-api-key']);
  return serviceKey == secret || authHeader == 'Bearer $secret';
}
