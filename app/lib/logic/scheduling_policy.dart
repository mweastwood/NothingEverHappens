import 'package:flutter/material.dart';
import 'package:core/core.dart' as core;

export 'package:core/core.dart'
    show
        SchedulingType,
        SchedulingPolicy,
        FixedCalendarPolicy,
        CompletionRelativePolicy;

extension CompletionRelativePolicyFlutterExtension
    on core.CompletionRelativePolicy {
  TimeOfDay get targetTime => TimeOfDay(hour: targetHour, minute: targetMinute);
}
