export 'notification_helper_core.dart';

import 'notification_helper_core.dart';

/// Stub for requesting permission (noop on native platforms).
void requestWebNotificationPermission([NotificationJsContext? context]) {}

/// Stub for showing web notifications (noop on native platforms).
void showWebNotification(
  String title,
  String body, [
  NotificationJsContext? context,
]) {}
