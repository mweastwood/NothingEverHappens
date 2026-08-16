import 'package:flutter/foundation.dart';

class TaskIntegration {
  static String? resolveLaunchUrl({
    String? title,
    String? appLaunchUrl,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    if (appLaunchUrl != null && appLaunchUrl.trim().isNotEmpty) {
      return appLaunchUrl.trim();
    }
    if (title != null && title.toLowerCase().contains('duolingo')) {
      final currentPlatform = platform ?? defaultTargetPlatform;
      if (!isWeb && currentPlatform == TargetPlatform.android) {
        return 'duolingo://';
      }
      return 'https://www.duolingo.com/lesson';
    }
    return null;
  }
}
