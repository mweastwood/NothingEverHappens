import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/telemetry_service.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  bool collectionEnabled = true;
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];
  final Map<String, String?> userProperties = {};

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    userProperties[name] = value;
  }
}

void main() {
  group('TelemetryService Tests', () {
    late FakeFirebaseAnalytics fakeAnalytics;

    setUp(() {
      fakeAnalytics = FakeFirebaseAnalytics();
    });

    test('initializes default user properties when enabled', () {
      final service = FirebaseTelemetryService(
        analytics: fakeAnalytics,
        enabled: true,
        defaultPlatform: 'android',
        defaultAppVersion: '1.2.3',
      );

      expect(service.isEnabled, isTrue);
      expect(fakeAnalytics.userProperties['platform'], 'android');
      expect(fakeAnalytics.userProperties['app_version'], '1.2.3');
    });

    test(
      'does not set user properties when initialized disabled (opted out)',
      () {
        final service = FirebaseTelemetryService(
          analytics: fakeAnalytics,
          enabled: false,
          defaultPlatform: 'android',
          defaultAppVersion: '1.2.3',
        );

        expect(service.isEnabled, isFalse);
        expect(fakeAnalytics.userProperties, isEmpty);
      },
    );

    test(
      'logAppLaunch logs app_launch event with platform, version and launch count',
      () async {
        final service = FirebaseTelemetryService(
          analytics: fakeAnalytics,
          enabled: true,
          defaultPlatform: 'web',
          defaultAppVersion: '2.0.0',
        );

        await service.logAppLaunch(
          platform: 'web',
          appVersion: '2.0.0',
          launchCount: 5,
        );

        expect(fakeAnalytics.loggedEvents.length, 1);
        final event = fakeAnalytics.loggedEvents.first;
        expect(event.name, 'app_launch');
        expect(event.parameters, {
          'platform': 'web',
          'app_version': '2.0.0',
          'launch_count': 5,
        });
      },
    );

    test(
      'logTaskCompleted logs task_completed event with task and schedule info',
      () async {
        final service = FirebaseTelemetryService(
          analytics: fakeAnalytics,
          enabled: true,
          defaultPlatform: 'android',
          defaultAppVersion: '1.0.0',
        );

        await service.logTaskCompleted(
          taskId: 'task-123',
          scheduleId: 'schedule-456',
          totalCompletedCount: 42,
        );

        expect(fakeAnalytics.loggedEvents.length, 1);
        final event = fakeAnalytics.loggedEvents.first;
        expect(event.name, 'task_completed');
        expect(event.parameters, {
          'platform': 'android',
          'app_version': '1.0.0',
          'task_id': 'task-123',
          'schedule_id': 'schedule-456',
          'total_completed_count': 42,
        });
      },
    );

    test('does not log events or properties when opted out', () async {
      final service = FirebaseTelemetryService(
        analytics: fakeAnalytics,
        enabled: false,
        defaultPlatform: 'android',
        defaultAppVersion: '1.0.0',
      );

      await service.logAppLaunch(
        platform: 'android',
        appVersion: '1.0.0',
        launchCount: 1,
      );
      await service.logTaskCompleted(taskId: 'task-1');
      await service.logEvent('custom_event', parameters: {'test': 'val'});
      await service.setUserProperty(name: 'custom_prop', value: 'val');

      expect(fakeAnalytics.loggedEvents, isEmpty);
      expect(fakeAnalytics.userProperties, isEmpty);
    });

    test(
      'setTelemetryEnabled updates collection and suppresses subsequent logs',
      () async {
        final service = FirebaseTelemetryService(
          analytics: fakeAnalytics,
          enabled: true,
          defaultPlatform: 'web',
          defaultAppVersion: '1.0.0',
        );

        expect(service.isEnabled, isTrue);

        await service.setTelemetryEnabled(false);
        expect(service.isEnabled, isFalse);
        expect(fakeAnalytics.collectionEnabled, isFalse);

        await service.logEvent('should_not_log');
        expect(fakeAnalytics.loggedEvents, isEmpty);

        await service.setTelemetryEnabled(true);
        expect(service.isEnabled, isTrue);
        expect(fakeAnalytics.collectionEnabled, isTrue);

        await service.logEvent('should_log');
        expect(fakeAnalytics.loggedEvents.length, 1);
        expect(fakeAnalytics.loggedEvents.first.name, 'should_log');
      },
    );

    test('NoOpTelemetryService behaves safely without exceptions', () async {
      final noOp = NoOpTelemetryService();
      expect(noOp.isEnabled, isTrue);

      await noOp.logAppLaunch(platform: 'web', appVersion: '1.0.0');
      await noOp.logTaskCompleted(taskId: 't1');
      await noOp.logEvent('any');
      await noOp.setUserProperty(name: 'k', value: 'v');
      await noOp.setTelemetryEnabled(false);
      expect(noOp.isEnabled, isFalse);
    });
  });
}
