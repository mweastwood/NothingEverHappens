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
  group('TaskSchedule Properties & Serialization', () {
    test('isOverdue checks dueFromMidnight correctly', () {
      const todayCivil = CivilDay(year: 2024, month: 1, day: 1);
      final task = TaskSchedule(
        id: '1',
        title: 'Test',
        description: 'Test',
        schedules: [
          OneOffSchedule(
            date: todayCivil,
            startRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 0, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
          ),
        ],
      );

      expect(task.isOverdue(DateTime(2024, 1, 1, 10, 0)), isFalse);
      expect(task.isOverdue(DateTime(2024, 1, 1, 13, 0)), isTrue);
    });

    test(
        'toFirestore and fromFirestore serialize multiple schedules, policies, and Agile fields correctly',
        () {
      final task = TaskSchedule(
        id: 'task-test',
        title: 'Multi TaskSchedule',
        description: 'Desc',
        schedules: [
          DailySchedule(
            startDate: const CivilDay(year: 2026, month: 3, day: 8),
            interval: 1,
            startRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 7),
              targetHour: 9,
              targetMinute: 30,
            ),
            missedOccurrencePolicy: const MissedOccurrencePolicy.autoDismiss(
              gracePeriod: Duration(hours: 4),
            ),
          ),
          WeeklySchedule(
            startDate: const CivilDay(year: 2026, month: 3, day: 8),
            interval: 1,
            daysOfWeek: const {1, 3, 5},
            startRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 20, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 21, minute: 0),
          ),
        ],
        activeOccurrenceIndex: 1,
        estimatedDuration: const Duration(minutes: 45),
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        priority: TaskPriority.high,
        cycleId: '2026-W23',
        assignedUserId: 'user-1',
        preferredBy: const {'user-1': true, 'user-2': false},
        appLaunchUrl: 'https://example.com/app',
        labelIds: const ['L-alpha', 'L-beta'],
      );

      final map = task.toFirestore();
      expect(map['schedules'], isA<List>());
      expect(map['schedules'].length, 2);
      expect(map['activeOccurrenceIndex'], 1);
      expect(map['estimatedDuration'], 45);
      expect(map['isFamily'], true);
      expect(map['familyCompletionMode'], 'individual');
      expect(map['priority'], 'high');
      expect(map['cycleId'], '2026-W23');
      expect(map['assignedUserId'], 'user-1');
      expect(map['appLaunchUrl'], 'https://example.com/app');
      expect(map['labelIds'], ['L-alpha', 'L-beta']);

      final deserialized = TaskSchedule.fromFirestore(
        _FakeDocumentSnapshot(id: task.id, dataMap: map),
      );
      expect(deserialized.id, task.id);
      expect(deserialized.schedules.length, 2);
      expect(deserialized.schedulingPolicy, isA<CompletionRelativePolicy>());
      final policy = deserialized.schedulingPolicy as CompletionRelativePolicy;
      expect(policy.interval, const Duration(days: 7));
      expect(policy.targetHour, 9);
      expect(policy.targetMinute, 30);
      expect(deserialized.missedOccurrencePolicy.isAutoDismiss, isTrue);
      expect(deserialized.missedOccurrencePolicy.gracePeriod,
          const Duration(hours: 4));
      expect(deserialized.estimatedDuration, const Duration(minutes: 45));
      expect(deserialized.isFamily, true);
      expect(
          deserialized.familyCompletionMode, FamilyCompletionMode.individual);
      expect(deserialized.priority, TaskPriority.high);
      expect(deserialized.cycleId, '2026-W23');
      expect(deserialized.preferredBy['user-1'], true);
      expect(deserialized.preferredBy['user-2'], false);
      expect(deserialized.assignedUserId, 'user-1');
      expect(deserialized.appLaunchUrl, 'https://example.com/app');
      expect(deserialized.labelIds, ['L-alpha', 'L-beta']);
    });

    test(
        'fromMap and copyWith handle defaults, labelIds clearing, and missing updatedAt',
        () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final missingUpdatedAt = TaskSchedule.fromMap({
        'title': 'Legacy Task Missing UpdatedAt',
      }, id: 'S-legacy-1');
      expect(missingUpdatedAt.updatedAt, equals(epoch));
      expect(missingUpdatedAt.labelIds, isEmpty);
      expect(missingUpdatedAt.estimatedDuration, isNull);

      final updated = missingUpdatedAt.copyWith(
        labelIds: ['L-2', 'L-3'],
        familyCompletionMode: FamilyCompletionMode.anyone,
        skipIfNoCapacity: true,
      );
      expect(updated.labelIds, equals(['L-2', 'L-3']));
      expect(updated.familyCompletionMode, FamilyCompletionMode.anyone);
      expect(updated.skipIfNoCapacity, isTrue);

      final cleared = updated.copyWith(clearLabelIds: true);
      expect(cleared.labelIds, isEmpty);
    });
  });

  group('TaskSchedule Editing, Diffs, and Whitespace Trimming', () {
    test('TaskSchedule.edit() returns correctly updated task and changes map',
        () {
      final task = TaskSchedule(
        id: 'edit-test-task',
        title: '   Initial Title   ',
        description: '   Initial Desc   \n\t',
        schedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 8),
            startRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
          ),
        ],
        labelIds: ['L-1', 'L-2'],
      );

      expect(task.title, 'Initial Title');
      expect(task.description, 'Initial Desc');

      final result = task.edit(
        newTitle: '   Updated Title   ',
        newDescription: 'Initial Desc', // unchanged
        newSchedules: [
          OneOffSchedule(
            date: const CivilDay(year: 2026, month: 3, day: 9),
            startRelativeTime:
                const RelativeTime(dayOffset: -1, hour: 10, minute: 0),
            dueRelativeTime:
                const RelativeTime(dayOffset: 0, hour: 18, minute: 0),
          ),
        ],
        newEstimatedDuration: null,
        newMissedPolicy: MissedPolicy.stack,
        newIsMaster: false,
        newLastSpawnedDate: null,
        newIsFamily: true,
        newFamilyCompletionMode: FamilyCompletionMode.individual,
        newPriority: TaskPriority.high,
        newLabelIds: ['L-3'],
      );

      final newTask = result.newTask;
      final changes = result.changes;

      expect(newTask.id, task.id);
      expect(newTask.title, 'Updated Title');
      expect(newTask.description, 'Initial Desc');
      expect(newTask.schedules.first.startRelativeTime.dayOffset, -1);
      expect(newTask.schedules.first.startRelativeTime.hour, 10);
      expect(newTask.schedules.first.dueRelativeTime.hour, 18);
      expect((newTask.schedules.first as OneOffSchedule).date.day, 9);
      expect(newTask.estimatedDuration, isNull);
      expect(newTask.isFamily, isTrue);
      expect(newTask.familyCompletionMode, FamilyCompletionMode.individual);
      expect(newTask.priority, TaskPriority.high);
      expect(newTask.labelIds, equals(['L-3']));

      expect(changes['title'], 'Updated Title');
      expect(changes.containsKey('description'), isFalse);
      expect(changes['schedules'][0]['startRelativeTime']['dayOffset'], -1);
      expect(changes['schedules'][0]['startRelativeTime']['hour'], 10);
      expect(changes['schedules'][0]['dueRelativeTime']['hour'], 18);
      expect(changes['schedules'][0]['date']['day'], 9);
      expect(changes['estimatedDuration'], isNull);
      expect(changes['isFamily'], isTrue);
      expect(changes['familyCompletionMode'], 'individual');
      expect(changes['priority'], 'high');
      expect(changes['labelIds'], equals(['L-3']));

      // Edit converting family task back to personal without changing labelIds
      final revertResult = newTask.edit(
        newTitle: newTask.title,
        newDescription: newTask.description,
        newSchedules: newTask.schedules,
        newEstimatedDuration: newTask.estimatedDuration,
        newMissedPolicy: newTask.missedPolicy,
        newIsMaster: newTask.isMaster,
        newLastSpawnedDate: newTask.lastSpawnedDate,
        newIsFamily: false,
        newPriority: newTask.priority,
        newLabelIds: ['L-3'],
      );
      expect(revertResult.newTask.isFamily, isFalse);
      expect(revertResult.changes['isFamily'], isFalse);
      expect(revertResult.changes.containsKey('labelIds'), isFalse);
    });
  });
}
