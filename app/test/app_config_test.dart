import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/main.dart';

void main() {
  group('AppConfig', () {
    setUp(AppConfig.reset);
    tearDown(AppConfig.reset);

    test('reset() restores environment to dev', () {
      AppConfig.environment = AppEnvironment.prod;
      expect(AppConfig.environment, AppEnvironment.prod);

      AppConfig.reset();
      expect(AppConfig.environment, AppEnvironment.dev);
    });

    test('sets prod in one test to verify teardown isolation', () {
      AppConfig.environment = AppEnvironment.prod;
      expect(AppConfig.environment, AppEnvironment.prod);
    });

    test('asserts dev in subsequent test to confirm no cross-test leakage', () {
      expect(AppConfig.environment, AppEnvironment.dev);
    });
  });
}
