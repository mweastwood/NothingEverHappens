String formatDurationHours(double hours) {
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
