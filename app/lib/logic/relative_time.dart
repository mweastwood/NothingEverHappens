import 'package:flutter/material.dart';
import 'package:core/core.dart' as core;

export 'package:core/core.dart' show RelativeTime;

extension RelativeTimeFlutterExtension on core.RelativeTime {
  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);
}
