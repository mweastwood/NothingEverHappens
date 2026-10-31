import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/missed_policy_runner.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
  late TaskSyncService syncService;
  late List<String> rescheduledTaskIds;
  late MissedPolicyRunner runner;

  setUp(() async {
    addTearDown(AppClock.reset);
    tempDir = await Directory.systemTemp.createTemp(
      'missed_policy_runner_test',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );
    firestore = FakeFirebaseFirestore();
    localDataSource = HiveLocalDataSource();
    await localDataSource.init();
    await localDataSource.setMigrationCompleted(true);
    syncService = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user-1',
      isActivePremium: true,
    );
    rescheduledTaskIds = [];
    runner = MissedPolicyRunner(
      localDataSource: localDataSource,
      syncService: syncService,
      userId: 'user-1',
      getFamilyId: () async => null,
      rescheduleTaskNotifications: (task) async {
        rescheduledTaskIds.add(task.id);
      },
    );
  });

  tearDown(() async {
    runner.dispose();
    syncService.dispose();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MissedPolicyRunner', () {
    test(
      'evaluates personal tasks, sweeps orphaned pending personal instances, and schedules next dynamic trigger',
      () async {
        final now = DateTime(2026, 9, 16, 8, 0);
        AppClock.setMockTime(now);
        const today = CivilDay(year: 2026, month: 9, day: 16);

        final task = TaskSchedule(
          id: 'S-personal',
          title: 'Morning Task',
          description: 'Desc',
          schedules: [
            OneOffSchedule(
              id: 'R-1',
              scheduleId: 'S-personal',
              date: today,
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
        final orphanPending = TaskInstance(
          id: 'I-orphan',
          scheduleId: 'S-deleted-schedule',
          ruleId: 'R-del',
          title: 'Orphan',
          description: 'Desc',
          scheduledDate: today,
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
          status: TaskStatus.pending,
          isFamily: false,
        );

        await localDataSource.saveTask(task);
        await localDataSource.saveInstance(orphanPending);

        var postProcessRan = false;
        await runner.triggerMissedPolicyProcessing(
          evaluateFamilyTasks: false,
          postProcess: () async {
            postProcessRan = true;
          },
        );

        expect(postProcessRan, isTrue);
        final instances = localDataSource.getInstances();
        expect(instances.any((i) => i.id == 'I-orphan'), isFalse);
        expect(instances.any((i) => i.scheduleId == 'S-personal'), isTrue);
        expect(rescheduledTaskIds, contains('S-personal'));
        expect(
          runner.scheduledTriggerTime,
          equals(DateTime(2026, 9, 16, 9, 0)),
        );
      },
    );

    test(
      'reconciles scope metadata on existing family task instances without evaluating family schedule locally',
      () async {
        final now = DateTime(2026, 9, 16, 8, 0);
        AppClock.setMockTime(now);
        const today = CivilDay(year: 2026, month: 9, day: 16);

        final familyTask = TaskSchedule(
          id: 'S-fam',
          title: 'Family Chore',
          description: 'Desc',
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.individual,
          schedules: [
            DailySchedule(
              id: 'R-fam',
              scheduleId: 'S-fam',
              startDate: today,
              interval: 1,
            ),
          ],
        );
        final staleScopeInst = TaskInstance(
          id: 'I-fam-1',
          scheduleId: 'S-fam',
          ruleId: 'R-fam',
          title: 'Family Chore',
          description: 'Desc',
          scheduledDate: today,
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
          isFamily: true,
          familyCompletionMode: FamilyCompletionMode.anyone,
        );

        await localDataSource.saveTask(familyTask);
        await localDataSource.saveInstance(staleScopeInst);

        await runner.triggerMissedPolicyProcessing(evaluateFamilyTasks: false);

        final updated = localDataSource.getInstances().singleWhere(
          (i) => i.id == 'I-fam-1',
        );
        expect(
          updated.familyCompletionMode,
          equals(FamilyCompletionMode.individual),
        );
        expect(rescheduledTaskIds, contains('S-fam'));
      },
    );

    test(
      'does not count family tasks assigned to another member against current user daily capacity',
      () async {
        final now = DateTime(2026, 9, 16, 10, 0);
        AppClock.setMockTime(now);
        const today = CivilDay(year: 2026, month: 9, day: 16);

        final otherMemberFamilyTask = TaskSchedule(
          id: 'S-fam-other',
          title: 'Other Member Family Task',
          description: '',
          isFamily: true,
          assignedUserId: 'user-2',
          estimatedDuration: const Duration(hours: 7),
          schedules: [
            DailySchedule(
              id: 'R-fam-other',
              scheduleId: 'S-fam-other',
              startDate: today,
              interval: 1,
            ),
          ],
        );
        final otherMemberFamilyInst = TaskInstance(
          id: 'I-fam-other-1',
          scheduleId: 'S-fam-other',
          ruleId: 'R-fam-other',
          title: 'Other Member Family Task',
          description: '',
          scheduledDate: today,
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
          isFamily: true,
          assignedUserId: 'user-2',
          status: TaskStatus.pending,
        );

        final myCapacityTask = TaskSchedule(
          id: 'S-my-cap',
          title: 'My 2h Capacity Task',
          description: '',
          isFamily: false,
          skipIfNoCapacity: true,
          estimatedDuration: const Duration(hours: 2),
          schedules: [
            DailySchedule(
              id: 'R-my-cap',
              scheduleId: 'S-my-cap',
              startDate: today,
              interval: 1,
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

        await localDataSource.saveTask(otherMemberFamilyTask);
        await localDataSource.saveInstance(otherMemberFamilyInst);
        await localDataSource.saveTask(myCapacityTask);

        await runner.triggerMissedPolicyProcessing(evaluateFamilyTasks: false);

        final myTodayInst = localDataSource.getInstances().singleWhere(
          (i) => i.scheduleId == 'S-my-cap' && i.scheduledDate == today,
        );
        expect(myTodayInst.status, equals(TaskStatus.pending));
      },
    );
  });
}
