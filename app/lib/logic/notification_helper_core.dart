/// Escapes single quotes for insertion into JS string literals.
String escapeNotificationText(String text) => text.replaceAll("'", "\\'");

/// Builds the JS script for creating a browser Notification.
String buildNotificationScript(String title, String body) {
  final escapedTitle = escapeNotificationText(title);
  final escapedBody = escapeNotificationText(body);
  return "new Notification('$escapedTitle', { body: '$escapedBody' });";
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
