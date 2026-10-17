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
        expect(TaskStatus.fromString('completed'), equals(TaskStatus.completed));
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
        expect(TaskStatus.fromString('COMPLETED'), equals(TaskStatus.completed));
        expect(TaskStatus.fromString('Completed'), equals(TaskStatus.completed));
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
          expect(TaskStatus.fromString('cancelled'), equals(TaskStatus.pending));
          expect(
            TaskStatus.fromString('in_progress'),
            equals(TaskStatus.pending),
          );
        },
      );
    });
  });
}
