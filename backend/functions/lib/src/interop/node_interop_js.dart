import 'dart:js' as js;

String? getEnv(String name) {
  final process = js.context['process'];
  if (process != null) {
    final env = process['env'];
    if (env != null) {
      return env[name] as String?;
    }
  }
  return null;
}

void exportFunction(String name, dynamic fn) {
  final exports = js.context['exports'];
  if (exports != null) {
    exports[name] = fn;
  }
}

js.JsObject? _loggerInstance;
js.JsObject get _logger {
  _loggerInstance ??= js.context
      .callMethod('require', ['firebase-functions/logger']) as js.JsObject;
  return _loggerInstance!;
}

void logInfo(String message) {
  try {
    _logger.callMethod('info', [message]);
  } catch (_) {
    // ignore: avoid_print
    print('[INFO] $message');
  }
}

void logWarn(String message) {
  try {
    _logger.callMethod('warn', [message]);
  } catch (_) {
    // ignore: avoid_print
    print('[WARN] $message');
  }
}

void logError(String message, [dynamic error]) {
  try {
    if (error != null) {
      _logger.callMethod('error', [message, error.toString()]);
    } else {
      _logger.callMethod('error', [message]);
    }
  } catch (_) {
    // ignore: avoid_print
    print('[ERROR] $message ${error ?? ""}');
  }
}
