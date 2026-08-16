import 'dart:io' show Platform;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_handler.dart';
import 'hive_local_data_source.dart';
import 'utils/app_version.dart';

abstract class TelemetryService {
  Future<void> setTelemetryEnabled(bool enabled);
  Future<void> logAppLaunch({
    required String platform,
    required String appVersion,
    int? launchCount,
  });
  Future<void> logTaskCompleted({
    String? taskId,
    String? scheduleId,
    int? totalCompletedCount,
  });
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
  Future<void> setUserProperty({required String name, required String? value});
}

class FirebaseTelemetryService implements TelemetryService {
  final FirebaseAnalytics? _analytics;
  bool _enabled;
  final String _platform;
  final String _appVersion;

  FirebaseTelemetryService({
    FirebaseAnalytics? analytics,
    bool enabled = true,
    String? defaultPlatform,
    String? defaultAppVersion,
  }) : _analytics = analytics,
       _enabled = enabled,
       _platform =
           defaultPlatform ?? (kIsWeb ? 'web' : Platform.operatingSystem),
       _appVersion = defaultAppVersion ?? AppVersion.current {
    _initProperties();
  }

  void _initProperties() {
    if (_enabled) {
      setUserProperty(name: 'platform', value: _platform);
      setUserProperty(name: 'app_version', value: _appVersion);
    }
  }

  bool get isEnabled => _enabled;

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(enabled);
      if (enabled) {
        await setUserProperty(name: 'platform', value: _platform);
        await setUserProperty(name: 'app_version', value: _appVersion);
      }
    } catch (e) {
      debugPrint('Error updating analytics collection state: $e');
    }
  }

  @override
  Future<void> logAppLaunch({
    required String platform,
    required String appVersion,
    int? launchCount,
  }) async {
    await logEvent(
      'app_launch',
      parameters: {
        'platform': platform,
        'app_version': appVersion,
        'launch_count': ?launchCount,
      },
    );
  }

  @override
  Future<void> logTaskCompleted({
    String? taskId,
    String? scheduleId,
    int? totalCompletedCount,
  }) async {
    await logEvent(
      'task_completed',
      parameters: {
        'task_id': ?taskId,
        'schedule_id': ?scheduleId,
        'total_completed_count': ?totalCompletedCount,
      },
    );
  }

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_enabled) return;

    final mergedParameters = <String, Object>{
      'platform': _platform,
      'app_version': _appVersion,
      ...?parameters,
    };

    try {
      await _analytics?.logEvent(name: name, parameters: mergedParameters);
    } catch (e) {
      debugPrint('Error logging analytics event ($name): $e');
    }
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_enabled) return;

    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Error setting user property ($name): $e');
    }
  }
}

class NoOpTelemetryService implements TelemetryService {
  bool _enabled;

  NoOpTelemetryService({bool enabled = true}) : _enabled = enabled;

  bool get isEnabled => _enabled;

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    _enabled = enabled;
  }

  @override
  Future<void> logAppLaunch({
    required String platform,
    required String appVersion,
    int? launchCount,
  }) async {}

  @override
  Future<void> logTaskCompleted({
    String? taskId,
    String? scheduleId,
    int? totalCompletedCount,
  }) async {}

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  try {
    final hive = ref.watch(hiveLocalDataSourceProvider);
    final initialSettings = hive.getSettings();
    return FirebaseTelemetryService(
      analytics: FirebaseAnalytics.instance,
      enabled: initialSettings.telemetryEnabled,
    );
  } catch (e, st) {
    ref.read(errorHandlerProvider).report(e, stackTrace: st);
    return NoOpTelemetryService();
  }
});
