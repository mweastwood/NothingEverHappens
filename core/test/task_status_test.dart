import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('TaskStatus Tests', () {
    group('Enum Definition & Values', () {
      test('has expected enum values and count', () {
        expect(TaskStatus.values, hasLength(4));
        expect(
          TaskStatus.values,
          equals([
            TaskStatus.pending,
            TaskStatus.completed,
            TaskStatus.skipped,
            TaskStatus.failed,
          ]),
        );
      });

      test('has correct name property for all values', () {
        expect(TaskStatus.pending.name, equals('pending'));
        expect(TaskStatus.completed.name, equals('completed'));
        expect(TaskStatus.skipped.name, equals('skipped'));
        expect(TaskStatus.failed.name, equals('failed'));
      });
    });

    group('JSON Serialization (toJson)', () {
      test('serializes all enum values to correct string representation', () {
        expect(TaskStatus.pending.toJson(), equals('pending'));
        expect(TaskStatus.completed.toJson(), equals('completed'));
        expect(TaskStatus.skipped.toJson(), equals('skipped'));
        expect(TaskStatus.failed.toJson(), equals('failed'));
      });
    });

    group('String Parsing & Deserialization (TaskStatus.fromString)', () {
      test('parses canonical lowercase string values correctly', () {
        expect(TaskStatus.fromString('pending'), equals(TaskStatus.pending));
        expect(
            TaskStatus.fromString('completed'), equals(TaskStatus.completed));
        expect(TaskStatus.fromString('skipped'), equals(TaskStatus.skipped));
        expect(TaskStatus.fromString('failed'), equals(TaskStatus.failed));
      });

      test('maps legacy dismissed status to TaskStatus.skipped', () {
        expect(TaskStatus.fromString('dismissed'), equals(TaskStatus.skipped));
        expect(TaskStatus.fromString('DISMISSED'), equals(TaskStatus.skipped));
        expect(TaskStatus.fromString('Dismissed'), equals(TaskStatus.skipped));
      });

      test('handles uppercase and mixed-case string values', () {
        expect(TaskStatus.fromString('PENDING'), equals(TaskStatus.pending));
        expect(TaskStatus.fromString('Pending'), equals(TaskStatus.pending));
        expect(
            TaskStatus.fromString('COMPLETED'), equals(TaskStatus.completed));
        expect(
            TaskStatus.fromString('Completed'), equals(TaskStatus.completed));
        expect(TaskStatus.fromString('SKIPPED'), equals(TaskStatus.skipped));
        expect(TaskStatus.fromString('Skipped'), equals(TaskStatus.skipped));
        expect(TaskStatus.fromString('FAILED'), equals(TaskStatus.failed));
        expect(TaskStatus.fromString('Failed'), equals(TaskStatus.failed));
      });

      test(
        'falls back to TaskStatus.pending for null, empty, or unknown strings',
        () {
          expect(TaskStatus.fromString(null), equals(TaskStatus.pending));
          expect(TaskStatus.fromString(''), equals(TaskStatus.pending));
          expect(TaskStatus.fromString('   '), equals(TaskStatus.pending));
          expect(TaskStatus.fromString('unknown'), equals(TaskStatus.pending));
          expect(
            TaskStatus.fromString('unknown_state'),
            equals(TaskStatus.pending),
          );
          expect(
              TaskStatus.fromString('cancelled'), equals(TaskStatus.pending));
          expect(
            TaskStatus.fromString('in_progress'),
            equals(TaskStatus.pending),
          );
        },
      );
    });
  });

  group('InstanceStatusReason Tests', () {
    test('has expected enum values and wire values', () {
      expect(InstanceStatusReason.values, hasLength(8));
      expect(
        InstanceStatusReason.userCompleted.value,
        equals('user_completed'),
      );
      expect(
        InstanceStatusReason.userDismissed.value,
        equals('user_dismissed'),
      );
      expect(InstanceStatusReason.userModified.value, equals('user_modified'));
      expect(
        InstanceStatusReason.schedulerAutoDismiss.value,
        equals('scheduler_auto_dismiss'),
      );
      expect(
        InstanceStatusReason.schedulerPreferNewer.value,
        equals('scheduler_prefer_newer'),
      );
      expect(
        InstanceStatusReason.schedulerPreferOlder.value,
        equals('scheduler_prefer_older'),
      );
      expect(
        InstanceStatusReason.schedulerCapacityLimit.value,
        equals('scheduler_capacity_limit'),
      );
      expect(
        InstanceStatusReason.schedulerGenerated.value,
        equals('scheduler_generated'),
      );
    });

    test('correctly classifies user vs scheduler actions and revivability', () {
      for (final reason in InstanceStatusReason.values) {
        final expectedUserAction =
            reason == InstanceStatusReason.userCompleted ||
                reason == InstanceStatusReason.userDismissed ||
                reason == InstanceStatusReason.userModified;
        expect(reason.isUserAction, equals(expectedUserAction));
        expect(reason.isSchedulerAction, equals(!expectedUserAction));
        expect(
          reason.isRevivableByCapacity,
          equals(reason == InstanceStatusReason.schedulerCapacityLimit),
        );
      }
    });

    test('tryParse parses known wire values and returns null for unknown', () {
      for (final reason in InstanceStatusReason.values) {
        expect(InstanceStatusReason.tryParse(reason.value), equals(reason));
      }
      expect(InstanceStatusReason.tryParse(null), isNull);
      expect(InstanceStatusReason.tryParse(''), isNull);
      expect(InstanceStatusReason.tryParse('unknown_reason'), isNull);
    });
  });
}
