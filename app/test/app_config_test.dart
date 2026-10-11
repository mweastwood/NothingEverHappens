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
  });
}
