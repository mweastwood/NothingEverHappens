import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task_status.dart';

void main() {
  group('TaskStatus.fromString', () {
    test('parses completed correctly', () {
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('COMPLETED'), TaskStatus.completed);
    });

    test('parses skipped correctly', () {
      expect(TaskStatus.fromString('skipped'), TaskStatus.skipped);
    });

    test('parses legacy dismissed status to skipped for backward compatibility', () {
      expect(TaskStatus.fromString('dismissed'), TaskStatus.skipped);
      expect(TaskStatus.fromString('DISMISSED'), TaskStatus.skipped);
    });

    test('parses failed correctly', () {
      expect(TaskStatus.fromString('failed'), TaskStatus.failed);
    });

    test('parses pending correctly', () {
      expect(TaskStatus.fromString('pending'), TaskStatus.pending);
    });

    test('falls back to pending for unknown or null values', () {
      expect(TaskStatus.fromString(null), TaskStatus.pending);
      expect(TaskStatus.fromString('unknown_status'), TaskStatus.pending);
    });
  });
}
