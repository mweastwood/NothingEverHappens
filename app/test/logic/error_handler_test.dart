import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';

void main() {
  group('ErrorHandler Unit Tests', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
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
  });
}
