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
  group('UserSettings Model Unit Tests', () {
    test(
      'default instantiation has 8.0 hoursAvailable and true for sort bar visibility',
      () {
        const settings = UserSettings(hoursAvailable: 8.0);
        expect(settings.hoursAvailable, 8.0);
        expect(settings.showLastSpawnedDate, isFalse);
        expect(settings.showTaskListSortBar, isTrue);
        expect(settings.showScheduleListSortBar, isTrue);
        expect(settings.crashReportingEnabled, isTrue);
      },
    );

    test('fromJson handles empty JSON by falling back to defaults', () {
      final settings = UserSettings.fromJson(const {});
      expect(settings.hoursAvailable, 8.0);
      expect(settings.showLastSpawnedDate, isFalse);
      expect(settings.showTaskListSortBar, isTrue);
      expect(settings.showScheduleListSortBar, isTrue);
      expect(settings.crashReportingEnabled, isTrue);
    });

    test('fromJson handles valid JSON input including sort bar visibility', () {
      final settings = UserSettings.fromJson(const {
        'hoursAvailable': 12.5,
        'showLastSpawnedDate': true,
        'showTaskListSortBar': false,
        'showScheduleListSortBar': false,
        'taskListSort': [
          {'column': 'priority', 'ascending': false},
        ],
        'scheduleListSort': [
          {'column': 'next_due', 'ascending': true},
        ],
      });
      expect(settings.hoursAvailable, 12.5);
      expect(settings.showLastSpawnedDate, isTrue);
      expect(settings.showTaskListSortBar, isFalse);
      expect(settings.showScheduleListSortBar, isFalse);
      expect(settings.taskListSort, const [
        (column: 'priority', ascending: false),
      ]);
      expect(settings.scheduleListSort, const [
        (column: 'next_due', ascending: true),
      ]);
    });

    test(
      'fromJson safely parses raw Map<dynamic, dynamic> nested maps from Hive Web',
      () {
        final Map<dynamic, dynamic> rawDynamicMap = <dynamic, dynamic>{
          'hoursAvailable': 10.0,
          'taskListSort': <dynamic>[
            <dynamic, dynamic>{'column': 'priority', 'ascending': false},
          ],
          'scheduleListSort': <dynamic>[
            <dynamic, dynamic>{'column': 'next_due', 'ascending': true},
          ],
          'defaultDailyCapacity': <dynamic, dynamic>{'1': 8.0},
          'dailyCapacityOverrides': <dynamic, dynamic>{'2026-08-05': 6.0},
        };

        final settings = UserSettings.fromJson(
          Map<String, dynamic>.from(rawDynamicMap),
        );
        expect(settings.hoursAvailable, 10.0);
        expect(settings.taskListSort, const [
          (column: 'priority', ascending: false),
        ]);
        expect(settings.scheduleListSort, const [
          (column: 'next_due', ascending: true),
        ]);
        expect(settings.defaultDailyCapacity, {'1': 8.0});
        expect(settings.dailyCapacityOverrides, {'2026-08-05': 6.0});
      },
    );

    test('toJson serializes correctly including sort bar visibility', () {
      const settings = UserSettings(
        hoursAvailable: 6.0,
        showLastSpawnedDate: true,
        showTaskListSortBar: false,
        showScheduleListSortBar: true,
        telemetryEnabled: true,
        crashReportingEnabled: true,
        taskListSort: [(column: 'priority', ascending: false)],
        scheduleListSort: [(column: 'next_due', ascending: true)],
      );
      expect(settings.toJson(), {
        'hoursAvailable': 6.0,
        'showLastSpawnedDate': true,
        'taskListSort': [
          {'column': 'priority', 'ascending': false},
        ],
        'scheduleListSort': [
          {'column': 'next_due', 'ascending': true},
        ],
        'showTaskListSortBar': false,
        'showScheduleListSortBar': true,
        'telemetryEnabled': true,
        'crashReportingEnabled': true,
      });
    });

    test('copyWith updates value correctly', () {
      const settings = UserSettings(
        hoursAvailable: 8.0,
        showLastSpawnedDate: false,
      );
      final updated = settings.copyWith(
        hoursAvailable: 4.5,
        showLastSpawnedDate: true,
        taskListSort: const [(column: 'priority', ascending: false)],
        scheduleListSort: const [(column: 'next_due', ascending: true)],
      );
      expect(updated.hoursAvailable, 4.5);
      expect(updated.showLastSpawnedDate, isTrue);
      expect(updated.taskListSort, const [
        (column: 'priority', ascending: false),
      ]);
      expect(updated.scheduleListSort, const [
        (column: 'next_due', ascending: true),
      ]);

      final copyOfSame = updated.copyWith();
      expect(copyOfSame.hoursAvailable, 4.5);
      expect(copyOfSame.showLastSpawnedDate, isTrue);
      expect(copyOfSame.taskListSort, const [
        (column: 'priority', ascending: false),
      ]);
      expect(copyOfSame.scheduleListSort, const [
        (column: 'next_due', ascending: true),
      ]);
    });

    test('equality and hashCode work as expected', () {
      const s1 = UserSettings(
        hoursAvailable: 5.0,
        showLastSpawnedDate: true,
        taskListSort: [(column: 'priority', ascending: false)],
      );
      const s2 = UserSettings(
        hoursAvailable: 5.0,
        showLastSpawnedDate: true,
        taskListSort: [(column: 'priority', ascending: false)],
      );
      const s3 = UserSettings(
        hoursAvailable: 6.0,
        showLastSpawnedDate: true,
        taskListSort: [(column: 'priority', ascending: false)],
      );
      const s4 = UserSettings(
        hoursAvailable: 5.0,
        showLastSpawnedDate: false,
        taskListSort: [(column: 'priority', ascending: false)],
      );
      const s5 = UserSettings(
        hoursAvailable: 5.0,
        showLastSpawnedDate: true,
        taskListSort: [(column: 'title', ascending: true)],
      );

      expect(s1, s2);
      expect(s1.hashCode, s2.hashCode);
      expect(s1, isNot(s3));
      expect(s1, isNot(s4));
      expect(s1, isNot(s5));
    });

    test(
      'dailyCapacityOverrides automatically prunes entries older than 90 days',
      () {
        // Mock clock time
        AppClock.setMockTime(
          DateTime(2026, 7, 10),
        ); // cutoff is 90 days ago: 2026-04-11
        addTearDown(AppClock.reset);

        final input = {
          'hoursAvailable': 8.0,
          'dailyCapacityOverrides': {
            '2026-07-10': 4.0, // Today: keep
            '2026-07-09': 5.0, // Yesterday: keep
            '2026-04-12': 6.0, // 89 days ago: keep
            '2026-04-11': 7.0, // 90 days ago: keep
            '2026-04-10': 2.0, // 91 days ago: prune
            '2026-01-01': 1.0, // Long ago: prune
          },
        };

        // 1. Test fromJson pruning
        final settings = UserSettings.fromJson(input);
        expect(settings.dailyCapacityOverrides, {
          '2026-07-10': 4.0,
          '2026-07-09': 5.0,
          '2026-04-12': 6.0,
          '2026-04-11': 7.0,
        });

        // 2. Test toJson pruning
        // Let's create settings directly with old overrides (which can happen if constructor is called directly)
        final settingsUnpruned = UserSettings(
          hoursAvailable: 8.0,
          dailyCapacityOverrides: const {'2026-07-10': 4.0, '2026-04-10': 2.0},
        );
        expect(settingsUnpruned.toJson()['dailyCapacityOverrides'], {
          '2026-07-10': 4.0,
        });

        // 3. Test copyWith pruning
        final updated = settingsUnpruned.copyWith(
          dailyCapacityOverrides: {'2026-07-09': 5.0, '2026-01-01': 1.0},
        );
        expect(updated.dailyCapacityOverrides, {'2026-07-09': 5.0});
      },
    );
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
        localDataSource: localDataSource,
      );
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
  });
}
