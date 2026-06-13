import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task_delta.dart';

void main() {
  group('TaskDelta', () {
    final timestamp = DateTime(2024, 1, 1, 10, 0);
    final expiresAt = DateTime(2024, 4, 1, 10, 0);

    test('constructor sets fields correctly', () {
      final delta = TaskDelta(
        id: 'delta-1',
        taskId: 'task-1',
        timestamp: timestamp,
        expiresAt: expiresAt,
        operation: 'create',
        changedFields: {
          'title': 'New TaskSchedule',
          'description': 'Some description',
        },
        userId: 'user-1',
      );

      expect(delta.id, 'delta-1');
      expect(delta.taskId, 'task-1');
      expect(delta.timestamp, timestamp);
      expect(delta.expiresAt, expiresAt);
      expect(delta.operation, 'create');
      expect(delta.changedFields, {
        'title': 'New TaskSchedule',
        'description': 'Some description',
      });
      expect(delta.userId, 'user-1');
    });

    test('toJson serializes correctly', () {
      final delta = TaskDelta(
        id: 'delta-1',
        taskId: 'task-1',
        timestamp: timestamp,
        expiresAt: expiresAt,
        operation: 'create',
        changedFields: {'title': 'New TaskSchedule'},
        userId: 'user-1',
      );

      final json = delta.toJson();

      expect(json['id'], 'delta-1');
      expect(json['taskId'], 'task-1');
      expect(json['timestamp'], timestamp.toIso8601String());
      expect(json['expiresAt'], expiresAt.toIso8601String());
      expect(json['operation'], 'create');
      expect(json['changedFields'], {'title': 'New TaskSchedule'});
      expect(json['userId'], 'user-1');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'delta-1',
        'taskId': 'task-1',
        'timestamp': timestamp.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'operation': 'create',
        'changedFields': {'title': 'New TaskSchedule'},
        'userId': 'user-1',
      };

      final delta = TaskDelta.fromJson(json);

      expect(delta.id, 'delta-1');
      expect(delta.taskId, 'task-1');
      expect(delta.timestamp, timestamp);
      expect(delta.expiresAt, expiresAt);
      expect(delta.operation, 'create');
      expect(delta.changedFields, {'title': 'New TaskSchedule'});
      expect(delta.userId, 'user-1');
    });

    test('fromJson handles null changedFields gracefully', () {
      final json = {
        'id': 'delta-1',
        'taskId': 'task-1',
        'timestamp': timestamp.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'operation': 'delete',
        'changedFields': null,
        'userId': 'user-1',
      };

      final delta = TaskDelta.fromJson(json);

      expect(delta.id, 'delta-1');
      expect(delta.taskId, 'task-1');
      expect(delta.timestamp, timestamp);
      expect(delta.expiresAt, expiresAt);
      expect(delta.operation, 'delete');
      expect(delta.changedFields, isEmpty);
      expect(delta.userId, 'user-1');
    });
  });
}
