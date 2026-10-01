import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('AppLogger Tests', () {
    group('Constructor & Capacity Assertion', () {
      test('defaults to capacity 500 when instantiated without arguments', () {
        final logger = AppLogger();
        expect(logger.capacity, equals(500));
        expect(logger.getEvents(), isEmpty);
      });

      test(
        'throws AssertionError when instantiated with capacity: 0 or negative',
        () {
          expect(() => AppLogger(capacity: 0), throwsA(isA<AssertionError>()));
          expect(() => AppLogger(capacity: -1), throwsA(isA<AssertionError>()));
          expect(
            () => AppLogger(capacity: -100),
            throwsA(isA<AssertionError>()),
          );
        },
      );
    });

    group('Ring Buffer FIFO Eviction', () {
      test(
        'retains all logged events within capacity boundary',
        () {
          final logger = AppLogger(capacity: 3);

          logger.info('cat', 'msg 1');
          logger.info('cat', 'msg 2');
          logger.info('cat', 'msg 3');

          final events = logger.getEvents();
          expect(events.length, equals(3));
          expect(events.map((e) => e.message).toList(), equals([
            'msg 1',
            'msg 2',
            'msg 3',
          ]));
        },
      );

      test(
        'evicts oldest entry in first-in-first-out order on buffer overflow',
        () {
          final logger = AppLogger(capacity: 3);

          logger.info('cat', 'msg 1');
          logger.info('cat', 'msg 2');
          logger.info('cat', 'msg 3');
          logger.info('cat', 'msg 4');

          final events = logger.getEvents();
          expect(events.length, equals(3));
          expect(events.map((e) => e.message).toList(), equals([
            'msg 2',
            'msg 3',
            'msg 4',
          ]));
        },
      );

      test(
        'continues sequential FIFO eviction as additional events arrive',
        () {
          final logger = AppLogger(capacity: 3);

          for (var i = 1; i <= 6; i++) {
            logger.info('cat', 'msg $i');
          }

          final events = logger.getEvents();
          expect(events.length, equals(3));
          expect(events.map((e) => e.message).toList(), equals([
            'msg 4',
            'msg 5',
            'msg 6',
          ]));
        },
      );
    });

    group('Log Levels & Helper Methods', () {
      late AppLogger logger;

      setUp(() {
        logger = AppLogger(capacity: 10);
      });

      test('dispatches events with matching LogLevel across all helper methods', () {
        logger.debug('cat_debug', 'debug event');
        logger.info('cat_info', 'info event');
        logger.warning('cat_warning', 'warning event');
        logger.error('cat_error', 'error event');

        final events = logger.getEvents();
        expect(events.length, equals(4));

        expect(events[0].level, equals(LogLevel.debug));
        expect(events[0].category, equals('cat_debug'));
        expect(events[0].message, equals('debug event'));

        expect(events[1].level, equals(LogLevel.info));
        expect(events[1].category, equals('cat_info'));
        expect(events[1].message, equals('info event'));

        expect(events[2].level, equals(LogLevel.warning));
        expect(events[2].category, equals('cat_warning'));
        expect(events[2].message, equals('warning event'));

        expect(events[3].level, equals(LogLevel.error));
        expect(events[3].category, equals('cat_error'));
        expect(events[3].message, equals('error event'));
      });

      test('captures all parameters accurately on recorded AppLogEvent', () {
        final stack = StackTrace.current;
        final error = StateError('State failure');

        logger.log(
          LogLevel.warning,
          'pipeline',
          'Operation failed',
          data: {'retryCount': 2, 'active': false},
          error: error,
          stackTrace: stack,
        );

        final events = logger.getEvents();
        expect(events.length, equals(1));

        final event = events.first;
        expect(event.level, equals(LogLevel.warning));
        expect(event.category, equals('pipeline'));
        expect(event.message, equals('Operation failed'));
        expect(event.data, equals({'retryCount': 2, 'active': false}));
        expect(event.error, equals(error));
        expect(event.stackTrace, equals(stack.toString()));
        expect(event.timestamp.isUtc, isTrue);
      });

      test('serializes StackTrace object to string in event.stackTrace', () {
        final stack = StackTrace.current;

        logger.error(
          'diagnostics',
          'Fatal crash',
          stackTrace: stack,
        );

        final event = logger.getEvents().first;
        expect(event.stackTrace, equals(stack.toString()));
        expect(event.stackTrace, isA<String>());
      });

      test('performs defensive map copying on data parameter to prevent mutation', () {
        final mutableData = <String, dynamic>{
          'user': 'alice',
          'count': 1,
        };

        logger.info('audit', 'Action logged', data: mutableData);

        // Mutate original map after call
        mutableData['count'] = 999;
        mutableData['user'] = 'bob';
        mutableData['injected'] = true;

        final event = logger.getEvents().first;
        expect(event.data, equals({'user': 'alice', 'count': 1}));
        expect(event.data?.containsKey('injected'), isFalse);
      });
    });

    group('JSON Serialization (AppLogEvent.toJson)', () {
      test('serializes all fields to JSON map with UTC ISO-8601 string', () {
        final now = DateTime.utc(2026, 10, 1, 14, 25, 30, 450);
        final event = AppLogEvent(
          timestamp: now,
          level: LogLevel.error,
          category: 'network',
          message: 'Connection dropped',
          data: {'endpoint': '/v1/sync', 'status': 503},
          error: Exception('Service unavailable'),
          stackTrace: 'custom_stack_trace_string',
        );

        final json = event.toJson();

        expect(json['timestamp'], equals('2026-10-01T14:25:30.450Z'));
        expect(json['level'], equals('error'));
        expect(json['category'], equals('network'));
        expect(json['message'], equals('Connection dropped'));
        expect(json['data'], equals({'endpoint': '/v1/sync', 'status': 503}));
        expect(json['error'], equals('Exception: Service unavailable'));
        expect(json['stackTrace'], equals('custom_stack_trace_string'));
      });

      test('omits null optional fields (data, error, stackTrace) from JSON map', () {
        final now = DateTime.utc(2026, 10, 1, 12, 0, 0);
        final event = AppLogEvent(
          timestamp: now,
          level: LogLevel.info,
          category: 'lifecycle',
          message: 'Application started',
        );

        final json = event.toJson();

        expect(json['timestamp'], equals('2026-10-01T12:00:00.000Z'));
        expect(json['level'], equals('info'));
        expect(json['category'], equals('lifecycle'));
        expect(json['message'], equals('Application started'));
        expect(json.containsKey('data'), isFalse);
        expect(json.containsKey('error'), isFalse);
        expect(json.containsKey('stackTrace'), isFalse);
      });

      test('converts non-string errors to string representation', () {
        final now = DateTime.utc(2026, 10, 1, 8, 0, 0);
        final customObject = 404;
        final event = AppLogEvent(
          timestamp: now,
          level: LogLevel.warning,
          category: 'http',
          message: 'Resource not found',
          error: customObject,
        );

        final json = event.toJson();
        expect(json['error'], equals('404'));
      });

      test('serializes all LogLevel enum values correctly', () {
        final now = DateTime.utc(2026, 10, 1, 10, 0, 0);
        for (final level in LogLevel.values) {
          final event = AppLogEvent(
            timestamp: now,
            level: level,
            category: 'test',
            message: 'test message',
          );
          expect(event.toJson()['level'], equals(level.name));
        }
      });
    });

    group('Buffer Management & Snapshot Immutability', () {
      test('clear resets getEvents to empty list and accepts new logs', () {
        final logger = AppLogger(capacity: 5);

        logger.info('cat', 'msg 1');
        logger.info('cat', 'msg 2');
        expect(logger.getEvents().length, equals(2));

        logger.clear();
        expect(logger.getEvents(), isEmpty);

        logger.info('cat', 'msg 3');
        final events = logger.getEvents();
        expect(events.length, equals(1));
        expect(events.first.message, equals('msg 3'));
      });

      test('getEvents returns unmodifiable list snapshot preventing mutation', () {
        final logger = AppLogger(capacity: 5);
        logger.info('cat', 'original event');

        final snapshot = logger.getEvents();

        expect(
          () => snapshot.add(
            AppLogEvent(
              timestamp: DateTime.now().toUtc(),
              level: LogLevel.debug,
              category: 'cat',
              message: 'injected',
            ),
          ),
          throwsUnsupportedError,
        );

        expect(
          () => snapshot.clear(),
          throwsUnsupportedError,
        );

        expect(
          () => snapshot.removeAt(0),
          throwsUnsupportedError,
        );
      });
    });
  });
}
