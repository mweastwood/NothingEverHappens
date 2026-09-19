import 'dart:async';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:test/test.dart';

void main() {
  group('safePromiseToFuture Unit Tests', () {
    test('resolves successfully for valid future/promise', () async {
      final future = Future.value('success');
      final result = await safePromiseToFuture<String>(future);
      expect(result, equals('success'));
    });

    test('resolves dynamic future casting to requested type', () async {
      final Future<dynamic> future = Future.value(42);
      final result = await safePromiseToFuture<int>(future);
      expect(result, equals(42));
    });

    test('propagates error when future/promise rejects', () async {
      final future = Future<String>.error(Exception('Promise rejected'));
      expect(
        () => safePromiseToFuture<String>(future),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError when passed null', () {
      expect(
        () => safePromiseToFuture(null),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Expected a JavaScript Promise/thenable'),
          ),
        ),
      );
    });

    test('throws StateError when passed non-thenable object', () {
      expect(
        () => safePromiseToFuture({'not': 'a promise'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Expected a JavaScript Promise/thenable'),
          ),
        ),
      );
    });

    test('throws StateError when passed string primitive', () {
      expect(
        () => safePromiseToFuture('a primitive string'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Expected a JavaScript Promise/thenable'),
          ),
        ),
      );
    });

    test('throws StateError when passed numeric primitive', () {
      expect(
        () => safePromiseToFuture(12345),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Expected a JavaScript Promise/thenable'),
          ),
        ),
      );
    });

    test('throws StateError when passed boolean primitive', () {
      expect(
        () => safePromiseToFuture(true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Expected a JavaScript Promise/thenable'),
          ),
        ),
      );
    });
  });
}
