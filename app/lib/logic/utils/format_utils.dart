class FormatUtils {
  const FormatUtils._();

  static String formatDurationHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) {
      return '${h}h ${m}m';
    } else if (h > 0) {
      return '${h}h';
    } else {
      return '${m}m';
    }
  }

  static String formatDuration(Duration duration, {bool compact = false}) {
    final minutes = duration.inMinutes;
    if (compact) {
      final h = duration.inHours;
      final m = minutes % 60;
      if (h > 0 && m > 0) {
        return '${h}h ${m}m';
      } else if (h > 0) {
        return '${h}h';
      } else {
        return '${m}m';
      }
    }
    if (minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      final hourStr = hours == 1 ? '1 hr' : '$hours hrs';
      final minStr = remainingMinutes > 0 ? '$remainingMinutes min' : '';
      return minStr.isEmpty ? hourStr : '$hourStr $minStr';
    } else {
      return '$minutes min';
    }
  }

  static String formatIsoDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

String formatDurationHours(double hours) =>
    FormatUtils.formatDurationHours(hours);

String formatDuration(Duration duration, {bool compact = false}) =>
    FormatUtils.formatDuration(duration, compact: compact);

String formatIsoDate(DateTime d) => FormatUtils.formatIsoDate(d);
