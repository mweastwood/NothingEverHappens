import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/main.dart';

void main() {
  group('AppConfig', () {
    tearDown(AppConfig.reset);

    test('reset() restores environment to dev', () {
      AppConfig.environment = AppEnvironment.prod;
      expect(AppConfig.environment, AppEnvironment.prod);

      AppConfig.reset();
      expect(AppConfig.environment, AppEnvironment.dev);
    });
  });

  group('AppConfig teardown isolation', () {
    // Intentionally no per-test setUp reset: the second test only passes if
    // the tearDown from the first test restored the default environment.
    tearDown(AppConfig.reset);

    test('sets prod; tearDown must restore dev', () {
      AppConfig.environment = AppEnvironment.prod;
      expect(AppConfig.environment, AppEnvironment.prod);
    });

    test('environment is dev after previous test tearDown', () {
      expect(AppConfig.environment, AppEnvironment.dev);
    });
  });
}
