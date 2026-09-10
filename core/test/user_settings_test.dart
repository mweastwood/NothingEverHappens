import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('UserSettings Tests', () {
    test('default instantiation has expected defaults', () {
      const settings = UserSettings(hoursAvailable: 8.0);
      expect(settings.hoursAvailable, equals(8.0));
      expect(settings.showLastSpawnedDate, isFalse);
      expect(settings.showTaskListSortBar, isTrue);
      expect(settings.showScheduleListSortBar, isTrue);
      expect(settings.telemetryEnabled, isTrue);
      expect(settings.crashReportingEnabled, isTrue);
      expect(settings.taskListSort, isNull);
      expect(settings.scheduleListSort, isNull);
      expect(settings.defaultDailyCapacity, isNull);
      expect(settings.dailyCapacityOverrides, isNull);
      expect(settings.lastCapacityConfirmedWeek, isNull);
      expect(settings.acknowledgedMissedTaskCommunications, isNull);
    });

    test('fromJson handles empty map with defaults', () {
      final settings = UserSettings.fromJson(const {});
      expect(settings.hoursAvailable, equals(8.0));
      expect(settings.showLastSpawnedDate, isFalse);
      expect(settings.showTaskListSortBar, isTrue);
      expect(settings.showScheduleListSortBar, isTrue);
      expect(settings.telemetryEnabled, isTrue);
      expect(settings.crashReportingEnabled, isTrue);
    });

    test('fromJson and toJson round-trip with full properties', () {
      final now = DateTime(2026, 9, 8);
      final original = UserSettings(
        hoursAvailable: 6.5,
        showLastSpawnedDate: true,
        showTaskListSortBar: false,
        showScheduleListSortBar: false,
        telemetryEnabled: false,
        crashReportingEnabled: false,
        lastCapacityConfirmedWeek: '2026-W36',
        taskListSort: const [(column: 'priority', ascending: false)],
        scheduleListSort: const [(column: 'next_due', ascending: true)],
        defaultDailyCapacity: {'1': 7.0, '2': 8.0},
        dailyCapacityOverrides: {'2026-09-08': 4.0},
        acknowledgedMissedTaskCommunications: ['task-1:2026-09-08'],
      );

      final json = original.toJson(now: now);
      final deserialized = UserSettings.fromJson(json, now: now);

      expect(deserialized.hoursAvailable, equals(6.5));
      expect(deserialized.showLastSpawnedDate, isTrue);
      expect(deserialized.showTaskListSortBar, isFalse);
      expect(deserialized.showScheduleListSortBar, isFalse);
      expect(deserialized.telemetryEnabled, isFalse);
      expect(deserialized.crashReportingEnabled, isFalse);
      expect(deserialized.lastCapacityConfirmedWeek, equals('2026-W36'));
      expect(
        deserialized.taskListSort,
        equals(const [(column: 'priority', ascending: false)]),
      );
      expect(
        deserialized.scheduleListSort,
        equals(const [(column: 'next_due', ascending: true)]),
      );
      expect(deserialized.defaultDailyCapacity, equals({'1': 7.0, '2': 8.0}));
      expect(deserialized.dailyCapacityOverrides, equals({'2026-09-08': 4.0}));
      expect(
        deserialized.acknowledgedMissedTaskCommunications,
        equals(['task-1:2026-09-08']),
      );
      expect(deserialized, equals(original));
    });

    test(
        'getCapacityForDate evaluates overrides, defaults, and hoursAvailable in order',
        () {
      final settings = UserSettings(
        hoursAvailable: 5.0,
        defaultDailyCapacity: {
          '1': 6.0, // Monday
          '2': 7.0, // Tuesday
        },
        dailyCapacityOverrides: {
          '2026-09-08': 3.0, // Tuesday override
        },
      );

      // Tuesday 2026-09-08: override takes precedence over default weekday
      expect(settings.getCapacityForDate(DateTime(2026, 9, 8)), equals(3.0));

      // Monday 2026-09-07: uses default daily capacity (6.0)
      expect(settings.getCapacityForDate(DateTime(2026, 9, 7)), equals(6.0));

      // Wednesday 2026-09-09: no override and no weekday default -> fallback to hoursAvailable (5.0)
      expect(settings.getCapacityForDate(DateTime(2026, 9, 9)), equals(5.0));
    });

    test(
        'pruning drops overrides older than 90 days and comms older than 30 days',
        () {
      final fixedNow = DateTime(
          2026, 9, 8); // cutoff for comms: ~2026-08-09; overrides: ~2026-06-10

      final json = {
        'hoursAvailable': 8.0,
        'dailyCapacityOverrides': {
          '2026-09-01': 5.0, // kept
          '2026-04-01': 2.0, // pruned (>90 days)
        },
        'acknowledgedMissedTaskCommunications': [
          't1:2026-09-05', // kept
          't2:2026-07-01', // pruned (>30 days)
          'unformatted_comm', // kept because no colon format
        ],
      };

      final settings = UserSettings.fromJson(json, now: fixedNow);
      expect(
          settings.dailyCapacityOverrides?.containsKey('2026-09-01'), isTrue);
      expect(
          settings.dailyCapacityOverrides?.containsKey('2026-04-01'), isFalse);
      expect(
        settings.acknowledgedMissedTaskCommunications,
        equals(['t1:2026-09-05', 'unformatted_comm']),
      );
    });

    test('copyWith properly updates fields and preserves unchanged ones', () {
      const original = UserSettings(
        hoursAvailable: 8.0,
        showLastSpawnedDate: false,
      );

      final updated = original.copyWith(
        hoursAvailable: 10.0,
        showLastSpawnedDate: true,
      );

      expect(updated.hoursAvailable, equals(10.0));
      expect(updated.showLastSpawnedDate, isTrue);
      expect(updated.showTaskListSortBar, equals(original.showTaskListSortBar));
    });
  });
}
