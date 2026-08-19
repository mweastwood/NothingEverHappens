import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/crashlytics_service.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';

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
  final List<String> logs = [];
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
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys[key] = value;
  }
}

void main() {
  group('CrashlyticsService Tests', () {
    late FakeFirebaseCrashlytics fakeCrashlytics;

    setUp(() {
      fakeCrashlytics = FakeFirebaseCrashlytics();
    });

    test('initializes with enabled state', () {
      final service = FirebaseCrashlyticsService(
        crashlytics: fakeCrashlytics,
        enabled: true,
      );

      expect(service.isEnabled, isTrue);
    });

    test('initializes with disabled state', () {
      final service = FirebaseCrashlyticsService(
        crashlytics: fakeCrashlytics,
        enabled: false,
      );

      expect(service.isEnabled, isFalse);
    });

    test(
      'forwards recordError, customKeys, logs, and recordFlutterFatalError when enabled',
      () async {
        final service = FirebaseCrashlyticsService(
          crashlytics: fakeCrashlytics,
          enabled: true,
        );

        final stackTrace = StackTrace.current;
        final error = StateError('Test error');
        await service.recordError(
          error,
          stackTrace,
          reason: 'Test reason',
          fatal: true,
        );

        expect(fakeCrashlytics.recordedErrors.length, 1);
        final recorded = fakeCrashlytics.recordedErrors.first;
        expect(recorded.exception, error);
        expect(recorded.stack, stackTrace);
        expect(recorded.reason, 'Test reason');
        expect(recorded.fatal, isTrue);

        await service.setCustomKey('testKey', 'testVal');
        expect(fakeCrashlytics.customKeys['testKey'], 'testVal');

        await service.log('Test log message');
        expect(fakeCrashlytics.logs, contains('Test log message'));

        final details = FlutterErrorDetails(exception: error);
        await service.recordFlutterFatalError(details);
        expect(fakeCrashlytics.recordedFlutterErrors, contains(details));
      },
    );

    test('suppresses error recording, logs, and keys when disabled', () async {
      final service = FirebaseCrashlyticsService(
        crashlytics: fakeCrashlytics,
        enabled: false,
      );

      final stackTrace = StackTrace.current;
      final error = StateError('Ignored error');
      await service.recordError(error, stackTrace, fatal: true);
      await service.setCustomKey('testKey', 'testVal');
      await service.log('Ignored message');
      await service.recordFlutterFatalError(
        FlutterErrorDetails(exception: error),
      );

      expect(fakeCrashlytics.recordedErrors, isEmpty);
      expect(fakeCrashlytics.customKeys, isEmpty);
      expect(fakeCrashlytics.logs, isEmpty);
      expect(fakeCrashlytics.recordedFlutterErrors, isEmpty);
    });

    test(
      'setCrashlyticsCollectionEnabled toggles collection and updates isEnabled',
      () async {
        final service = FirebaseCrashlyticsService(
          crashlytics: fakeCrashlytics,
          enabled: true,
        );

        expect(service.isEnabled, isTrue);

        await service.setCrashlyticsCollectionEnabled(false);
        expect(service.isEnabled, isFalse);
        expect(fakeCrashlytics.collectionEnabled, isFalse);

        await service.recordError('test', null);
        expect(fakeCrashlytics.recordedErrors, isEmpty);

        await service.setCrashlyticsCollectionEnabled(true);
        expect(service.isEnabled, isTrue);
        expect(fakeCrashlytics.collectionEnabled, isTrue);

        await service.recordError('test2', null);
        expect(fakeCrashlytics.recordedErrors.length, 1);
      },
    );

    test('NoOpCrashlyticsService behaves safely without throwing', () async {
      final noOp = NoOpCrashlyticsService();
      expect(noOp.isEnabled, isTrue);

      await noOp.recordError(Exception('test'), StackTrace.current);
      await noOp.recordFlutterFatalError(
        FlutterErrorDetails(exception: Exception('test')),
      );
      await noOp.log('msg');
      await noOp.setCustomKey('k', 'v');
      await noOp.setCrashlyticsCollectionEnabled(false);
      expect(noOp.isEnabled, isFalse);
    });

    test('crashlyticsServiceProvider resolves without circular dependency', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Instantiating hiveLocalDataSourceProvider triggers errorHandlerProvider which triggers crashlyticsServiceProvider
      expect(
        () => container.read(hiveLocalDataSourceProvider),
        returnsNormally,
      );
      final crashlytics = container.read(crashlyticsServiceProvider);
      expect(crashlytics, isA<CrashlyticsService>());
    });
  });
}
