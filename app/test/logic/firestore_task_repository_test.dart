import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/firestore_task_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  const userId = 'user-test-123';
  const familyId = 'family-test-456';
  final fixedClockTime = DateTime(2026, 6, 3, 12, 0);

  late FakeFirebaseFirestore firestore;
  late FirestoreTaskRepository repository;

  setUp(() {
    AppClock.setMockTime(fixedClockTime);
    firestore = FakeFirebaseFirestore();
    repository = FirestoreTaskRepository(firestore: firestore, userId: userId);
  });

  tearDown(() {
    repository.dispose();
    AppClock.reset();
  });

  TaskSchedule createTestTask({
    required String id,
    String title = 'Test Task',
    bool isFamily = false,
    List<TaskScheduleRule>? schedules,
  }) {
    return TaskSchedule(
      id: id,
      title: title,
      description: 'Test description for $title',
      schedules:
          schedules ??
          [
            OneOffSchedule(
              id: 'rule-1',
              date: const CivilDay(year: 2026, month: 6, day: 1),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 17,
                minute: 0,
              ),
            ),
          ],
      isFamily: isFamily,
    );
  }

  TaskInstance createTestInstance({
    required String id,
    required String scheduleId,
    String ruleId = 'rule-1',
    String title = 'Test Task Instance',
    TaskStatus status = TaskStatus.pending,
    bool isFamily = false,
    CivilDay? scheduledDate,
    DateTime? updatedAt,
  }) {
    return TaskInstance(
      id: id,
      scheduleId: scheduleId,
      ruleId: ruleId,
      title: title,
      description: 'Instance description',
      status: status,
      isFamily: isFamily,
      scheduledDate:
          scheduledDate ?? const CivilDay(year: 2026, month: 6, day: 1),
      startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
      dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      updatedAt: updatedAt ?? fixedClockTime,
    );
  }

  group('1. Firestore Stream Subscriptions', () {
    test('Personal-Only Streams: getTasks and getInstances emit matching '
        'documents when familyId is null or empty', () async {
      // Set user document without familyId (field omitted / null)
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
      });

      final personalTask = createTestTask(id: 'S-personal-1', isFamily: false);
      final personalInst = createTestInstance(
        id: 'I-personal-1',
        scheduleId: 'S-personal-1',
        isFamily: false,
      );

      await FirestoreCollections.userTasks(
        firestore,
        userId,
      ).doc(personalTask.id).set(personalTask);
      await FirestoreCollections.userInstances(
        firestore,
        userId,
      ).doc(personalInst.id).set(personalInst);

      final tasks = await repository.getTasks().first;
      expect(tasks.length, 1);
      expect(tasks.first.id, personalTask.id);
      expect(tasks.first.title, personalTask.title);

      final instances = await repository.getInstances().first;
      expect(instances.length, 1);
      expect(instances.first.id, personalInst.id);
      expect(instances.first.scheduleId, personalInst.scheduleId);

      // Also test explicitly setting familyId to null and empty string
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': null,
      });
      expect((await repository.getTasks().first).length, 1);
      expect((await repository.getInstances().first).length, 1);

      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': '',
      });
      expect((await repository.getTasks().first).length, 1);
      expect((await repository.getInstances().first).length, 1);
    });

    test('Family-Scoped Streams: getTasks and getInstances combine streams '
        'from personal and family collections', () async {
      // Configure user doc with familyId
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': familyId,
      });

      final personalTask = createTestTask(id: 'S-personal-1', isFamily: false);
      final familyTask = createTestTask(
        id: 'S-family-1',
        title: 'Family Task',
        isFamily: true,
      );

      final personalInst = createTestInstance(
        id: 'I-personal-1',
        scheduleId: 'S-personal-1',
        isFamily: false,
      );
      final familyInst = createTestInstance(
        id: 'I-family-1',
        scheduleId: 'S-family-1',
        title: 'Family Instance',
        isFamily: true,
      );

      await FirestoreCollections.userTasks(
        firestore,
        userId,
      ).doc(personalTask.id).set(personalTask);
      await FirestoreCollections.familyTasks(
        firestore,
        familyId,
      ).doc(familyTask.id).set(familyTask);

      await FirestoreCollections.userInstances(
        firestore,
        userId,
      ).doc(personalInst.id).set(personalInst);
      await FirestoreCollections.familyInstances(
        firestore,
        familyId,
      ).doc(familyInst.id).set(familyInst);

      final tasks = await repository.getTasks().first;
      expect(tasks.length, 2);
      expect(tasks.any((t) => t.id == personalTask.id), isTrue);
      expect(tasks.any((t) => t.id == familyTask.id), isTrue);

      final instances = await repository.getInstances().first;
      expect(instances.length, 2);
      expect(instances.any((i) => i.id == personalInst.id), isTrue);
      expect(instances.any((i) => i.id == familyInst.id), isTrue);
    });

    test('Dynamic Stream Re-subscription (Tasks): stream updates automatically '
        'when user familyId transitions', () async {
      // Initially personal only
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': '',
      });

      final personalTask = createTestTask(id: 'S-personal-1', isFamily: false);
      final familyTask = createTestTask(id: 'S-family-1', isFamily: true);

      await FirestoreCollections.userTasks(
        firestore,
        userId,
      ).doc(personalTask.id).set(personalTask);
      await FirestoreCollections.familyTasks(
        firestore,
        familyId,
      ).doc(familyTask.id).set(familyTask);

      final taskStream = repository.getTasks();
      final taskEmissions = <List<TaskSchedule>>[];
      final sub = taskStream.listen(taskEmissions.add);

      // Allow initial emission to propagate
      await pumpEventQueue();
      expect(taskEmissions.isNotEmpty, isTrue);
      expect(taskEmissions.last.length, 1);
      expect(taskEmissions.last.first.id, personalTask.id);

      // Transition: User joins family
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': familyId,
      });

      await pumpEventQueue();
      expect(taskEmissions.last.length, 2);
      expect(taskEmissions.last.any((t) => t.id == familyTask.id), isTrue);

      // Transition: User leaves family
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': '',
      });

      await pumpEventQueue();
      expect(taskEmissions.last.length, 1);
      expect(taskEmissions.last.first.id, personalTask.id);

      await sub.cancel();
    });

    test('Dynamic Stream Re-subscription (Instances): getInstances stream '
        'updates automatically when user familyId transitions', () async {
      // Initially personal only
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': '',
      });

      final personalInst = createTestInstance(
        id: 'I-personal-dyn-1',
        scheduleId: 'S-personal-dyn-1',
        isFamily: false,
      );
      final familyInst = createTestInstance(
        id: 'I-family-dyn-1',
        scheduleId: 'S-family-dyn-1',
        title: 'Family Instance Dynamic',
        isFamily: true,
      );

      await FirestoreCollections.userInstances(
        firestore,
        userId,
      ).doc(personalInst.id).set(personalInst);
      await FirestoreCollections.familyInstances(
        firestore,
        familyId,
      ).doc(familyInst.id).set(familyInst);

      final instanceStream = repository.getInstances();
      final instanceEmissions = <List<TaskInstance>>[];
      final sub = instanceStream.listen(instanceEmissions.add);

      // Allow initial emission to propagate
      await pumpEventQueue();
      expect(instanceEmissions.isNotEmpty, isTrue);
      expect(instanceEmissions.last.length, 1);
      expect(instanceEmissions.last.first.id, personalInst.id);

      // Transition: User joins family
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': familyId,
      });

      await pumpEventQueue();
      expect(instanceEmissions.last.length, 2);
      expect(instanceEmissions.last.any((i) => i.id == familyInst.id), isTrue);

      // Transition: User leaves family
      await firestore.collection(FirestorePaths.users).doc(userId).set({
        'displayName': 'Test User',
        'familyId': '',
      });

      await pumpEventQueue();
      expect(instanceEmissions.last.length, 1);
      expect(instanceEmissions.last.first.id, personalInst.id);

      await sub.cancel();
    });
  });

  group('2. Missed Policy Queue Processing', () {
    test(
      'Single Invocation: processes tasks, updates task caches, and executes '
      'pending missed policy logic',
      () async {
        final task = createTestTask(
          id: 'S-task-single',
          title: 'Overdue Task',
          schedules: [
            OneOffSchedule(
              id: 'rule-single',
              date: const CivilDay(year: 2026, month: 6, day: 1),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 17,
                minute: 0,
              ),
            ),
          ],
        );

        // Persist task in Firestore so _doProcessMissedPolicies reads it
        await FirestoreCollections.userTasks(
          firestore,
          userId,
        ).doc(task.id).set(task);

        await repository.checkAndProcessMissedPolicies([task]);

        // Verify task cache was updated
        expect(repository.cachedTasksMap.containsKey(task.id), isTrue);
        expect(repository.cachedTasksMap[task.id]?.title, 'Overdue Task');

        // Verify instances were spawned in Firestore by SchedulerEngine
        // evaluation
        final instancesSnap = await FirestoreCollections.userInstances(
          firestore,
          userId,
        ).get();
        expect(instancesSnap.docs.isNotEmpty, isTrue);
        expect(
          instancesSnap.docs.any((d) => d.data().scheduleId == task.id),
          isTrue,
        );
      },
    );

    test(
      'Deduplication & Concurrency: concurrent or rapid successive calls '
      'deduplicate task IDs in _queuedTasksMap without race conditions',
      () async {
        final task = createTestTask(
          id: 'S-task-dedup',
          title: 'Concurrent Task',
          schedules: [
            OneOffSchedule(
              id: 'rule-dedup',
              date: const CivilDay(year: 2026, month: 6, day: 2),
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 9,
                minute: 0,
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                hour: 17,
                minute: 0,
              ),
            ),
          ],
        );

        await FirestoreCollections.userTasks(
          firestore,
          userId,
        ).doc(task.id).set(task);

        // Rapid concurrent invocations
        final futures = List.generate(
          5,
          (_) => repository.checkAndProcessMissedPolicies([task]),
        );
        await Future.wait(futures);

        // Verify task map contains the task and queue was completely drained
        expect(repository.cachedTasksMap.containsKey(task.id), isTrue);
        expect(repository.queuedTasksMap.isEmpty, isTrue);

        // Verify no duplicate instances were spawned in Firestore
        final instancesSnap = await FirestoreCollections.userInstances(
          firestore,
          userId,
        ).get();
        final spawnedForTask = instancesSnap.docs
            .where((d) => d.data().scheduleId == task.id)
            .toList();
        expect(spawnedForTask.length, 1);
      },
    );

    test(
      'Post-Processing Callbacks: executes postProcess callbacks sequentially '
      'following queue completion',
      () async {
        final task = createTestTask(id: 'S-task-callback');
        await FirestoreCollections.userTasks(
          firestore,
          userId,
        ).doc(task.id).set(task);

        final executionOrder = <int>[];

        final future1 = repository.checkAndProcessMissedPolicies(
          [task],
          postProcess: () async {
            executionOrder.add(1);
          },
        );

        final future2 = repository.checkAndProcessMissedPolicies(
          [task],
          postProcess: () async {
            executionOrder.add(2);
          },
        );

        final future3 = repository.checkAndProcessMissedPolicies(
          [task],
          postProcess: () async {
            executionOrder.add(3);
          },
        );

        await Future.wait([future1, future2, future3]);

        expect(executionOrder, [1, 2, 3]);
      },
    );
  });

  group('3. Orphaned Instance Cleanup', () {
    test(
      'Orphan Detection & Deletion: deletes pending instances whose scheduleId '
      'does not match any active task in taskMap',
      () async {
        final orphanInst = createTestInstance(
          id: 'I-orphan-1',
          scheduleId: 'S-deleted-task',
          status: TaskStatus.pending,
          isFamily: false,
        );

        // Save orphan in Firestore
        await FirestoreCollections.userInstances(
          firestore,
          userId,
        ).doc(orphanInst.id).set(orphanInst);

        // Pre-populate spawnedInstancesCache with this orphan instance
        final cacheKey =
            '${orphanInst.scheduleId}:${orphanInst.ruleId}:'
            '${orphanInst.scheduledDate}';
        repository.spawnedInstancesCache[cacheKey] = fixedClockTime;

        final batch = firestore.batch();
        final instancesById = <String, TaskInstance>{orphanInst.id: orphanInst};
        final instancesByScheduleId = <String, List<TaskInstance>>{
          orphanInst.scheduleId: [orphanInst],
        };
        final deletedInstanceIds = <String>{};
        final taskMap = <String, TaskSchedule>{}; // Active taskMap is empty

        final hasChanges = repository.sweepOrphanedPendingInstances(
          batch,
          instancesById,
          instancesByScheduleId,
          deletedInstanceIds,
          taskMap,
          null,
        );

        await batch.commit();

        expect(hasChanges, isTrue);
        expect(repository.spawnedInstancesCache.containsKey(cacheKey), isFalse);
        expect(deletedInstanceIds.contains(orphanInst.id), isTrue);
        expect(instancesById.containsKey(orphanInst.id), isFalse);
        expect(
          instancesByScheduleId[orphanInst.scheduleId]?.isEmpty ?? true,
          isTrue,
        );

        final docSnap = await FirestoreCollections.userInstances(
          firestore,
          userId,
        ).doc(orphanInst.id).get();
        expect(docSnap.exists, isFalse);
      },
    );

    test(
      'Non-Orphan Preservation: preserves instances attached to active tasks, '
      'completed/skipped instances, and family-scoped instances',
      () async {
        final activeTask = createTestTask(id: 'S-active-task');
        final taskMap = <String, TaskSchedule>{activeTask.id: activeTask};

        final activePendingInst = createTestInstance(
          id: 'I-active-pending',
          scheduleId: activeTask.id,
          status: TaskStatus.pending,
          isFamily: false,
        );

        final completedOrphanInst = createTestInstance(
          id: 'I-completed-orphan',
          scheduleId: 'S-missing-task-1',
          status: TaskStatus.completed,
          isFamily: false,
        );

        final skippedOrphanInst = createTestInstance(
          id: 'I-skipped-orphan',
          scheduleId: 'S-missing-task-2',
          status: TaskStatus.skipped,
          isFamily: false,
        );

        final familyPendingOrphanInst = createTestInstance(
          id: 'I-family-orphan',
          scheduleId: 'S-missing-task-3',
          status: TaskStatus.pending,
          isFamily: true,
        );

        final instancesList = [
          activePendingInst,
          completedOrphanInst,
          skippedOrphanInst,
          familyPendingOrphanInst,
        ];

        for (final inst in instancesList) {
          if (inst.isFamily) {
            await FirestoreCollections.familyInstances(
              firestore,
              familyId,
            ).doc(inst.id).set(inst);
          } else {
            await FirestoreCollections.userInstances(
              firestore,
              userId,
            ).doc(inst.id).set(inst);
          }
        }

        final batch = firestore.batch();
        final instancesById = {for (final inst in instancesList) inst.id: inst};
        final instancesByScheduleId = <String, List<TaskInstance>>{};
        for (final inst in instancesList) {
          instancesByScheduleId
              .putIfAbsent(inst.scheduleId, () => [])
              .add(inst);
        }
        final deletedInstanceIds = <String>{};

        final hasChanges = repository.sweepOrphanedPendingInstances(
          batch,
          instancesById,
          instancesByScheduleId,
          deletedInstanceIds,
          taskMap,
          familyId,
        );

        await batch.commit();

        expect(hasChanges, isFalse);
        expect(deletedInstanceIds.isEmpty, isTrue);
        expect(instancesById.length, 4);

        for (final inst in instancesList) {
          final docRef = inst.isFamily
              ? FirestoreCollections.familyInstances(
                  firestore,
                  familyId,
                ).doc(inst.id)
              : FirestoreCollections.userInstances(
                  firestore,
                  userId,
                ).doc(inst.id);
          final docSnap = await docRef.get();
          expect(docSnap.exists, isTrue);
        }
      },
    );
  });

  group('4. Virtual Instance Expiration', () {
    test('Virtual Instance Injection: caches recently spawned instance and '
        'injects virtual TaskInstance within 2 seconds', () {
      final task = createTestTask(id: 'S-virtual-task');
      const ruleId = 'rule-1';
      final targetDate = const CivilDay(year: 2026, month: 6, day: 3);

      final cacheKey = '${task.id}:$ruleId:${targetDate.toString()}';
      repository.spawnedInstancesCache[cacheKey] = fixedClockTime.subtract(
        const Duration(milliseconds: 500),
      );

      final taskInstances = <TaskInstance>[];
      repository.injectVirtualSpawnedInstances(
        task,
        taskInstances,
        fixedClockTime,
      );

      expect(taskInstances.length, 1);
      final virtualInst = taskInstances.first;
      expect(virtualInst.id.startsWith('VIRTUAL-'), isTrue);
      expect(virtualInst.scheduleId, task.id);
      expect(virtualInst.ruleId, ruleId);
      expect(virtualInst.scheduledDate, targetDate);
      expect(virtualInst.status, TaskStatus.pending);

      // Cache entry remains valid (within 2 seconds)
      expect(repository.spawnedInstancesCache.containsKey(cacheKey), isTrue);
    });

    test(
      'Cache Expiration: purges expired entries after 2 seconds and does not '
      'inject virtual instances',
      () {
        final task = createTestTask(id: 'S-expired-task');
        const ruleId = 'rule-1';
        final targetDate = const CivilDay(year: 2026, month: 6, day: 3);

        final cacheKey = '${task.id}:$ruleId:${targetDate.toString()}';
        repository.spawnedInstancesCache[cacheKey] = fixedClockTime.subtract(
          const Duration(seconds: 3),
        );

        final taskInstances = <TaskInstance>[];
        repository.injectVirtualSpawnedInstances(
          task,
          taskInstances,
          fixedClockTime,
        );

        expect(taskInstances.isEmpty, isTrue);
        expect(repository.spawnedInstancesCache.containsKey(cacheKey), isFalse);
      },
    );

    test(
      'Does not inject virtual instance if instance with matching ruleId and '
      'date already exists',
      () {
        final task = createTestTask(id: 'S-existing-task');
        const ruleId = 'rule-1';
        final targetDate = const CivilDay(year: 2026, month: 6, day: 3);

        final cacheKey = '${task.id}:$ruleId:${targetDate.toString()}';
        repository.spawnedInstancesCache[cacheKey] = fixedClockTime.subtract(
          const Duration(milliseconds: 500),
        );

        final existingInstance = createTestInstance(
          id: 'I-existing-1',
          scheduleId: task.id,
          ruleId: ruleId,
          scheduledDate: targetDate,
        );

        final taskInstances = <TaskInstance>[existingInstance];
        repository.injectVirtualSpawnedInstances(
          task,
          taskInstances,
          fixedClockTime,
        );

        // Should not add duplicate virtual instance
        expect(taskInstances.length, 1);
        expect(taskInstances.first.id, 'I-existing-1');
      },
    );
  });
}
