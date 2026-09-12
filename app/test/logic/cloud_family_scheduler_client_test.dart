import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/cloud_family_scheduler_client.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';

class _MockErrorHandler extends Fake implements ErrorHandler {
  final List<dynamic> errors = [];

  @override
  ErrorReport report(dynamic error, {StackTrace? stackTrace}) {
    errors.add(error);
    return ErrorReport(
      code: 'TEST',
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );
  }
}

class _MockUser extends Mock implements User {
  final String _token;
  _MockUser({String token = 'test-token'}) : _token = token;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => _token;

  @override
  String get uid => 'user-123';
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {
  final User? _user;
  _MockFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class _TestHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;
  final List<http.Request> requests = [];

  _TestHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    requests.add(httpRequest);
    final response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('CloudFamilySchedulerClient', () {
    late _MockErrorHandler errorHandler;

    setUp(() {
      errorHandler = _MockErrorHandler();
    });

    test('resolveEndpointUrl with custom baseUrl without trailing slash', () {
      final client = CloudFamilySchedulerClient(
        baseUrl: 'http://localhost:5001/my-project/us-central1',
      );
      expect(
        client.resolveEndpointUrl(),
        'http://localhost:5001/my-project/us-central1/processFamilySchedule',
      );
    });

    test('resolveEndpointUrl with custom baseUrl with trailing slash', () {
      final client = CloudFamilySchedulerClient(
        baseUrl: 'http://localhost:5001/my-project/us-central1/',
      );
      expect(
        client.resolveEndpointUrl(),
        'http://localhost:5001/my-project/us-central1/processFamilySchedule',
      );
    });

    test('resolveEndpointUrl fallback when no Firebase or baseUrl', () {
      final client = CloudFamilySchedulerClient();
      expect(
        client.resolveEndpointUrl(),
        'https://us-central1-nothing-ever-happens-dev.cloudfunctions.net/processFamilySchedule',
      );
    });

    test(
      'triggerFamilyScheduleProcessing does nothing if familyId is empty',
      () async {
        var called = false;
        final httpClient = _TestHttpClient((req) async {
          called = true;
          return http.Response('ok', 200);
        });

        final client = CloudFamilySchedulerClient(
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser()),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: '',
        );
        expect(success, isFalse);
        expect(called, isFalse);
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing does nothing if user is null',
      () async {
        var called = false;
        final httpClient = _TestHttpClient((req) async {
          called = true;
          return http.Response('ok', 200);
        });

        final client = CloudFamilySchedulerClient(
          httpClient: httpClient,
          auth: _MockFirebaseAuth(null),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-123',
        );
        expect(success, isFalse);
        expect(called, isFalse);
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing sends correct POST request with auth header',
      () async {
        http.Request? capturedRequest;
        final httpClient = _TestHttpClient((req) async {
          capturedRequest = req;
          return http.Response(jsonEncode({'success': true}), 200);
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser(token: 'my-auth-token')),
          errorHandler: errorHandler,
        );

        final testTime = DateTime.utc(2026, 9, 12, 10, 30);
        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-abc',
          now: testTime,
        );

        expect(success, isTrue);
        expect(capturedRequest, isNotNull);
        expect(
          capturedRequest!.url.toString(),
          'http://localhost:5001/processFamilySchedule',
        );
        expect(
          capturedRequest!.headers['authorization'],
          'Bearer my-auth-token',
        );
        expect(
          capturedRequest!.headers['content-type'],
          startsWith('application/json'),
        );

        final decodedBody =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(decodedBody['familyId'], 'family-abc');
        expect(decodedBody['now'], testTime.toIso8601String());
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing handles HTTP error status without throwing',
      () async {
        final httpClient = _TestHttpClient((req) async {
          return http.Response('Internal Server Error', 500);
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser()),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-err',
        );
        expect(success, isFalse);
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing handles network exception gracefully and reports it',
      () async {
        final httpClient = _TestHttpClient((req) async {
          throw http.ClientException('Connection refused');
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser()),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-net-err',
        );
        expect(success, isFalse);
        expect(errorHandler.errors.length, 1);
        expect(errorHandler.errors.first, isA<http.ClientException>());
      },
    );
  });
}
