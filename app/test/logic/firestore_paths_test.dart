import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('FirestorePaths constants', () {
    test('defines all collection path names correctly', () {
      expect(FirestorePaths.users, equals('users'));
      expect(FirestorePaths.families, equals('families'));
      expect(FirestorePaths.tasks, equals('tasks'));
      expect(FirestorePaths.instances, equals('instances'));
      expect(FirestorePaths.settings, equals('settings'));
      expect(FirestorePaths.history, equals('history'));
      expect(FirestorePaths.invites, equals('invites'));
      expect(FirestorePaths.recipes, equals('recipes'));
    });
  });

  group('FirestoreCollections helpers', () {
    final testTask = TaskSchedule(
      id: 'S-test-1',
      title: 'Clean Room',
      description: 'Vacuum and dust',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2026, month: 1, day: 1),
          interval: 1,
        ),
      ],
    );

    final testInstance = TaskInstance(
      id: 'I-test-1',
      scheduleId: 'S-test-1',
      ruleId: 'R-daily-1',
      scheduledDate: const CivilDay(year: 2026, month: 1, day: 1),
      title: 'Clean Room',
      description: 'Vacuum and dust',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
    );

    test(
      'userTasks provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.userTasks(
          fakeFirestore,
          'user123',
        );
        expect(collection.path, equals('users/user123/tasks'));

        await collection.doc(testTask.id).set(testTask);

        final snap = await collection.doc(testTask.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('S-test-1'));
        expect(snap.data()!.title, equals('Clean Room'));
      },
    );

    test(
      'familyTasks provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.familyTasks(
          fakeFirestore,
          'fam456',
        );
        expect(collection.path, equals('families/fam456/tasks'));

        await collection.doc(testTask.id).set(testTask);

        final snap = await collection.doc(testTask.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('S-test-1'));
        expect(snap.data()!.title, equals('Clean Room'));
      },
    );

    test(
      'userInstances provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.userInstances(
          fakeFirestore,
          'user123',
        );
        expect(collection.path, equals('users/user123/instances'));

        await collection.doc(testInstance.id).set(testInstance);

        final snap = await collection.doc(testInstance.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('I-test-1'));
        expect(snap.data()!.title, equals('Clean Room'));
      },
    );

    test(
      'familyInstances provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.familyInstances(
          fakeFirestore,
          'fam456',
        );
        expect(collection.path, equals('families/fam456/instances'));

        await collection.doc(testInstance.id).set(testInstance);

        final snap = await collection.doc(testInstance.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('I-test-1'));
        expect(snap.data()!.title, equals('Clean Room'));
      },
    );
  });
}
