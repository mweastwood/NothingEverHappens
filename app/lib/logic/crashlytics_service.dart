import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hive_local_data_source.dart';

abstract class CrashlyticsService {
  bool get isEnabled;
  Future<void> setCrashlyticsCollectionEnabled(bool enabled);
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    bool? printDetails,
  });
  Future<void> recordFlutterFatalError(FlutterErrorDetails flutterErrorDetails);
  Future<void> log(String message);
  Future<void> setCustomKey(String key, Object value);
}

class FirebaseCrashlyticsService implements CrashlyticsService {
  final FirebaseCrashlytics? _crashlytics;
  bool _enabled;

  FirebaseCrashlyticsService({
    FirebaseCrashlytics? crashlytics,
    bool enabled = true,
  }) : _crashlytics = crashlytics,
       _enabled = enabled;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    _enabled = enabled;
    if (!kIsWeb) {
      try {
        await _crashlytics?.setCrashlyticsCollectionEnabled(enabled);
      } catch (e) {
        debugPrint('Error setting Crashlytics collection state: $e');
      }
    }
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    bool? printDetails,
  }) async {
    if (!_enabled || kIsWeb) return;
    try {
      await _crashlytics?.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
        printDetails: printDetails,
      );
    } catch (e) {
      debugPrint('Error recording Crashlytics error: $e');
    }
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    if (!_enabled || kIsWeb) return;
    try {
      await _crashlytics?.recordFlutterFatalError(details);
    } catch (e) {
      debugPrint('Error recording Flutter fatal error: $e');
    }
  }

  @override
  Future<void> log(String message) async {
    if (!_enabled || kIsWeb) return;
    try {
      await _crashlytics?.log(message);
    } catch (e) {
      debugPrint('Error writing Crashlytics log: $e');
    }
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    if (!_enabled || kIsWeb) return;
    try {
      await _crashlytics?.setCustomKey(key, value);
    } catch (e) {
      debugPrint('Error setting Crashlytics custom key: $e');
    }
  }
}

class NoOpCrashlyticsService implements CrashlyticsService {
  bool _enabled;

  NoOpCrashlyticsService({bool enabled = true}) : _enabled = enabled;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    _enabled = enabled;
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    bool? printDetails,
  }) async {}

  @override
  Future<void> recordFlutterFatalError(
    FlutterErrorDetails flutterErrorDetails,
  ) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

final Provider<CrashlyticsService> crashlyticsServiceProvider =
    Provider<CrashlyticsService>((ref) {
      try {
        final hive = ref.watch(hiveLocalDataSourceProvider);
        final initialSettings = hive.getSettings();
        return FirebaseCrashlyticsService(
          crashlytics: !kIsWeb && Firebase.apps.isNotEmpty
              ? FirebaseCrashlytics.instance
              : null,
          enabled: initialSettings.crashReportingEnabled,
        );
      } catch (e) {
        return NoOpCrashlyticsService();
      }
    });
