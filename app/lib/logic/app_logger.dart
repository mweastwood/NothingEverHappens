import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogLevel { debug, info, warning, error }

class AppLogEvent {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final dynamic error;
  final String? stackTrace;

  AppLogEvent({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.name,
      'category': category,
      'message': message,
    };
    if (data != null) {
      map['data'] = data;
    }
    if (error != null) {
      map['error'] = error.toString();
    }
    if (stackTrace != null) {
      map['stackTrace'] = stackTrace;
    }
    return map;
  }
}

class AppLogger {
  final int capacity;
  final List<AppLogEvent> _events = [];

  AppLogger({this.capacity = 500}) : assert(capacity > 0);

  void log(
    LogLevel level,
    String category,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final event = AppLogEvent(
      timestamp: DateTime.now().toUtc(),
      level: level,
      category: category,
      message: message,
      data: data != null ? Map<String, dynamic>.from(data) : null,
      error: error,
      stackTrace: stackTrace?.toString(),
    );

    if (_events.length >= capacity) {
      _events.removeAt(0);
    }
    _events.add(event);
  }

  void debug(
    String category,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.debug,
    category,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  void info(
    String category,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.info,
    category,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  void warning(
    String category,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.warning,
    category,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  void error(
    String category,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    category,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  List<AppLogEvent> getEvents() => List.unmodifiable(_events);

  void clear() {
    _events.clear();
  }
}

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());
