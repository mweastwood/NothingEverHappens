import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveLocalDataSource localDataSource;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'user_settings_repository_test',
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
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UserSettingsRepository dailyCapacityOverrides deletion', () {
    late FakeFirebaseFirestore firestore;
    late UserSettingsRepository repository;
    const userId = 'test-user';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      localDataSource = HiveLocalDataSource();
      await localDataSource.init();
      repository = UserSettingsRepository(
        firestore: firestore,
        userId: userId,
        isActivePremium: true,
        localDataSource: localDataSource,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'removing a date key from dailyCapacityOverrides deletes the key from Firestore',
      () async {
        AppClock.setMockTime(DateTime(2026, 7, 10));
        addTearDown(AppClock.reset);

        await repository.updateSettings(
          const UserSettings(
            hoursAvailable: 8.0,
            dailyCapacityOverrides: {'2026-07-10': 3.0, '2026-07-11': 5.0},
          ),
        );

        var snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('agile')
            .get();
        expect(snapshot.data()?['dailyCapacityOverrides'], {
          '2026-07-10': 3.0,
          '2026-07-11': 5.0,
        });

        await repository.updateSettings(
          const UserSettings(
            hoursAvailable: 8.0,
            dailyCapacityOverrides: {'2026-07-11': 5.0},
          ),
        );

        snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('agile')
            .get();
        final overrides =
            snapshot.data()?['dailyCapacityOverrides'] as Map<String, dynamic>?;
        expect(overrides, isNotNull);
        expect(overrides!.containsKey('2026-07-10'), isFalse);
        expect(overrides, {'2026-07-11': 5.0});

        await repository.updateSettings(
          const UserSettings(hoursAvailable: 8.0, dailyCapacityOverrides: {}),
        );

        snapshot = await firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('agile')
            .get();
        final clearedOverrides =
            snapshot.data()?['dailyCapacityOverrides'] as Map<String, dynamic>?;
        expect(clearedOverrides, isEmpty);
      },
    );
  });
}
