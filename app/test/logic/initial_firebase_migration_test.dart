import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/initial_firebase_migration_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late HiveLocalDataSource localDataSource;
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
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Migration of pre-existing user tasks from Firestore', () async {
    await firestore.collection('users').doc('user1').set({'familyId': 'fam1'});

    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'User Task',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    await firestore
        .collection('users')
        .doc('user1')
        .collection('instances')
        .doc('I-1')
        .set({
          'id': 'I-1',
          'scheduleId': 'S-1',
          'title': 'User Instance',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    final service = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );

    expect(localDataSource.isMigrationCompleted(), false);

    await service.migrateIfNeeded();

    expect(localDataSource.isMigrationCompleted(), true);

    final tasks = localDataSource.getTasks();
    expect(tasks.length, 1);
    expect(tasks.first.id, 'S-1');

    final instances = localDataSource.getInstances();
    expect(instances.length, 1);
    expect(instances.first.id, 'I-1');
  });

  test('Migration does not run if migration_completed is true', () async {
    await firestore
        .collection('users')
        .doc('user1')
        .collection('tasks')
        .doc('S-1')
        .set({
          'id': 'S-1',
          'title': 'User Task',
          'updatedAt': DateTime.now().toIso8601String(),
        });

    await localDataSource.setMigrationCompleted(true);

    final service = InitialFirebaseMigrationService(
      firestore: firestore,
      localDataSource: localDataSource,
      userId: 'user1',
    );

    await service.migrateIfNeeded();

    final tasks = localDataSource.getTasks();
    expect(tasks.isEmpty, true); // Since migration was skipped
  });
}
