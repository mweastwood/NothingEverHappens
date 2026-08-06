class TaskIntegration {
  static String? resolveLaunchUrl({String? title, String? appLaunchUrl}) {
    if (appLaunchUrl != null && appLaunchUrl.isNotEmpty) {
      return appLaunchUrl;
    }
    if (title != null && title.toLowerCase().contains('duolingo')) {
      return 'https://www.duolingo.com';
    }
    return null;
  }
}
