import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

void main() {
  group('AppVersion', () {
    test('provides default version string', () {
      expect(AppVersion.current, isNotEmpty);
      expect(AppVersion.display, isNotEmpty);
    });

    test('shortGitHash truncates git hash to 7 characters when available', () {
      expect(AppVersion.shortGitHash.length, lessThanOrEqualTo(7));
    });
  });
}
