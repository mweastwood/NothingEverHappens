import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_priority.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('TaskInstance Serialization and Helpers', () {
    const testDate = CivilDay(year: 2026, month: 6, day: 13);
    const testStart = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 9, minute: 0),
    );
    const testDue = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 17, minute: 0),
    );
    const testNotification = RelativeTime(
      dayOffset: 0,
      time: TimeOfDay(hour: 8, minute: 30),
    );

    test('Constructor initializes all fields correctly', () {
      final completedAt = DateTime(2026, 6, 13, 10, 0);
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
    });

    test('toFirestore serializes fields correctly', () {
      final completedAt = DateTime(2026, 6, 13, 10, 0);
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
    });

    test('fromFirestore deserializes data correctly', () async {
      final firestore = FakeFirebaseFirestore();
      final ref = firestore.collection('instances').doc('instance-123');
      final completedAt = DateTime(2026, 6, 13, 10, 0);

      await ref.set({
        'scheduleId': 'schedule-456',
        'ruleId': 'rule-456',
        'title': 'Task Occurrence',
        'description': 'Do the laundry',
        'scheduledDate': testDate.toJson(),
        'startRelativeTime': testStart.toJson(),
        'dueRelativeTime': testDue.toJson(),
        'notificationRelativeTime': testNotification.toJson(),
        'isFamily': true,
        'priority': 'high',
        'cycleId': 'cycle-789',
        'assignedUserId': 'user-abc',
        'completedByUserId': 'user-xyz',
        'completedAt': Timestamp.fromDate(completedAt),
        'status': 'completed',
      });

      final snapshot = await ref.get();
      final instance = TaskInstance.fromFirestore(snapshot);

      expect(instance.id, 'instance-123');
      expect(instance.scheduleId, 'schedule-456');
      expect(instance.ruleId, 'rule-456');
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
    });

    test(
      'fromFirestore deserializes multiple notifications list correctly',
      () async {
        final firestore = FakeFirebaseFirestore();
        final ref = firestore.collection('instances').doc('instance-multi');
        final notif1 = const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 8, minute: 0),
        );
        final notif2 = const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 12, minute: 0),
        );

        await ref.set({
          'scheduleId': 'schedule-456',
          'ruleId': 'rule-456',
          'title': 'Task Occurrence',
          'description': 'Do the laundry',
          'scheduledDate': testDate.toJson(),
          'startRelativeTime': testStart.toJson(),
          'dueRelativeTime': testDue.toJson(),
          'notificationRelativeTimes': [notif1.toJson(), notif2.toJson()],
          'isFamily': true,
          'priority': 'high',
          'cycleId': 'cycle-789',
          'assignedUserId': 'user-abc',
          'status': 'pending',
        });

        final snapshot = await ref.get();
        final instance = TaskInstance.fromFirestore(snapshot);

        expect(instance.notificationRelativeTimes.length, 2);
        expect(instance.notificationRelativeTimes[0], notif1);
        expect(instance.notificationRelativeTimes[1], notif2);
      },
    );

    test('deserializes completedAt from various formats', () async {
      final firestore = FakeFirebaseFirestore();
      final ref1 = firestore.collection('instances').doc('inst-string');
      final ref2 = firestore.collection('instances').doc('inst-int');
      final completedAt = DateTime(2026, 6, 13, 10, 0);

      await ref1.set({'completedAt': completedAt.toIso8601String()});
      await ref2.set({'completedAt': completedAt.millisecondsSinceEpoch});

      final snap1 = await ref1.get();
      final snap2 = await ref2.get();

      final inst1 = TaskInstance.fromFirestore(snap1);
      final inst2 = TaskInstance.fromFirestore(snap2);

      expect(inst1.completedAt, completedAt);
      expect(inst2.completedAt, completedAt);
    });

    test('copyWith copies and overrides fields correctly', () {
      final completedAt = DateTime(2026, 6, 13, 10, 0);
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
      );

      final updated = instance.copyWith(
        title: 'New Title',
        description: 'New Desc',
        scheduledDate: const CivilDay(year: 2026, month: 6, day: 14),
        startRelativeTime: const RelativeTime(
          dayOffset: 1,
          time: TimeOfDay(hour: 10, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 1,
          time: TimeOfDay(hour: 18, minute: 0),
        ),
        clearNotificationRelativeTimes: true,
        isFamily: true,
        priority: TaskPriority.high,
        clearCycleId: true,
        clearAssignedUserId: true,
        clearCompletedByUserId: true,
        clearCompletedAt: true,
        status: TaskStatus.completed,
      );

      expect(updated.id, 'instance-123');
      expect(updated.scheduleId, 'schedule-456');
      expect(updated.ruleId, 'rule-456');
      expect(updated.title, 'New Title');
      expect(updated.description, 'New Desc');
      expect(
        updated.scheduledDate,
        const CivilDay(year: 2026, month: 6, day: 14),
      );
      expect(
        updated.startRelativeTime,
        const RelativeTime(dayOffset: 1, time: TimeOfDay(hour: 10, minute: 0)),
      );
      expect(
        updated.dueRelativeTime,
        const RelativeTime(dayOffset: 1, time: TimeOfDay(hour: 18, minute: 0)),
      );
      expect(updated.notificationRelativeTimes, isEmpty);
      expect(updated.isFamily, true);
      expect(updated.priority, TaskPriority.high);
      expect(updated.cycleId, isNull);
      expect(updated.assignedUserId, isNull);
      expect(updated.completedByUserId, isNull);
      expect(updated.completedAt, isNull);
      expect(updated.status, TaskStatus.completed);
    });

    test(
      'deserializes updatedAt from various formats and defaults when null',
      () async {
        final firestore = FakeFirebaseFirestore();
        final refTimestamp = firestore.collection('instances').doc('inst-ts');
        final refString = firestore.collection('instances').doc('inst-str');
        final refInt = firestore.collection('instances').doc('inst-int');
        final refNull = firestore.collection('instances').doc('inst-null');

        final time = DateTime(2026, 8, 16, 12, 0);

        await refTimestamp.set({'updatedAt': Timestamp.fromDate(time)});
        await refString.set({'updatedAt': time.toIso8601String()});
        await refInt.set({'updatedAt': time.millisecondsSinceEpoch});
        await refNull.set({'title': 'No updatedAt'});

        final snapTs = await refTimestamp.get();
        final snapStr = await refString.get();
        final snapInt = await refInt.get();
        final snapNull = await refNull.get();

        final instTs = TaskInstance.fromFirestore(snapTs);
        final instStr = TaskInstance.fromFirestore(snapStr);
        final instInt = TaskInstance.fromFirestore(snapInt);
        final instNull = TaskInstance.fromFirestore(snapNull);

        expect(instTs.updatedAt, time);
        expect(instStr.updatedAt, time);
        expect(instInt.updatedAt, time);
        expect(instNull.updatedAt, isNotNull);

        final toFirestoreMap = instNull.toFirestore();
        expect(toFirestoreMap['updatedAt'], isNotNull);
      },
    );

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
      },
    );

    test(
      'isCompletedForUser returns correct status based on completion mode',
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
        expect(anyoneInstance.isCompletedForUser('user2'), isFalse);

        final completedAnyone = anyoneInstance.copyWith(
          status: TaskStatus.completed,
        );
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

        final fullyCompletedIndividual = individualInstance.copyWith(
          completedByUserIds: const ['user1', 'user2'],
          status: TaskStatus.completed,
        );
        expect(fullyCompletedIndividual.isCompletedForUser('user1'), isTrue);
        expect(fullyCompletedIndividual.isCompletedForUser('user2'), isTrue);
        expect(fullyCompletedIndividual.isCompletedForUser('user3'), isFalse);
      },
    );

    test(
      'toFirestore and fromFirestore serialize and deserialize familyCompletionMode and completedByUserIds',
      () async {
        final firestore = FakeFirebaseFirestore();
        final ref = firestore.collection('instances').doc('inst-individual');

        final instance = TaskInstance(
          id: 'inst-individual',
          scheduleId: 's-123',
          ruleId: 'r-123',
          title: 'Individual Family Task',
          description: 'Test description',
          scheduledDate: testDate,
          startRelativeTime: testStart,
          dueRelativeTime: testDue,
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          completedByUserIds: ['userA', 'userB'],
        );

        final data = instance.toFirestore();
        expect(data['familyCompletionMode'], 'individual');
        expect(data['completedByUserIds'], ['userA', 'userB']);

        await ref.set(data);
        final snapshot = await ref.get();
        final loaded = TaskInstance.fromFirestore(snapshot);

        expect(loaded.id, 'inst-individual');
        expect(loaded.isFamily, isTrue);
        expect(loaded.familyCompletionMode, FamilyCompletionMode.individual);
        expect(loaded.completedByUserIds, ['userA', 'userB']);
      },
    );

    test('copyWith handles familyCompletionMode and completedByUserIds', () {
      final instance = TaskInstance(
        scheduleId: 's-1',
        ruleId: 'r-1',
        title: 'Test',
        description: '',
        scheduledDate: testDate,
        startRelativeTime: testStart,
        dueRelativeTime: testDue,
        isFamily: true,
        familyCompletionMode: FamilyCompletionMode.anyone,
        completedByUserIds: ['u1'],
      );

      final updated = instance.copyWith(
        familyCompletionMode: FamilyCompletionMode.individual,
        completedByUserIds: ['u1', 'u2'],
      );
      expect(updated.familyCompletionMode, FamilyCompletionMode.individual);
      expect(updated.completedByUserIds, ['u1', 'u2']);

      final cleared = updated.copyWith(clearCompletedByUserIds: true);
      expect(cleared.completedByUserIds, isEmpty);
    });
  });
}
