import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/telemetry_service.dart';
import 'package:nothing_ever_happens/logic/crashlytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveLocalDataSource localDataSource;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('user_settings_test');
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

  group('UserSettingsRepository Unit Tests', () {
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
      'getSettings returns default 8.0 hoursAvailable when document does not exist',
      () async {
        final settings = await repository.getSettings().first;
        expect(settings.hoursAvailable, 8.0);
      },
    );

    test('getSettings returns stored settings when saved', () async {
      await repository.updateSettings(const UserSettings(hoursAvailable: 10.0));

      final settings = await repository.getSettings().first;
      expect(settings.hoursAvailable, 10.0);
    });

    test('updateSettings creates or updates settings in Firestore', () async {
      const updated = UserSettings(
        hoursAvailable: 15.0,
        showLastSpawnedDate: true,
      );
      await repository.updateSettings(updated);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), {
        'hoursAvailable': 15.0,
        'showLastSpawnedDate': true,
        'firstDayOfWeek': 'sunday',
        'showTaskListSortBar': true,
        'showScheduleListSortBar': true,
        'telemetryEnabled': true,
        'crashReportingEnabled': true,
      });

      final settingsFromRepository = await repository.getSettings().first;
      expect(settingsFromRepository.hoursAvailable, 15.0);
      expect(settingsFromRepository.showLastSpawnedDate, isTrue);
      expect(settingsFromRepository.telemetryEnabled, isTrue);
      expect(settingsFromRepository.crashReportingEnabled, isTrue);
    });

    test(
      'updateSettings synchronizes telemetry enabled state to TelemetryService',
      () async {
        final fakeTelemetry = NoOpTelemetryService(enabled: true);
        final repoWithTelemetry = UserSettingsRepository(
          firestore: firestore,
          userId: userId,
          localDataSource: localDataSource,
          telemetryService: fakeTelemetry,
        );

        expect(fakeTelemetry.isEnabled, isTrue);

        await repoWithTelemetry.updateSettings(
          const UserSettings(hoursAvailable: 8.0, telemetryEnabled: false),
        );

        expect(fakeTelemetry.isEnabled, isFalse);
      },
    );

    test(
      'updateSettings synchronizes crash reporting enabled state to CrashlyticsService',
      () async {
        final fakeCrashlytics = NoOpCrashlyticsService(enabled: true);
        final repoWithCrashlytics = UserSettingsRepository(
          firestore: firestore,
          userId: userId,
          localDataSource: localDataSource,
          crashlyticsService: fakeCrashlytics,
        );

        expect(fakeCrashlytics.isEnabled, isTrue);

        await repoWithCrashlytics.updateSettings(
          const UserSettings(hoursAvailable: 8.0, crashReportingEnabled: false),
        );

        expect(fakeCrashlytics.isEnabled, isFalse);
      },
    );

    test(
      'remote Firestore settings snapshot updates local Hive storage when subscribed',
      () async {
        AppClock.setMockTime(DateTime(2026, 7, 10));
        addTearDown(AppClock.reset);

        await firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('agile')
            .set({
              'hoursAvailable': 6.0,
              'defaultDailyCapacity': {'1': 4.0, '2': 5.0},
              'dailyCapacityOverrides': {'2026-07-10': 3.0},
            });

        final current = await localDataSource.watchSettings().firstWhere(
          (settings) =>
              settings.hoursAvailable == 6.0 &&
              (settings.dailyCapacityOverrides?.containsKey('2026-07-10') ??
                  false),
        );
        expect(current.hoursAvailable, 6.0);
        expect(current.defaultDailyCapacity, {'1': 4.0, '2': 5.0});
        expect(current.dailyCapacityOverrides, {'2026-07-10': 3.0});
      },
    );

    test(
      'updateSettings removes deleted dailyCapacityOverrides date keys in Firestore',
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
      },
    );
  });
}
