import 'package:core/core.dart';
import 'package:test/test.dart';

class _FakeSnapshotMetadata {
  final bool hasPendingWrites = false;
  final bool isFromCache = false;
  const _FakeSnapshotMetadata();
}

class _FakeDocumentSnapshot {
  final String id;
  final Map<String, dynamic> dataMap;
  final _FakeSnapshotMetadata metadata = const _FakeSnapshotMetadata();

  _FakeDocumentSnapshot({
    required this.id,
    required this.dataMap,
  });

  Map<String, dynamic> data() => dataMap;
}

void main() {
  group('TaskSchedule labelIds tests', () {
    test('default instantiation has empty labelIds', () {
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Test',
        description: 'Desc',
      );
      expect(task.labelIds, isEmpty);
    });

    test('accepts labelIds in constructor', () {
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Test',
        description: 'Desc',
        labelIds: const ['L-1', 'L-2'],
      );
      expect(task.labelIds, equals(['L-1', 'L-2']));
    });

    test('serialization round-trip (toMap / fromMap)', () {
      final task = TaskSchedule(
        id: 'S-123',
        title: 'Label Task',
        description: 'Description',
        labelIds: ['L-alpha', 'L-beta'],
      );

      final map = task.toMap();
      expect(map['labelIds'], equals(['L-alpha', 'L-beta']));

      final restored = TaskSchedule.fromMap(map, id: 'S-123');
      expect(restored.labelIds, equals(['L-alpha', 'L-beta']));
    });

    test('fromMap defaults labelIds to empty list when null or missing', () {
      final task = TaskSchedule.fromMap({
        'title': 'No labels',
        'description': 'None',
      }, id: 'S-456');
      expect(task.labelIds, isEmpty);
    });

    test('fromFirestore parses labelIds correctly', () {
      final fakeSnapshot = _FakeDocumentSnapshot(
        id: 'S-doc-789',
        dataMap: {
          'title': 'Firestore Task',
          'description': 'From firestore',
          'labelIds': ['L-100', 'L-200'],
        },
      );

      final task = TaskSchedule.fromFirestore(fakeSnapshot);
      expect(task.id, equals('S-doc-789'));
      expect(task.labelIds, equals(['L-100', 'L-200']));
    });

    test('copyWith updates labelIds or clears them', () {
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Task',
        description: 'Desc',
        labelIds: ['L-1'],
      );

      final updated = task.copyWith(labelIds: ['L-2', 'L-3']);
      expect(updated.labelIds, equals(['L-2', 'L-3']));

      final cleared = updated.copyWith(clearLabelIds: true);
      expect(cleared.labelIds, isEmpty);

      final preserved = updated.copyWith(title: 'New Title');
      expect(preserved.labelIds, equals(['L-2', 'L-3']));
    });

    test('edit tracks labelIds modifications in changes map', () {
      final task = TaskSchedule(
        id: 'S-1',
        title: 'Task',
        description: 'Desc',
        labelIds: ['L-1', 'L-2'],
      );

      // Edit with different labelIds
      final mod1 = task.edit(
        newTitle: task.title,
        newDescription: task.description,
        newSchedules: task.schedules,
        newEstimatedDuration: task.estimatedDuration,
        newMissedPolicy: task.missedPolicy,
        newIsMaster: task.isMaster,
        newLastSpawnedDate: task.lastSpawnedDate,
        newIsFamily: task.isFamily,
        newPriority: task.priority,
        newLabelIds: ['L-3'],
      );
      expect(mod1.newTask.labelIds, equals(['L-3']));
      expect(mod1.changes['labelIds'], equals(['L-3']));

      // Edit without changing labelIds
      final mod2 = task.edit(
        newTitle: task.title,
        newDescription: task.description,
        newSchedules: task.schedules,
        newEstimatedDuration: task.estimatedDuration,
        newMissedPolicy: task.missedPolicy,
        newIsMaster: task.isMaster,
        newLastSpawnedDate: task.lastSpawnedDate,
        newIsFamily: task.isFamily,
        newPriority: task.priority,
        newLabelIds: ['L-1', 'L-2'],
      );
      expect(mod2.changes.containsKey('labelIds'), isFalse);

      // Edit with null newLabelIds preserves existing
      final mod3 = task.edit(
        newTitle: 'Updated',
        newDescription: task.description,
        newSchedules: task.schedules,
        newEstimatedDuration: task.estimatedDuration,
        newMissedPolicy: task.missedPolicy,
        newIsMaster: task.isMaster,
        newLastSpawnedDate: task.lastSpawnedDate,
        newIsFamily: task.isFamily,
        newPriority: task.priority,
      );
      expect(mod3.newTask.labelIds, equals(['L-1', 'L-2']));
      expect(mod3.changes.containsKey('labelIds'), isFalse);
    });

    test(
        'parses map timestamp with string seconds and nanoseconds without throwing',
        () {
      final schedule = TaskSchedule.fromMap({
        'title': 'Map Timestamp Schedule',
        'updatedAt': {
          '_seconds': '1725000000',
          '_nanoseconds': '500000000',
        },
      });
      expect(schedule.updatedAt, isNotNull);
      expect(schedule.updatedAt.millisecondsSinceEpoch, equals(1725000000500));
    });

    test('parses numeric string timestamp without throwing', () {
      final schedule = TaskSchedule.fromMap({
        'title': 'String Timestamp Schedule',
        'updatedAt': '1725000000',
      });
      expect(schedule.updatedAt, isNotNull);
      expect(schedule.updatedAt.millisecondsSinceEpoch, equals(1725000000000));
    });
  });
}
