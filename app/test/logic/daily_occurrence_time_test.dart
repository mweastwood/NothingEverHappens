import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  group('DailyOccurrenceTime Custom Notifications', () {
    test('serialization and deserialization with notificationTime', () {
      const slot = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 8, minute: 30),
        dueTime: TimeOfDay(hour: 16, minute: 45),
        notificationTime: TimeOfDay(hour: 8, minute: 15),
      );

      final json = slot.toJson();
      expect(json['startHour'], 8);
      expect(json['startMinute'], 30);
      expect(json['dueHour'], 16);
      expect(json['dueMinute'], 45);
      expect(json['notificationHour'], 8);
      expect(json['notificationMinute'], 15);

      final decoded = DailyOccurrenceTime.fromJson(json);
      expect(decoded.startTime, const TimeOfDay(hour: 8, minute: 30));
      expect(decoded.dueTime, const TimeOfDay(hour: 16, minute: 45));
      expect(decoded.notificationTime, const TimeOfDay(hour: 8, minute: 15));
    });

    test(
      'backward-compatible deserialization when notificationTime is absent',
      () {
        final oldJson = {
          'startHour': 9,
          'startMinute': 0,
          'dueHour': 17,
          'dueMinute': 0,
        };

        final decoded = DailyOccurrenceTime.fromJson(oldJson);
        expect(decoded.startTime, const TimeOfDay(hour: 9, minute: 0));
        expect(decoded.dueTime, const TimeOfDay(hour: 17, minute: 0));
        expect(decoded.notificationTime, isNull);
      },
    );

    test('equality and hashCode checks', () {
      const slot1 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: TimeOfDay(hour: 9, minute: 45),
      );
      const slot2 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: TimeOfDay(hour: 9, minute: 45),
      );
      const slot3 = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 10, minute: 0),
        dueTime: TimeOfDay(hour: 11, minute: 0),
        notificationTime: null,
      );

      expect(slot1, equals(slot2));
      expect(slot1.hashCode, equals(slot2.hashCode));
      expect(slot1, isNot(equals(slot3)));
    });

    test('toString representation', () {
      const slot = DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 13, minute: 5),
        dueTime: TimeOfDay(hour: 14, minute: 20),
        notificationTime: TimeOfDay(hour: 12, minute: 50),
      );
      expect(
        slot.toString(),
        contains('start: 13:05, due: 14:20, notification: 12:50'),
      );
    });
  });
}
