import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class RemoteConfigService {
  Future<void> initialize({Map<String, dynamic>? defaultParameters});
  Future<bool> fetchAndActivate();
  bool getBool(String key);
  String getString(String key);
  int getInt(String key);
  double getDouble(String key);
  Map<String, dynamic> getAll();
}

class FirebaseRemoteConfigService implements RemoteConfigService {
  final FirebaseRemoteConfig? _remoteConfig;
  Map<String, dynamic> _defaultParameters = const {};

  FirebaseRemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig;

  @override
  Future<void> initialize({Map<String, dynamic>? defaultParameters}) async {
    if (defaultParameters != null) {
      _defaultParameters = Map<String, dynamic>.unmodifiable(defaultParameters);
    }
    if (_remoteConfig == null) return;
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 12)
              : const Duration(minutes: 1),
        ),
      );
      if (_defaultParameters.isNotEmpty) {
        await _remoteConfig.setDefaults(_defaultParameters);
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Remote Config: $e');
    }
  }

  @override
  Future<bool> fetchAndActivate() async {
    if (_remoteConfig == null) return false;
    try {
      return await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Error fetching and activating Remote Config: $e');
      return false;
    }
  }

  @override
  bool getBool(String key) {
    if (_remoteConfig != null) {
      try {
        return _remoteConfig.getBool(key);
      } catch (e) {
        debugPrint('Error reading bool key ($key) from Remote Config: $e');
      }
    }
    final fallback = _defaultParameters[key];
    if (fallback is bool) return fallback;
    if (fallback is String) return fallback.toLowerCase() == 'true';
    return false;
  }

  @override
  String getString(String key) {
    if (_remoteConfig != null) {
      try {
        return _remoteConfig.getString(key);
      } catch (e) {
        debugPrint('Error reading string key ($key) from Remote Config: $e');
      }
    }
    final fallback = _defaultParameters[key];
    return fallback?.toString() ?? '';
  }

  @override
  int getInt(String key) {
    if (_remoteConfig != null) {
      try {
        return _remoteConfig.getInt(key);
      } catch (e) {
        debugPrint('Error reading int key ($key) from Remote Config: $e');
      }
    }
    final fallback = _defaultParameters[key];
    if (fallback is int) return fallback;
    if (fallback is num) return fallback.toInt();
    if (fallback is String) return int.tryParse(fallback) ?? 0;
    return 0;
  }

  @override
  double getDouble(String key) {
    if (_remoteConfig != null) {
      try {
        return _remoteConfig.getDouble(key);
      } catch (e) {
        debugPrint('Error reading double key ($key) from Remote Config: $e');
      }
    }
    final fallback = _defaultParameters[key];
    if (fallback is double) return fallback;
    if (fallback is num) return fallback.toDouble();
    if (fallback is String) return double.tryParse(fallback) ?? 0.0;
    return 0.0;
  }

  @override
  Map<String, dynamic> getAll() {
    final map = <String, dynamic>{..._defaultParameters};
    if (_remoteConfig != null) {
      try {
        for (final entry in _remoteConfig.getAll().entries) {
          map[entry.key] = entry.value.asString();
        }
      } catch (e) {
        debugPrint('Error getting all Remote Config parameters: $e');
      }
    }
    return map;
  }
}

class NoOpRemoteConfigService implements RemoteConfigService {
  Map<String, dynamic> _defaultParameters;

  NoOpRemoteConfigService({Map<String, dynamic>? defaultParameters})
    : _defaultParameters = defaultParameters != null
          ? Map<String, dynamic>.unmodifiable(defaultParameters)
          : const {};

  @override
  Future<void> initialize({Map<String, dynamic>? defaultParameters}) async {
    if (defaultParameters != null) {
      _defaultParameters = Map<String, dynamic>.unmodifiable(defaultParameters);
    }
  }

  @override
  Future<bool> fetchAndActivate() async => false;

  @override
  bool getBool(String key) {
    final val = _defaultParameters[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  @override
  String getString(String key) {
    final val = _defaultParameters[key];
    return val?.toString() ?? '';
  }

  @override
  int getInt(String key) {
    final val = _defaultParameters[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  @override
  double getDouble(String key) {
    final val = _defaultParameters[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  Map<String, dynamic> getAll() =>
      Map<String, dynamic>.from(_defaultParameters);
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  try {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseRemoteConfigService(
        remoteConfig: FirebaseRemoteConfig.instance,
      );
    }
    return NoOpRemoteConfigService();
  } catch (e) {
    return NoOpRemoteConfigService();
  }
});
