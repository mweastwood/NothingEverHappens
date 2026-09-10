import 'dart:convert';

/// Escapes characters for insertion into single-quoted JS string literals.
String escapeNotificationText(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

/// Builds the JS script for creating a browser Notification.
String buildNotificationScript(String title, String body) {
  return 'new Notification(${jsonEncode(title)}, { body: ${jsonEncode(body)} });';
}

/// Abstract representation of the browser's Notification object.
abstract class NotificationJsObject {
  String? get permission;
  void requestPermission();
}

/// Abstract representation of the JavaScript execution context.
abstract class NotificationJsContext {
  bool hasProperty(String property);
  NotificationJsObject? getNotification();
  void eval(String script);
}

/// Requests web notification permission using the provided JS context.
void executeRequestWebNotificationPermission(NotificationJsContext jsContext) {
  if (jsContext.hasProperty('Notification')) {
    final notification = jsContext.getNotification();
    if (notification != null && notification.permission != 'granted') {
      notification.requestPermission();
    }
  }
}

/// Shows a web notification using the provided JS context if permission is granted.
void executeShowWebNotification(
  NotificationJsContext jsContext,
  String title,
  String body,
) {
  if (jsContext.hasProperty('Notification')) {
    final notification = jsContext.getNotification();
    if (notification != null && notification.permission == 'granted') {
      jsContext.eval(buildNotificationScript(title, body));
    }
  }
}
