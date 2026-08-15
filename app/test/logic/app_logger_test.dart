import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';

void main() {
  group('AppLogger Unit Tests', () {
    late AppLogger logger;

    setUp(() {
      logger = AppLogger(capacity: 5);
    });

    test('logs events across all LogLevel categories and helper methods', () {
      logger.debug('test_cat', 'debug msg', data: {'key1': 'val1'});
      logger.info('test_cat', 'info msg', data: {'key2': 42});
      logger.warning('test_cat', 'warning msg', data: {'key3': true});
      logger.error(
        'test_cat',
        'error msg',
        data: {'key4': 'err'},
        error: Exception('Test Ex'),
        stackTrace: StackTrace.current,
      );

      final events = logger.getEvents();
      expect(events.length, 4);

      expect(events[0].level, LogLevel.debug);
      expect(events[0].category, 'test_cat');
      expect(events[0].message, 'debug msg');
      expect(events[0].data, {'key1': 'val1'});
      expect(events[0].error, isNull);
      expect(events[0].stackTrace, isNull);

      expect(events[1].level, LogLevel.info);
      expect(events[1].message, 'info msg');
      expect(events[1].data, {'key2': 42});

      expect(events[2].level, LogLevel.warning);
      expect(events[2].message, 'warning msg');
      expect(events[2].data, {'key3': true});

      expect(events[3].level, LogLevel.error);
      expect(events[3].message, 'error msg');
      expect(events[3].data, {'key4': 'err'});
      expect(events[3].error, isNotNull);
      expect(events[3].stackTrace, isNotNull);
    });

    test(
      'enforces ring buffer capacity limits by evicting oldest events FIFO',
      () {
        final boundedLogger = AppLogger(capacity: 3);

        boundedLogger.info('cat', 'msg 1');
        boundedLogger.info('cat', 'msg 2');
        boundedLogger.info('cat', 'msg 3');

        expect(boundedLogger.getEvents().map((e) => e.message).toList(), [
          'msg 1',
          'msg 2',
          'msg 3',
        ]);

        // Adding 4th item evicts msg 1
        boundedLogger.info('cat', 'msg 4');
        expect(boundedLogger.getEvents().map((e) => e.message).toList(), [
          'msg 2',
          'msg 3',
          'msg 4',
        ]);

        // Adding 5th item evicts msg 2
        boundedLogger.info('cat', 'msg 5');
        expect(boundedLogger.getEvents().map((e) => e.message).toList(), [
          'msg 3',
          'msg 4',
          'msg 5',
        ]);
      },
    );

    test(
      'AppLogEvent.toJson serializes correctly with UTC ISO-8601 timestamps',
      () {
        final now = DateTime.utc(2026, 8, 15, 12, 34, 56);
        final event = AppLogEvent(
          timestamp: now,
          level: LogLevel.warning,
          category: 'auth',
          message: 'Auth token expired',
          data: {'userId': 'user-999', 'attempts': 3},
          error: 'TokenExpiredException',
          stackTrace: 'custom stack trace',
        );

        final json = event.toJson();
        expect(json['timestamp'], '2026-08-15T12:34:56.000Z');
        expect(json['level'], 'warning');
        expect(json['category'], 'auth');
        expect(json['message'], 'Auth token expired');
        expect(json['data'], {'userId': 'user-999', 'attempts': 3});
        expect(json['error'], 'TokenExpiredException');
        expect(json['stackTrace'], 'custom stack trace');
      },
    );

    test('AppLogEvent.toJson handles null optional fields cleanly', () {
      final now = DateTime.utc(2026, 8, 15, 12, 0, 0);
      final event = AppLogEvent(
        timestamp: now,
        level: LogLevel.info,
        category: 'lifecycle',
        message: 'App started',
      );

      final json = event.toJson();
      expect(json['timestamp'], '2026-08-15T12:00:00.000Z');
      expect(json['level'], 'info');
      expect(json['category'], 'lifecycle');
      expect(json['message'], 'App started');
      expect(json.containsKey('data'), isFalse);
      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
    });

    test('clear empties the buffer', () {
      logger.info('cat', 'msg 1');
      logger.info('cat', 'msg 2');
      expect(logger.getEvents().length, 2);

      logger.clear();
      expect(logger.getEvents(), isEmpty);
    });

    test('getEvents returns unmodifiable list snapshot', () {
      logger.info('cat', 'msg 1');
      final events = logger.getEvents();
      expect(
        () => (events as dynamic).add(
          AppLogEvent(
            timestamp: DateTime.now(),
            level: LogLevel.info,
            category: 'cat',
            message: 'hack',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
