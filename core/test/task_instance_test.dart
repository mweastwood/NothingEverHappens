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
  group('TaskInstance Serialization and Helpers', () {
    const testDate = CivilDay(year: 2026, month: 6, day: 13);
    const testStart = RelativeTime(dayOffset: 0, hour: 9, minute: 0);
    const testDue = RelativeTime(dayOffset: 0, hour: 17, minute: 0);
    const testNotification = RelativeTime(dayOffset: 0, hour: 8, minute: 30);

    test('Constructor initializes all fields correctly', () {
      final completedAt = DateTime.utc(2026, 6, 13, 10, 0);
      final instance = TaskInstance(
        id: 'instance-123',
        scheduleId: 'schedule-456',
        ruleId: 'rule-456',
        title: 'Task Occurrence',
        description: 'Do the laundry',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        notificationRelativeTimes: [testNotification],
        isFamily: true,
        priority: TaskPriority.high,
        cycleId: 'cycle-789',
        assignedUserId: 'user-abc',
        completedByUserId: 'user-xyz',
        completedAt: completedAt,
        status: TaskStatus.completed,
      );

      expect(instance.id, 'instance-123');
      expect(instance.scheduleId, 'schedule-456');
      expect(instance.title, 'Task Occurrence');
      expect(instance.description, 'Do the laundry');
      expect(instance.scheduledDate, testDate);
      expect(instance.startRelativeTime, testStart);
      expect(instance.dueRelativeTime, testDue);
      expect(instance.notificationRelativeTimes, [testNotification]);
      expect(instance.isFamily, true);
      expect(instance.priority, TaskPriority.high);
      expect(instance.cycleId, 'cycle-789');
      expect(instance.assignedUserId, 'user-abc');
      expect(instance.completedByUserId, 'user-xyz');
      expect(instance.completedAt, completedAt);
      expect(instance.status, TaskStatus.completed);
      expect(instance.labelIds, isEmpty);
    });

    test('toFirestore and fromFirestore round-trip fields correctly', () {
      final completedAt = DateTime.utc(2026, 6, 13, 10, 0);
      final instance = TaskInstance(
        id: 'instance-123',
        scheduleId: 'schedule-456',
        ruleId: 'rule-456',
        title: 'Task Occurrence',
        description: 'Do the laundry',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        notificationRelativeTimes: [testNotification],
        isFamily: true,
        priority: TaskPriority.high,
        cycleId: 'cycle-789',
        assignedUserId: 'user-abc',
        completedByUserId: 'user-xyz',
        completedAt: completedAt,
        status: TaskStatus.completed,
        labelIds: const ['L-1', 'L-2'],
      );

      final map = instance.toFirestore();
      expect(map['scheduleId'], 'schedule-456');
      expect(map['ruleId'], 'rule-456');
      expect(map['title'], 'Task Occurrence');
      expect(map['description'], 'Do the laundry');
      expect(map['scheduledDate'], testDate.toJson());
      expect(map['startRelativeTime'], testStart.toJson());
      expect(map['dueRelativeTime'], testDue.toJson());
      expect(map['notificationRelativeTimes'], [testNotification.toJson()]);
      expect(map['isFamily'], true);
      expect(map['priority'], 'high');
      expect(map['cycleId'], 'cycle-789');
      expect(map['assignedUserId'], 'user-abc');
      expect(map['completedByUserId'], 'user-xyz');
      expect(map['completedAt'], completedAt);
      expect(map['status'], 'completed');
      expect(map['labelIds'], ['L-1', 'L-2']);

      final loaded = TaskInstance.fromFirestore(
        _FakeDocumentSnapshot(id: 'instance-123', dataMap: map),
      );
      expect(loaded.id, 'instance-123');
      expect(loaded.scheduleId, 'schedule-456');
      expect(loaded.ruleId, 'rule-456');
      expect(loaded.title, 'Task Occurrence');
      expect(loaded.description, 'Do the laundry');
      expect(loaded.scheduledDate, testDate);
      expect(loaded.startRelativeTime, testStart);
      expect(loaded.dueRelativeTime, testDue);
      expect(loaded.notificationRelativeTimes, [testNotification]);
      expect(loaded.isFamily, true);
      expect(loaded.priority, TaskPriority.high);
      expect(loaded.cycleId, 'cycle-789');
      expect(loaded.assignedUserId, 'user-abc');
      expect(loaded.completedByUserId, 'user-xyz');
      expect(loaded.completedAt, completedAt);
      expect(loaded.status, TaskStatus.completed);
      expect(loaded.labelIds, ['L-1', 'L-2']);
    });

    test(
        'fromFirestore deserializes legacy single notification and multiple notifications',
        () {
      const notif1 = RelativeTime(dayOffset: 0, hour: 8, minute: 0);
      const notif2 = RelativeTime(dayOffset: 0, hour: 12, minute: 0);

      final singleLoaded = TaskInstance.fromFirestore(
        _FakeDocumentSnapshot(
          id: 'instance-single',
          dataMap: {
            'scheduleId': 'schedule-456',
            'ruleId': 'rule-456',
            'title': 'Single Notification',
            'notificationRelativeTime': testNotification.toJson(),
          },
        ),
      );
      expect(singleLoaded.notificationRelativeTimes, [testNotification]);

      final multiLoaded = TaskInstance.fromFirestore(
        _FakeDocumentSnapshot(
          id: 'instance-multi',
          dataMap: {
            'scheduleId': 'schedule-456',
            'ruleId': 'rule-456',
            'title': 'Multiple Notifications',
            'notificationRelativeTimes': [notif1.toJson(), notif2.toJson()],
          },
        ),
      );
      expect(multiLoaded.notificationRelativeTimes, [notif1, notif2]);
    });

    test('copyWith copies, overrides, and clears fields correctly', () {
      final completedAt = DateTime.utc(2026, 6, 13, 10, 0);
      final instance = TaskInstance(
        id: 'instance-123',
        scheduleId: 'schedule-456',
        ruleId: 'rule-456',
        title: 'Original Title',
        description: 'Original Desc',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        notificationRelativeTimes: [testNotification],
        isFamily: false,
        priority: TaskPriority.low,
        cycleId: 'cycle-789',
        assignedUserId: 'user-abc',
        completedByUserId: 'user-xyz',
        completedAt: completedAt,
        status: TaskStatus.pending,
        labelIds: ['L-1'],
      );

      final updated = instance.copyWith(
        title: 'New Title',
        description: 'New Desc',
        scheduledDate: const CivilDay(year: 2026, month: 6, day: 14),
        startRelativeTime:
            const RelativeTime(dayOffset: 1, hour: 10, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 1, hour: 18, minute: 0),
        clearNotificationRelativeTimes: true,
        isFamily: true,
        priority: TaskPriority.high,
        clearCycleId: true,
        clearAssignedUserId: true,
        clearCompletedByUserId: true,
        clearCompletedAt: true,
        clearLabelIds: true,
        status: TaskStatus.completed,
      );

      expect(updated.id, 'instance-123');
      expect(updated.title, 'New Title');
      expect(updated.description, 'New Desc');
      expect(
          updated.scheduledDate, const CivilDay(year: 2026, month: 6, day: 14));
      expect(updated.startRelativeTime,
          const RelativeTime(dayOffset: 1, hour: 10, minute: 0));
      expect(updated.dueRelativeTime,
          const RelativeTime(dayOffset: 1, hour: 18, minute: 0));
      expect(updated.notificationRelativeTimes, isEmpty);
      expect(updated.isFamily, true);
      expect(updated.priority, TaskPriority.high);
      expect(updated.cycleId, isNull);
      expect(updated.assignedUserId, isNull);
      expect(updated.completedByUserId, isNull);
      expect(updated.completedAt, isNull);
      expect(updated.labelIds, isEmpty);
      expect(updated.status, TaskStatus.completed);
    });

    test(
        'Constructor and copyWith trim leading and trailing spaces from title and description',
        () {
      final instance = TaskInstance(
        scheduleId: 'schedule-1',
        ruleId: 'rule-1',
        title: '   Trimmed Instance Title   ',
        description: '   Trimmed Instance Description \t\n  ',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
      );

      expect(instance.title, 'Trimmed Instance Title');
      expect(instance.description, 'Trimmed Instance Description');

      final copied = instance.copyWith(
        title: '   Updated Instance Title   ',
        description: '   Updated Instance Description   ',
      );

      expect(copied.title, 'Updated Instance Title');
      expect(copied.description, 'Updated Instance Description');
    });

    test('isCompletedForUser returns correct status based on completion mode',
        () {
      final anyoneInstance = TaskInstance(
        scheduleId: 's1',
        ruleId: 'r1',
        title: 'Anyone Mode Task',
        description: '',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.anyone,
        status: TaskStatus.pending,
      );
      expect(anyoneInstance.isCompletedForUser('user1'), isFalse);

      final completedAnyone =
          anyoneInstance.copyWith(status: TaskStatus.completed);
      expect(completedAnyone.isCompletedForUser('user1'), isTrue);
      expect(completedAnyone.isCompletedForUser('user2'), isTrue);

      final individualInstance = TaskInstance(
        scheduleId: 's2',
        ruleId: 'r2',
        title: 'Individual Mode Task',
        description: '',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        completedByUserIds: const ['user1'],
        status: TaskStatus.pending,
      );
      expect(individualInstance.isCompletedForUser('user1'), isTrue);
      expect(individualInstance.isCompletedForUser('user2'), isFalse);
    });

    test(
        'serializes and deserializes familyCompletionMode, completedByUserIds, and telemetry fields',
        () {
      final instance = TaskInstance(
        id: 'inst-telemetry',
        scheduleId: 's-100',
        ruleId: 'r-100',
        title: 'Attributed Task',
        description: 'Testing telemetry fields',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.individual,
        completedByUserIds: ['userA', 'userB'],
        status: TaskStatus.skipped,
        statusReason: 'scheduler_prefer_older',
        lastModifiedByUserId: 'user-telemetry-1',
        lastModifiedByAppVersion: 'v1.2.3 (abc1234)',
        lastModifiedByPlatform: 'android',
      );

      final data = instance.toFirestore();
      final loaded = TaskInstance.fromFirestore(
        _FakeDocumentSnapshot(id: 'inst-telemetry', dataMap: data),
      );

      expect(loaded.familyCompletionMode, FamilyCompletionMode.individual);
      expect(loaded.completedByUserIds, ['userA', 'userB']);
      expect(loaded.statusReason, 'scheduler_prefer_older');
      expect(loaded.lastModifiedByUserId, 'user-telemetry-1');
      expect(loaded.lastModifiedByAppVersion, 'v1.2.3 (abc1234)');
      expect(loaded.lastModifiedByPlatform, 'android');

      final cleared = loaded.copyWith(
        clearCompletedByUserIds: true,
        clearStatusReason: true,
        clearLastModifiedByUserId: true,
        clearLastModifiedByAppVersion: true,
        clearLastModifiedByPlatform: true,
      );
      expect(cleared.completedByUserIds, isEmpty);
      expect(cleared.statusReason, isNull);
      expect(cleared.lastModifiedByUserId, isNull);
      expect(cleared.lastModifiedByAppVersion, isNull);
      expect(cleared.lastModifiedByPlatform, isNull);
    });

    test(
        'isCompletedOverdue and isCompletedOverdueByMoreThan24Hours work correctly',
        () {
      final baseInstance = TaskInstance(
        id: 'inst-overdue-test',
        scheduleId: 's-1',
        ruleId: 'r-1',
        title: 'Overdue Test',
        description: '',
        scheduledDate: const CivilDay(year: 2026, month: 7, day: 1),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        status: TaskStatus.completed,
      );

      final onTime =
          baseInstance.copyWith(completedAt: DateTime(2026, 7, 1, 16, 0));
      expect(onTime.isCompletedOverdue, isFalse);
      expect(onTime.isCompletedOverdueByMoreThan24Hours, isFalse);

      final exactlyOnTime =
          baseInstance.copyWith(completedAt: DateTime(2026, 7, 1, 17, 0));
      expect(exactlyOnTime.isCompletedOverdue, isFalse);

      final overdueUnder24h =
          baseInstance.copyWith(completedAt: DateTime(2026, 7, 1, 19, 0));
      expect(overdueUnder24h.isCompletedOverdue, isTrue);
      expect(overdueUnder24h.isCompletedOverdueByMoreThan24Hours, isFalse);

      final overdueExact24h =
          baseInstance.copyWith(completedAt: DateTime(2026, 7, 2, 17, 0));
      expect(overdueExact24h.isCompletedOverdue, isTrue);
      expect(overdueExact24h.isCompletedOverdueByMoreThan24Hours, isFalse);

      final overdueOver24h =
          baseInstance.copyWith(completedAt: DateTime(2026, 7, 2, 18, 0));
      expect(overdueOver24h.isCompletedOverdue, isTrue);
      expect(overdueOver24h.isCompletedOverdueByMoreThan24Hours, isTrue);

      final pendingTask = baseInstance.copyWith(
        status: TaskStatus.pending,
        completedAt: DateTime(2026, 7, 2, 18, 0),
      );
      expect(pendingTask.isCompletedOverdue, isFalse);
      expect(pendingTask.isCompletedOverdueByMoreThan24Hours, isFalse);
    });
  });

  group('TaskInstance scheduledDate and UTC normalization tests', () {
    test(
        'deserializes scheduledDate from Map, ISO String, or defaults to today',
        () {
      final fromMap = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': {'year': 2026, 'month': 8, 'day': 30},
      });
      expect(fromMap.scheduledDate,
          equals(const CivilDay(year: 2026, month: 8, day: 30)));

      final fromIso = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': '2026-08-30',
      });
      expect(fromIso.scheduledDate,
          equals(const CivilDay(year: 2026, month: 8, day: 30)));

      final nowCivilDay = CivilDay.fromDateTime(DateTime.now());
      final fromInvalid = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': 'invalid-date',
      });
      expect(fromInvalid.scheduledDate, equals(nowCivilDay));
    });

    test(
        'normalizes caller-supplied local updatedAt and completedAt to UTC and defaults missing updatedAt',
        () {
      final localTime = DateTime(2026, 9, 16, 15, 16, 27);
      final inst = TaskInstance(
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Local DateTime Instance',
        description: '',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 16),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        updatedAt: localTime,
        completedAt: localTime,
      );
      expect(inst.updatedAt.isUtc, isTrue);
      expect(inst.updatedAt, equals(localTime.toUtc()));
      expect(inst.completedAt!.isUtc, isTrue);
      expect(inst.completedAt, equals(localTime.toUtc()));

      final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final missingBoth = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Legacy Pending Instance',
      }, id: 'I-legacy-1');
      expect(missingBoth.updatedAt, equals(epoch));
    });

    test(
        'maps legacy dismissed status without statusReason to user_dismissed so isRevivableByCapacity is false',
        () {
      final inst = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Dismissed External Instance',
        'status': 'dismissed',
      }, id: 'I-ext-1');
      expect(inst.status, equals(TaskStatus.skipped));
      expect(
        inst.statusReason,
        equals(InstanceStatusReason.userDismissed.value),
      );
      expect(inst.isRevivableByCapacity, isFalse);
    });
  });
}
