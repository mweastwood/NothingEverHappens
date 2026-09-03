import 'package:flutter/foundation.dart';

class AppVersion {
  static const String rawVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'v0.0.0-dev',
  );

  static const String rawGitHash = String.fromEnvironment(
    'GIT_HASH',
    defaultValue: '',
  );

  static String get current => rawVersion;

  static String get gitHash => rawGitHash;

  static String get shortGitHash =>
      rawGitHash.length >= 7 ? rawGitHash.substring(0, 7) : rawGitHash;

  static String get display {
    if (shortGitHash.isNotEmpty) {
      return '$rawVersion ($shortGitHash)';
    }
    return rawVersion;
  }

  static String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name;
}
