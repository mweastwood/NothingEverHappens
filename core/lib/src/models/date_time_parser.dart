/// Parses flexible date/time representations (ISO-8601 strings, compact digit
/// strings, epoch numbers, Firestore `_seconds`/`_nanoseconds` maps, or objects
/// with `.toDate()`) into a [DateTime].
DateTime? parseFlexibleDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null && parsed.year <= 3000) return parsed;
    if (RegExp(r'^\d{4}$').hasMatch(raw)) {
      final year = int.parse(raw);
      if (year >= 1900 && year <= 3000) return DateTime(year);
    }
    if (RegExp(r'^\d{6}$').hasMatch(raw)) {
      final year = int.parse(raw.substring(0, 4));
      final month = int.parse(raw.substring(4, 6));
      if (year >= 1900 && year <= 3000 && month >= 1 && month <= 12) {
        return DateTime(year, month);
      }
    }
    if (RegExp(r'^\d{8}$').hasMatch(raw)) {
      final year = int.parse(raw.substring(0, 4));
      final month = int.parse(raw.substring(4, 6));
      final day = int.parse(raw.substring(6, 8));
      if (year >= 1900 &&
          year <= 3000 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31) {
        return DateTime(year, month, day);
      }
    }
    final numVal = num.tryParse(raw);
    if (numVal != null) {
      final ms =
          numVal > 100000000000 ? numVal.toInt() : (numVal * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
    }
    return parsed;
  }
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  if (raw is Map) {
    final secondsRaw = raw['_seconds'] ?? raw['seconds'];
    final nanosRaw = raw['_nanoseconds'] ?? raw['nanoseconds'] ?? 0;
    final seconds = secondsRaw is num
        ? secondsRaw
        : (secondsRaw != null ? num.tryParse(secondsRaw.toString()) : null);
    if (seconds != null) {
      final nanos =
          nanosRaw is num ? nanosRaw : (num.tryParse(nanosRaw.toString()) ?? 0);
      return DateTime.fromMicrosecondsSinceEpoch(
        seconds.toInt() * 1000000 + (nanos.toInt() ~/ 1000),
        isUtc: true,
      );
    }
  }
  try {
    return (raw as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
