// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js' as js;

/// Requests notification permissions using the browser's Notification API.
void requestWebNotificationPermission() {
  if (js.context.hasProperty('Notification')) {
    final notification = js.context['Notification'];
    if (notification['permission'] != 'granted') {
      notification.callMethod('requestPermission');
    }
  }
}

/// Dispatches a browser Notification with the given title and body.
void showWebNotification(String title, String body) {
  if (js.context.hasProperty('Notification')) {
    final notification = js.context['Notification'];
    if (notification['permission'] == 'granted') {
      js.context.callMethod('eval', [
        "new Notification('${title.replaceAll("'", "\\'")}', { body: '${body.replaceAll("'", "\\'")}' });",
      ]);
    }
  }
}
