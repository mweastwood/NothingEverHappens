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
          targetHour: hour,
          targetMinute: minute,
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
  final int targetHour;
  final int targetMinute;

  const CompletionRelativePolicy({
    required this.interval,
    required this.targetHour,
    required this.targetMinute,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'intervalMinutes': interval.inMinutes,
      'targetHour': targetHour,
      'targetMinute': targetMinute,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletionRelativePolicy &&
        other.interval == interval &&
        other.targetHour == targetHour &&
        other.targetMinute == targetMinute;
  }

  @override
  int get hashCode => Object.hash(interval, targetHour, targetMinute);

  @override
  String toString() {
    return 'CompletionRelativePolicy(interval: $interval, targetHour: $targetHour, targetMinute: $targetMinute)';
  }
}
