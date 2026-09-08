import 'dart:io';

String? getEnv(String name) {
  return Platform.environment[name];
}

void exportFunction(String name, dynamic fn) {
  // No-op on VM stub
}

void logInfo(String message) {
  // ignore: avoid_print
  print('[INFO] $message');
}

void logWarn(String message) {
  // ignore: avoid_print
  print('[WARN] $message');
}

void logError(String message, [dynamic error]) {
  // ignore: avoid_print
  print('[ERROR] $message ${error ?? ""}');
}
