import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/missed_occurrence_policy.dart';
import 'package:nothing_ever_happens/logic/missed_policy.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:flutter/material.dart';

void main() {
  group('MissedOccurrencePolicy Tests', () {
    group('Constructors and Defaults', () {
      test('Default constructor and custom policies', () {
        const policy1 = MissedOccurrencePolicy();
        const policy2 = MissedOccurrencePolicy.preferNewer();
        const policy3 = MissedOccurrencePolicy.preferOlder();
        const policy4 = MissedOccurrencePolicy.stack();
        const policy5 = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 3),
        );

        expect(policy1.policy, MissedPolicy.stack);
        expect(policy2.policy, MissedPolicy.preferNewer);
        expect(policy3.policy, MissedPolicy.preferOlder);
        expect(policy4.policy, MissedPolicy.stack);
        expect(policy5.policy, MissedPolicy.autoDismiss);
        expect(policy5.gracePeriod, const Duration(hours: 3));
      });

      test(
        'Legacy constructor mapping preserves legacyPolicy and correct gracePeriod',
        () {
          const policySkip = MissedOccurrencePolicy(policy: MissedPolicy.skip);

          expect(policySkip.policy, MissedPolicy.autoDismiss);
          expect(policySkip.legacyPolicy, MissedPolicy.skip);
          expect(policySkip.gracePeriod, Duration.zero);
        },
      );

      test('Legacy keepAround constructor mapping', () {
        const policySkip = MissedOccurrencePolicy.keepAround(
          legacyPolicy: MissedPolicy.skip,
        );

        expect(policySkip.policy, MissedPolicy.autoDismiss);
        expect(policySkip.legacyPolicy, MissedPolicy.skip);
        expect(policySkip.gracePeriod, Duration.zero);
      });

      test('Equality and hashCode', () {
        const p1 = MissedOccurrencePolicy.preferOlder();
        const p2 = MissedOccurrencePolicy.preferOlder();
        const p3 = MissedOccurrencePolicy.preferNewer();

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1, isNot(equals(p3)));
      });

      test('Serialization (toJson / fromJson)', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 2),
        );
        final json = policy.toJson();

        expect(json['policy'], 'autoDismiss');
        expect(json['graceMinutes'], 120);

        final deserialized = MissedOccurrencePolicy.fromJson(json);
        expect(deserialized.policy, MissedPolicy.autoDismiss);
        expect(deserialized.gracePeriod, const Duration(hours: 2));
      });

      test(
        'Serialization preserves legacyPolicy and gracePeriod for mapped skip',
        () {
          const policy = MissedOccurrencePolicy(policy: MissedPolicy.skip);
          final json = policy.toJson();

          expect(json['policy'], 'autoDismiss');
          expect(json['legacyPolicy'], 'skip');
          expect(json['graceMinutes'], 0);

          final deserialized = MissedOccurrencePolicy.fromJson(json);
          expect(deserialized.policy, MissedPolicy.autoDismiss);
          expect(deserialized.legacyPolicy, MissedPolicy.skip);
          expect(deserialized.gracePeriod, Duration.zero);
        },
      );

      test('Legacy deserialization resets to stack', () {
        // A legacy JSON without 'policy' key or with old enums
        final legacyJson1 = {'type': 'keepAround', 'legacyPolicy': 'rollover'};
        final legacyJson2 = {'type': 'keepAround', 'legacyPolicy': 'shift'};

        final p1 = MissedOccurrencePolicy.fromJson(legacyJson1);
        final p2 = MissedOccurrencePolicy.fromJson(legacyJson2);

        expect(p1.policy, MissedPolicy.stack);
        expect(p1.legacyPolicy, MissedPolicy.stack);
        expect(p2.policy, MissedPolicy.stack);
        expect(p2.legacyPolicy, MissedPolicy.stack);
      });
    });

    group('Expiration Logic', () {
      final baseTime = DateTime(2026, 6, 1, 12, 0);

      test('Non-autoDismiss policies never expire', () {
        const policy = MissedOccurrencePolicy.preferNewer();
        expect(policy.calculateExpiration(baseTime), isNull);
        expect(
          policy.isExpired(baseTime, baseTime.add(const Duration(days: 10))),
          isFalse,
        );
      });

      test('Auto-dismiss calculates correct expiration', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 4),
        );
        expect(
          policy.calculateExpiration(baseTime),
          baseTime.add(const Duration(hours: 4)),
        );
      });

      test('Auto-dismiss properly evaluates isExpired', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 2),
        );
        expect(
          policy.isExpired(baseTime, baseTime.add(const Duration(hours: 1))),
          isFalse,
        );
        expect(
          policy.isExpired(baseTime, baseTime.add(const Duration(hours: 2))),
          isFalse,
        );
        expect(
          policy.isExpired(
            baseTime,
            baseTime.add(const Duration(hours: 2, seconds: 1)),
          ),
          isTrue,
        );
      });

      test('isInstanceExpired correctly checks a TaskInstance', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 2),
        );
        final instance = TaskInstance(
          id: 'test-inst',
          scheduleId: 'test-sched',
          title: 'Test',
          description: '',
          scheduledDate: CivilDay(year: 2026, month: 6, day: 19),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 12, minute: 0),
          ),
        );

        final dueTime = DateTime(2026, 6, 19, 12, 0);
        final expiredTime = DateTime(2026, 6, 19, 14, 0, 1);

        expect(policy.isInstanceExpired(instance, dueTime), isFalse);
        expect(policy.isInstanceExpired(instance, expiredTime), isTrue);
      });
    });
  });
}
