import 'package:flutter/material.dart';

enum SchedulingType { fixedCalendar, completionRelative }

abstract class SchedulingPolicy {
  const SchedulingPolicy();

  SchedulingType get type;
  Map<String, dynamic> toJson();

  factory SchedulingPolicy.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = SchedulingType.values.firstWhere((e) => e.name == typeStr);
    switch (type) {
      case SchedulingType.fixedCalendar:
        return const FixedCalendarPolicy();
      case SchedulingType.completionRelative:
        final intervalMinutes = json['intervalMinutes'] as int;
        final hour = json['targetHour'] as int;
        final minute = json['targetMinute'] as int;
        return CompletionRelativePolicy(
          interval: Duration(minutes: intervalMinutes),
          targetTime: TimeOfDay(hour: hour, minute: minute),
        );
    }
  }
}

class FixedCalendarPolicy extends SchedulingPolicy {
  @override
  SchedulingType get type => SchedulingType.fixedCalendar;

  const FixedCalendarPolicy();

  @override
  Map<String, dynamic> toJson() {
    return {'type': type.name};
  }

  @override
  bool operator ==(Object other) {
    return other is FixedCalendarPolicy;
  }

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() {
    return 'FixedCalendarPolicy()';
  }
}

class CompletionRelativePolicy extends SchedulingPolicy {
  @override
  SchedulingType get type => SchedulingType.completionRelative;

  final Duration interval;
  final TimeOfDay targetTime;

  const CompletionRelativePolicy({
    required this.interval,
    required this.targetTime,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'intervalMinutes': interval.inMinutes,
      'targetHour': targetTime.hour,
      'targetMinute': targetTime.minute,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletionRelativePolicy &&
        other.interval == interval &&
        other.targetTime == targetTime;
  }

  @override
  int get hashCode => Object.hash(interval, targetTime);

  @override
  String toString() {
    return 'CompletionRelativePolicy(interval: $interval, targetTime: $targetTime)';
  }
}
