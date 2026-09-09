import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

export 'package:core/core.dart' show LogLevel, AppLogEvent, AppLogger;

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());
