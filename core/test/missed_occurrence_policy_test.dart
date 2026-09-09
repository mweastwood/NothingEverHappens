import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('MissedOccurrencePolicy Tests', () {
    group('Constructors and Defaults', () {
      test('Default constructor and named constructors', () {
        const policyDefault = MissedOccurrencePolicy();
        const policyPreferNewer = MissedOccurrencePolicy.preferNewer();
        const policyPreferOlder = MissedOccurrencePolicy.preferOlder();
        const policyStack = MissedOccurrencePolicy.stack();
        const policyAutoDismiss = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 3),
        );

        expect(policyDefault.policy, equals(MissedPolicy.stack));
        expect(policyDefault.gracePeriod, equals(const Duration(days: 1)));
        expect(policyDefault.isKeepAround, isTrue);
        expect(policyDefault.isAutoDismiss, isFalse);

        expect(policyPreferNewer.policy, equals(MissedPolicy.preferNewer));
        expect(policyPreferNewer.isKeepAround, isTrue);

        expect(policyPreferOlder.policy, equals(MissedPolicy.preferOlder));
        expect(policyPreferOlder.isKeepAround, isTrue);

        expect(policyStack.policy, equals(MissedPolicy.stack));
        expect(policyStack.isKeepAround, isTrue);

        expect(policyAutoDismiss.policy, equals(MissedPolicy.autoDismiss));
        expect(policyAutoDismiss.gracePeriod, equals(const Duration(hours: 3)));
        expect(policyAutoDismiss.isAutoDismiss, isTrue);
        expect(policyAutoDismiss.isKeepAround, isFalse);
      });

      test('Equality and hashCode', () {
        const p1 = MissedOccurrencePolicy.preferOlder();
        const p2 = MissedOccurrencePolicy.preferOlder();
        const p3 = MissedOccurrencePolicy.preferNewer();
        const p4 = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 1),
        );

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1, isNot(equals(p3)));
        expect(p1, isNot(equals(p4)));
      });

      test('toString output', () {
        const p = MissedOccurrencePolicy.stack();
        expect(
          p.toString(),
          equals(
            'MissedOccurrencePolicy(policy: MissedPolicy.stack, gracePeriod: 24:00:00.000000)',
          ),
        );
      });
    });

    group('Serialization (toJson / fromJson)', () {
      test('AutoDismiss round-trip', () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 2),
        );
        final json = policy.toJson();

        expect(json['policy'], equals('autoDismiss'));
        expect(json['type'], equals('autoDismiss'));
        expect(json['graceMinutes'], equals(120));

        final deserialized = MissedOccurrencePolicy.fromJson(json);
        expect(deserialized.policy, equals(MissedPolicy.autoDismiss));
        expect(deserialized.gracePeriod, equals(const Duration(hours: 2)));
      });

      test('KeepAround policies round-trip', () {
        for (final p in [
          const MissedOccurrencePolicy.stack(),
          const MissedOccurrencePolicy.preferNewer(),
          const MissedOccurrencePolicy.preferOlder(),
        ]) {
          final json = p.toJson();
          expect(json['type'], equals('keepAround'));
          expect(json.containsKey('graceMinutes'), isFalse);

          final deserialized = MissedOccurrencePolicy.fromJson(json);
          expect(deserialized.policy, equals(p.policy));
        }
      });

      test('Legacy JSON formats fallback correctly', () {
        // Missing policyStr but with type or legacyPolicy resets to stack
        final legacy1 = {'type': 'keepAround'};
        expect(
          MissedOccurrencePolicy.fromJson(legacy1).policy,
          equals(MissedPolicy.stack),
        );

        final legacy2 = {'legacyPolicy': 'skip'};
        expect(
          MissedOccurrencePolicy.fromJson(legacy2).policy,
          equals(MissedPolicy.stack),
        );

        final legacy3 = {
          'policy': 'autoDismiss',
          'legacyPolicy': 'skip',
          'graceMinutes': 0,
        };
        final deserialized3 = MissedOccurrencePolicy.fromJson(legacy3);
        expect(deserialized3.policy, equals(MissedPolicy.autoDismiss));
        expect(deserialized3.gracePeriod, equals(Duration.zero));

        final legacy4 = {'policy': 'skip', 'graceMinutes': 30};
        final deserialized4 = MissedOccurrencePolicy.fromJson(legacy4);
        expect(deserialized4.policy, equals(MissedPolicy.autoDismiss));
        expect(deserialized4.gracePeriod, equals(const Duration(minutes: 30)));
      });
    });

    group('Expiration Calculation', () {
      test('Non-autoDismiss returns null expiration and false for isExpired',
          () {
        const policy = MissedOccurrencePolicy.stack();
        final due = DateTime(2026, 9, 8, 17, 0);
        final future = DateTime(2026, 9, 15, 17, 0);

        expect(policy.calculateExpiration(due), isNull);
        expect(policy.isExpired(due, future), isFalse);
      });

      test(
          'AutoDismiss calculates correct expiration time and expiration status',
          () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 4),
        );
        final due = DateTime(2026, 9, 8, 12, 0);

        final expiration = policy.calculateExpiration(due);
        expect(expiration, equals(DateTime(2026, 9, 8, 16, 0)));

        // Before expiration
        expect(policy.isExpired(due, DateTime(2026, 9, 8, 15, 59)), isFalse);
        // Exactly at expiration
        expect(policy.isExpired(due, DateTime(2026, 9, 8, 16, 0)), isFalse);
        // After expiration
        expect(policy.isExpired(due, DateTime(2026, 9, 8, 16, 1)), isTrue);
      });

      test(
          'isInstanceExpired checks TaskInstance dueRelativeTime against scheduledDate',
          () {
        const policy = MissedOccurrencePolicy.autoDismiss(
          gracePeriod: Duration(hours: 2),
        );
        const scheduledDate = CivilDay(year: 2026, month: 9, day: 8);
        const dueTime = RelativeTime(dayOffset: 0, hour: 10, minute: 0);

        final instance = TaskInstance(
          id: 'inst-1',
          scheduleId: 'sched-1',
          ruleId: 'rule-1',
          title: 'Test',
          description: 'Description',
          scheduledDate: scheduledDate,
          startRelativeTime: const RelativeTime(hour: 9, minute: 0),
          dueRelativeTime: dueTime,
        );

        final beforeExpiry = DateTime(2026, 9, 8, 11, 59);
        final afterExpiry = DateTime(2026, 9, 8, 12, 1);

        expect(policy.isInstanceExpired(instance, beforeExpiry), isFalse);
        expect(policy.isInstanceExpired(instance, afterExpiry), isTrue);
      });
    });
  });
}
