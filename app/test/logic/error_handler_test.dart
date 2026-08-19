import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/crashlytics_service.dart';

class FakeCrashlyticsService implements CrashlyticsService {
  @override
  bool isEnabled = true;
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
  final Map<String, Object> customKeys = {};
  final List<String> logs = [];

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    isEnabled = enabled;
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
  ) async {}

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
  group('ErrorHandler Unit Tests', () {
    late ErrorHandler errorHandler;
    late AppLogger logger;

    setUp(() {
      logger = AppLogger();
      errorHandler = ErrorHandler(logger: logger);
    });

    test('generates ERR_ suffix for generic Exception', () {
      final error = Exception('Test Generic Error');
      final report = errorHandler.report(error);

      // _Exception becomes ERR after trimming underscores
      expect(report.code, matches(RegExp(r'^ERR_[A-Z0-9]{4}$')));
      expect(report.error, error);
      expect(errorHandler.history, contains(report));
    });

    test('generates FIREBASE_ prefix and error code for FirebaseException', () {
      final error = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
      );
      final report = errorHandler.report(error);

      expect(
        report.code,
        matches(RegExp(r'^FIREBASE_PERMISSION_DENIED_[A-Z0-9]{4}$')),
      );
    });

    test('generates PLATFORM_ prefix and error code for PlatformException', () {
      final error = PlatformException(code: 'sign_in_failed');
      final report = errorHandler.report(error);

      expect(
        report.code,
        matches(RegExp(r'^PLATFORM_SIGN_IN_FAILED_[A-Z0-9]{4}$')),
      );
    });

    test('generates FORMAT_ prefix for FormatException', () {
      final error = const FormatException('Invalid formatting');
      final report = errorHandler.report(error);

      expect(report.code, matches(RegExp(r'^FORMAT_[A-Z0-9]{4}$')));
    });

    test('generates STATE_ prefix for StateError', () {
      final error = StateError('Bad state');
      final report = errorHandler.report(error);

      expect(report.code, matches(RegExp(r'^STATE_[A-Z0-9]{4}$')));
    });

    test('generates STRING_ prefix for a raw String message error', () {
      final report = errorHandler.report('Some raw error string');

      expect(report.code, matches(RegExp(r'^STRING_[A-Z0-9]{4}$')));
    });

    test('generates different unique codes for successive reports', () {
      final report1 = errorHandler.report('Error A');
      final report2 = errorHandler.report('Error B');

      expect(report1.code, isNot(report2.code));
    });

    test('ErrorHandler.report logs structured error event into AppLogger', () {
      final testError = StateError('Unhandled state test');
      final testStackTrace = StackTrace.current;

      final report = errorHandler.report(testError, stackTrace: testStackTrace);

      final events = logger.getEvents();
      expect(events.length, 1);
      final loggedEvent = events.first;

      expect(loggedEvent.level, LogLevel.error);
      expect(loggedEvent.category, 'error_handler');
      expect(loggedEvent.message, 'Error reported: ${report.code}');
      expect(loggedEvent.data, {'errorCode': report.code});
      expect(loggedEvent.error, testError);
      expect(loggedEvent.stackTrace, testStackTrace.toString());
    });

    test(
      'ErrorHandler.report forwards non-fatal errors and error code key to CrashlyticsService',
      () {
        final fakeCrashlytics = FakeCrashlyticsService();
        final handlerWithCrashlytics = ErrorHandler(
          logger: logger,
          crashlyticsService: fakeCrashlytics,
        );

        final testError = StateError('Test crashlytics dispatch');
        final testStackTrace = StackTrace.current;

        final report = handlerWithCrashlytics.report(
          testError,
          stackTrace: testStackTrace,
        );

        expect(fakeCrashlytics.customKeys['errorCode'], report.code);
        expect(fakeCrashlytics.recordedErrors.length, 1);

        final record = fakeCrashlytics.recordedErrors.first;
        expect(record.exception, testError);
        expect(record.stack, testStackTrace);
        expect(record.fatal, isFalse);
        expect(record.reason, 'ErrorHandler [${report.code}]');
      },
    );
  });
}
