import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/task_integration.dart';

void main() {
  group('TaskIntegration', () {
    group('resolveLaunchUrl', () {
      test('returns explicit appLaunchUrl when provided', () {
        final result = TaskIntegration.resolveLaunchUrl(
          title: 'Custom Task',
          appLaunchUrl: 'https://example.com/custom',
        );
        expect(result, 'https://example.com/custom');
      });

      test(
        'prioritizes explicit appLaunchUrl over title substring match across platforms',
        () {
          final resultWeb = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo French',
            appLaunchUrl: 'https://custom.duolingo.com/lesson',
            isWeb: true,
          );
          expect(resultWeb, 'https://custom.duolingo.com/lesson');

          final resultAndroid = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo French',
            appLaunchUrl: 'https://custom.duolingo.com/lesson',
            isWeb: false,
            platform: TargetPlatform.android,
          );
          expect(resultAndroid, 'https://custom.duolingo.com/lesson');

          final resultIOS = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo French',
            appLaunchUrl: 'https://custom.duolingo.com/lesson',
            isWeb: false,
            platform: TargetPlatform.iOS,
          );
          expect(resultIOS, 'https://custom.duolingo.com/lesson');
        },
      );

      test(
        'returns https://www.duolingo.com/lesson on web when title contains duolingo',
        () {
          final resultLower = TaskIntegration.resolveLaunchUrl(
            title: 'practice duolingo today',
            isWeb: true,
          );
          expect(resultLower, 'https://www.duolingo.com/lesson');

          final resultUpper = TaskIntegration.resolveLaunchUrl(
            title: 'DUOLINGO LESSON',
            isWeb: true,
          );
          expect(resultUpper, 'https://www.duolingo.com/lesson');

          final resultMixed = TaskIntegration.resolveLaunchUrl(
            title: 'Complete Duolingo Streak',
            isWeb: true,
          );
          expect(resultMixed, 'https://www.duolingo.com/lesson');
        },
      );

      test('returns duolingo:// on Android when title contains duolingo', () {
        final resultLower = TaskIntegration.resolveLaunchUrl(
          title: 'practice duolingo today',
          isWeb: false,
          platform: TargetPlatform.android,
        );
        expect(resultLower, 'duolingo://');

        final resultUpper = TaskIntegration.resolveLaunchUrl(
          title: 'DUOLINGO LESSON',
          isWeb: false,
          platform: TargetPlatform.android,
        );
        expect(resultUpper, 'duolingo://');

        final resultMixed = TaskIntegration.resolveLaunchUrl(
          title: 'Complete Duolingo Streak',
          isWeb: false,
          platform: TargetPlatform.android,
        );
        expect(resultMixed, 'duolingo://');
      });

      test(
        'returns https://www.duolingo.com/lesson on other non-web platforms',
        () {
          for (final platform in [
            TargetPlatform.iOS,
            TargetPlatform.macOS,
            TargetPlatform.windows,
            TargetPlatform.linux,
            TargetPlatform.fuchsia,
          ]) {
            final result = TaskIntegration.resolveLaunchUrl(
              title: 'Duolingo Streak',
              isWeb: false,
              platform: platform,
            );
            expect(
              result,
              'https://www.duolingo.com/lesson',
              reason: 'Failed for platform: $platform',
            );
          }
        },
      );

      test(
        'returns null when appLaunchUrl is null/empty and title does not match',
        () {
          expect(
            TaskIntegration.resolveLaunchUrl(
              title: 'Read a book',
              appLaunchUrl: null,
            ),
            isNull,
          );

          expect(
            TaskIntegration.resolveLaunchUrl(
              title: 'Do math homework',
              appLaunchUrl: '',
            ),
            isNull,
          );

          expect(
            TaskIntegration.resolveLaunchUrl(title: null, appLaunchUrl: null),
            isNull,
          );

          expect(
            TaskIntegration.resolveLaunchUrl(
              title: 'Read a book',
              isWeb: false,
              platform: TargetPlatform.android,
            ),
            isNull,
          );
        },
      );

      test('trims whitespace from appLaunchUrl', () {
        final result = TaskIntegration.resolveLaunchUrl(
          title: 'Custom Task',
          appLaunchUrl: '   https://example.com/custom   ',
        );
        expect(result, 'https://example.com/custom');
      });

      test(
        'falls back to platform-specific Duolingo check when appLaunchUrl is whitespace-only string',
        () {
          final resultWeb = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo Spanish',
            appLaunchUrl: '   ',
            isWeb: true,
          );
          expect(resultWeb, 'https://www.duolingo.com/lesson');

          final resultAndroid = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo Spanish',
            appLaunchUrl: '   ',
            isWeb: false,
            platform: TargetPlatform.android,
          );
          expect(resultAndroid, 'duolingo://');
        },
      );

      test(
        'returns null when appLaunchUrl is whitespace-only and title does not match',
        () {
          final result = TaskIntegration.resolveLaunchUrl(
            title: 'Read a book',
            appLaunchUrl: '   \t\n  ',
          );
          expect(result, isNull);
        },
      );
    });
  });
}
