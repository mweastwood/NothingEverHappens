import 'package:flutter/material.dart';

/// Represents a start and due time of day for an occurrence on a given day.
class DailyOccurrenceTime {
  final TimeOfDay startTime;
  final TimeOfDay dueTime;
  final TimeOfDay? notificationTime;

  const DailyOccurrenceTime({
    required this.startTime,
    required this.dueTime,
    this.notificationTime,
  });

  factory DailyOccurrenceTime.fromJson(Map<String, dynamic> json) {
    return DailyOccurrenceTime(
      startTime: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      dueTime: TimeOfDay(
        hour: json['dueHour'] as int,
        minute: json['dueMinute'] as int,
      ),
      notificationTime:
          json['notificationHour'] != null && json['notificationMinute'] != null
          ? TimeOfDay(
              hour: json['notificationHour'] as int,
              minute: json['notificationMinute'] as int,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'dueHour': dueTime.hour,
      'dueMinute': dueTime.minute,
      if (notificationTime != null) 'notificationHour': notificationTime!.hour,
      if (notificationTime != null)
        'notificationMinute': notificationTime!.minute,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyOccurrenceTime &&
        other.startTime == startTime &&
        other.dueTime == dueTime &&
        other.notificationTime == notificationTime;
  }

  @override
  int get hashCode => Object.hash(startTime, dueTime, notificationTime);

  @override
  String toString() {
    final notifStr = notificationTime != null
        ? '${notificationTime!.hour}:${notificationTime!.minute.toString().padLeft(2, '0')}'
        : 'none';
    return 'DailyOccurrenceTime(start: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}, due: ${dueTime.hour}:${dueTime.minute.toString().padLeft(2, '0')}, notification: $notifStr)';
  }
}
