// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js' as js;
import 'notification_helper_core.dart';

export 'notification_helper_core.dart';

class _DartJsNotificationObject implements NotificationJsObject {
  final dynamic _jsObj;
  _DartJsNotificationObject(this._jsObj);

  @override
  String? get permission => _jsObj['permission'] as String?;

  @override
  void requestPermission() {
    _jsObj.callMethod('requestPermission');
  }
}

class _DartJsNotificationContext implements NotificationJsContext {
  @override
  bool hasProperty(String property) => js.context.hasProperty(property);

  @override
  NotificationJsObject? getNotification() {
    if (!hasProperty('Notification')) return null;
    final obj = js.context['Notification'];
    return obj != null ? _DartJsNotificationObject(obj) : null;
  }

  @override
  void eval(String script) {
    js.context.callMethod('eval', [script]);
  }
}

final NotificationJsContext _defaultWebContext = _DartJsNotificationContext();

/// Requests notification permissions using the browser's Notification API.
void requestWebNotificationPermission([NotificationJsContext? context]) {
  executeRequestWebNotificationPermission(context ?? _defaultWebContext);
}

/// Dispatches a browser Notification with the given title and body.
void showWebNotification(
  String title,
  String body, [
  NotificationJsContext? context,
]) {
  executeShowWebNotification(context ?? _defaultWebContext, title, body);
}
