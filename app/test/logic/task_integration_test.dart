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

      test('prioritizes explicit appLaunchUrl over title substring match', () {
        final result = TaskIntegration.resolveLaunchUrl(
          title: 'Duolingo French',
          appLaunchUrl: 'https://custom.duolingo.com/lesson',
        );
        expect(result, 'https://custom.duolingo.com/lesson');
      });

      test('fallback to Duolingo URL when title contains duolingo', () {
        final resultLower = TaskIntegration.resolveLaunchUrl(
          title: 'practice duolingo today',
        );
        expect(resultLower, 'https://www.duolingo.com');

        final resultUpper = TaskIntegration.resolveLaunchUrl(
          title: 'DUOLINGO LESSON',
        );
        expect(resultUpper, 'https://www.duolingo.com');

        final resultMixed = TaskIntegration.resolveLaunchUrl(
          title: 'Complete Duolingo Streak',
        );
        expect(resultMixed, 'https://www.duolingo.com');
      });

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
        'falls back to title check when appLaunchUrl is whitespace-only string',
        () {
          final result = TaskIntegration.resolveLaunchUrl(
            title: 'Duolingo Spanish',
            appLaunchUrl: '   ',
          );
          expect(result, 'https://www.duolingo.com');
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
