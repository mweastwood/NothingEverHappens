import 'dart:ui';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/crashlytics_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/telemetry_service.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/main.dart';

class FakeFirebaseCrashlytics extends Fake implements FirebaseCrashlytics {
  bool collectionEnabled = true;
  final List<
    ({
      dynamic exception,
      StackTrace? stack,
      dynamic reason,
      Iterable<Object> information,
      bool fatal,
      bool? printDetails,
    })
  >
  recordedErrors = [];
  final List<FlutterErrorDetails> recordedFlutterErrors = [];
  final Map<String, Object> customKeys = {};

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    bool? printDetails,
  }) async {
    recordedErrors.add((
      exception: exception,
      stack: stack,
      reason: reason,
      information: information,
      fatal: fatal,
      printDetails: printDetails,
    ));
  }

  @override
  Future<void> recordFlutterFatalError(
    FlutterErrorDetails flutterErrorDetails,
  ) async {
    recordedFlutterErrors.add(flutterErrorDetails);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys[key] = value;
  }
}

class FakeHiveLocalDataSource extends Fake implements HiveLocalDataSource {
  UserSettings _settings = const UserSettings(
    hoursAvailable: 8.0,
    crashReportingEnabled: true,
  );

  @override
  UserSettings getSettings() => _settings;

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _settings = settings;
  }

  @override
  Stream<UserSettings> watchSettings() => Stream.value(_settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlutterExceptionHandler? originalFlutterOnError;
  ErrorCallback? originalPlatformOnError;

  setUp(() {
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  group('Global Error Handlers & Runtime Toggle Tests', () {
    late FakeFirebaseCrashlytics fakeCrashlytics;
    late FirebaseCrashlyticsService crashlyticsService;
    late FakeHiveLocalDataSource fakeHive;
    late FakeFirebaseFirestore fakeFirestore;
    late ProviderContainer container;

    setUp(() {
      fakeCrashlytics = FakeFirebaseCrashlytics();
      fakeHive = FakeHiveLocalDataSource();
      fakeFirestore = FakeFirebaseFirestore();

      crashlyticsService = FirebaseCrashlyticsService(
        crashlytics: fakeCrashlytics,
        enabled: true,
      );

      container = ProviderContainer(
        overrides: [
          crashlyticsServiceProvider.overrideWithValue(crashlyticsService),
          hiveLocalDataSourceProvider.overrideWithValue(fakeHive),
          firestoreProvider.overrideWithValue(fakeFirestore),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          telemetryServiceProvider.overrideWithValue(NoOpTelemetryService()),
        ],
      );

      setupGlobalErrorHandlers(container);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'FlutterError.onError respects runtime crashReportingEnabled toggle',
      () async {
        final userSettingsRepo = container.read(userSettingsRepositoryProvider);
        expect(userSettingsRepo, isNotNull);

        final errorDetails1 = FlutterErrorDetails(
          exception: Exception('Fatal flutter error 1'),
          stack: StackTrace.current,
        );

        // 1. Initially enabled -> error is recorded
        FlutterError.onError!(errorDetails1);
        expect(fakeCrashlytics.recordedFlutterErrors.length, 1);
        expect(
          fakeCrashlytics.recordedFlutterErrors.first.exception.toString(),
          contains('Fatal flutter error 1'),
        );

        // 2. User disables crash reporting at runtime via repository
        await userSettingsRepo!.updateSettings(
          const UserSettings(hoursAvailable: 8.0, crashReportingEnabled: false),
        );
        expect(crashlyticsService.isEnabled, isFalse);

        final errorDetails2 = FlutterErrorDetails(
          exception: Exception('Fatal flutter error 2 (ignored)'),
          stack: StackTrace.current,
        );

        // Trigger again -> fatal error is not recorded
        FlutterError.onError!(errorDetails2);
        expect(fakeCrashlytics.recordedFlutterErrors.length, 1);

        // 3. User re-enables crash reporting at runtime
        await userSettingsRepo.updateSettings(
          const UserSettings(hoursAvailable: 8.0, crashReportingEnabled: true),
        );
        expect(crashlyticsService.isEnabled, isTrue);

        final errorDetails3 = FlutterErrorDetails(
          exception: Exception('Fatal flutter error 3'),
          stack: StackTrace.current,
        );

        FlutterError.onError!(errorDetails3);
        expect(fakeCrashlytics.recordedFlutterErrors.length, 2);
        expect(
          fakeCrashlytics.recordedFlutterErrors.last.exception.toString(),
          contains('Fatal flutter error 3'),
        );
      },
    );

    test(
      'PlatformDispatcher.instance.onError respects runtime crashReportingEnabled toggle',
      () async {
        final userSettingsRepo = container.read(userSettingsRepositoryProvider);
        expect(userSettingsRepo, isNotNull);

        final exception1 = StateError('Fatal platform error 1');
        final stack1 = StackTrace.current;

        // 1. Initially enabled -> error is recorded with fatal: true
        final handled1 = PlatformDispatcher.instance.onError!(
          exception1,
          stack1,
        );
        expect(handled1, isTrue);
        expect(fakeCrashlytics.recordedErrors.length, 1);
        expect(fakeCrashlytics.recordedErrors.first.exception, exception1);
        expect(fakeCrashlytics.recordedErrors.first.fatal, isTrue);

        // 2. User disables crash reporting at runtime
        await userSettingsRepo!.updateSettings(
          const UserSettings(hoursAvailable: 8.0, crashReportingEnabled: false),
        );
        expect(crashlyticsService.isEnabled, isFalse);

        final exception2 = StateError('Fatal platform error 2 (ignored)');
        final handled2 = PlatformDispatcher.instance.onError!(
          exception2,
          StackTrace.current,
        );
        expect(handled2, isTrue);
        expect(fakeCrashlytics.recordedErrors.length, 1);

        // 3. User re-enables crash reporting at runtime
        await userSettingsRepo.updateSettings(
          const UserSettings(hoursAvailable: 8.0, crashReportingEnabled: true),
        );
        expect(crashlyticsService.isEnabled, isTrue);

        final exception3 = StateError('Fatal platform error 3');
        final handled3 = PlatformDispatcher.instance.onError!(
          exception3,
          StackTrace.current,
        );
        expect(handled3, isTrue);
        expect(fakeCrashlytics.recordedErrors.length, 2);
        expect(fakeCrashlytics.recordedErrors.last.exception, exception3);
        expect(fakeCrashlytics.recordedErrors.last.fatal, isTrue);
      },
    );

    test(
      'Global error handlers work seamlessly with NoOpCrashlyticsService',
      () {
        final noOpContainer = ProviderContainer(
          overrides: [
            crashlyticsServiceProvider.overrideWithValue(
              NoOpCrashlyticsService(),
            ),
          ],
        );
        addTearDown(noOpContainer.dispose);

        setupGlobalErrorHandlers(noOpContainer);

        expect(
          () => FlutterError.onError!(
            FlutterErrorDetails(exception: Exception('NoOp flutter error')),
          ),
          returnsNormally,
        );

        expect(
          () => PlatformDispatcher.instance.onError!(
            Exception('NoOp platform error'),
            StackTrace.current,
          ),
          returnsNormally,
        );
      },
    );
  });
}
