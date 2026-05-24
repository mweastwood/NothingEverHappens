import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
    });

    test('report generates a unique error code and logs error', () {
      final error = Exception('Test Error');
      final report = errorHandler.report(error);

      expect(report.code, hasLength(6));
      expect(report.error, error);
      expect(errorHandler.history, contains(report));
    });

    test('generates different codes for different reports', () {
      final report1 = errorHandler.report('Error 1');
      final report2 = errorHandler.report('Error 2');

      expect(report1.code, isNot(report2.code));
    });
  });
}
