import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/unified_task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
  late TaskSyncService syncService;
  late UnifiedTaskRepository repository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');

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

    localDataSource = HiveLocalDataSource();
    await localDataSource.init();
    firestore = FakeFirebaseFirestore();

    syncService = TaskSyncService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
      isActivePremium: false,
    );

    repository = UnifiedTaskRepository(
      localDataSource: localDataSource,
      syncService: syncService,
      firestore: firestore,
      userId: 'user1',
    );
  });

  tearDown(() async {
    syncService.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('addTaskSchedule, getTasks, completeTaskInstance', () async {
    final task = TaskSchedule(
      id: 'S-1',
      title: 'Test Task',
      description: 'Desc 1',
      schedules: [],
      updatedAt: DateTime.now(),
    );

    await repository.addTaskSchedule(task);

    final tasksStream = repository.getTasks();
    final tasks = await tasksStream.first;
    expect(tasks.any((t) => t.id == 'S-1'), true);

    // Dirty flag should be set for sync
    final dirtyList = localDataSource.getDirtyTaskIds();
    expect(dirtyList.contains('S-1'), true);

    final instance = TaskInstance(
      id: 'I-1',
      scheduleId: 'S-1',
      ruleId: 'R-1',
      title: 'Test Instance',
      description: 'Desc 1',
      scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 17, minute: 0),
      ),
      updatedAt: DateTime.now(),
      status: 'pending',
    );
    await localDataSource.saveInstance(instance);

    await repository.completeTaskInstance('I-1');

    final insts = localDataSource.getInstances();
    final updatedInst = insts.firstWhere((i) => i.id == 'I-1');
    expect(updatedInst.status, 'completed');
  });

  test('deleteTaskSchedule and updateTaskSchedule', () async {
    final task = TaskSchedule(
      id: 'S-2',
      title: 'Delete Task',
      description: 'Desc 2',
      schedules: [],
      updatedAt: DateTime.now(),
    );
    await repository.addTaskSchedule(task);

    await repository.deleteTaskSchedule('S-2');

    final tasks = localDataSource.getTasks();
    expect(tasks.any((t) => t.id == 'S-2'), false);
  });
}
