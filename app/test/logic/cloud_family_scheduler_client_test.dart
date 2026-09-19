import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
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
  final String? _token;
  final Future<String?> Function(bool forceRefresh)? _tokenProvider;

  _MockUser({
    String? token = 'test-token',
    Future<String?> Function(bool forceRefresh)? tokenProvider,
  }) : _token = token,
       _tokenProvider = tokenProvider;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    final tokenProvider = _tokenProvider;
    if (tokenProvider != null) {
      return await tokenProvider(forceRefresh);
    }
    return _token;
  }

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
  bool isClosed = false;

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

  @override
  void close() {
    isClosed = true;
    super.close();
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
      'triggerFamilyScheduleProcessing does not fall back to FirebaseAuth.instance when auth is explicitly provided with null currentUser',
      () async {
        var called = false;
        final httpClient = _TestHttpClient((req) async {
          called = true;
          return http.Response('ok', 200);
        });

        // Explicit auth provided where currentUser is null
        final client = CloudFamilySchedulerClient(
          httpClient: httpClient,
          auth: _MockFirebaseAuth(null),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-456',
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
      'triggerFamilyScheduleProcessing returns false if getIdToken is null',
      () async {
        var called = false;
        final httpClient = _TestHttpClient((req) async {
          called = true;
          return http.Response('ok', 200);
        });

        final client = CloudFamilySchedulerClient(
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser(token: null)),
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
      'triggerFamilyScheduleProcessing returns false if getIdToken is empty',
      () async {
        var called = false;
        final httpClient = _TestHttpClient((req) async {
          called = true;
          return http.Response('ok', 200);
        });

        final client = CloudFamilySchedulerClient(
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser(token: '')),
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
      'triggerFamilyScheduleProcessing retries with force-refreshed token on 401 response and succeeds',
      () async {
        final logger = AppLogger();
        final httpClient = _TestHttpClient((req) async {
          final authHeader = req.headers['authorization'];
          if (authHeader == 'Bearer expired-token') {
            return http.Response(
              jsonEncode({
                'success': false,
                'error':
                    'Unauthorized: Invalid or expired authentication token.',
              }),
              401,
            );
          } else if (authHeader == 'Bearer fresh-token') {
            return http.Response(jsonEncode({'success': true}), 200);
          }
          return http.Response('Bad request', 400);
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(
            _MockUser(
              tokenProvider: (forceRefresh) async =>
                  forceRefresh ? 'fresh-token' : 'expired-token',
            ),
          ),
          logger: logger,
          errorHandler: errorHandler,
        );

        final testTime = DateTime.utc(2026, 9, 19, 4, 0);
        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-retry-ok',
          now: testTime,
        );

        expect(success, isTrue);
        expect(httpClient.requests.length, 2);
        expect(
          httpClient.requests[0].headers['authorization'],
          'Bearer expired-token',
        );
        expect(
          httpClient.requests[1].headers['authorization'],
          'Bearer fresh-token',
        );
        expect(httpClient.requests[0].body, httpClient.requests[1].body);

        final logEvents = logger.getEvents();
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.info &&
                e.message.contains(
                  'Cloud family scheduler returned 401 Unauthorized; attempting token refresh and retry...',
                ),
          ),
          isTrue,
        );
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.info &&
                e.message.contains(
                  'Successfully triggered cloud family scheduler for familyId=family-retry-ok',
                ),
          ),
          isTrue,
        );
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing retries on 401 but returns false if refreshed request also fails',
      () async {
        final logger = AppLogger();
        final httpClient = _TestHttpClient((req) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'error': 'Unauthorized: Invalid or expired authentication token.',
            }),
            401,
          );
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(
            _MockUser(
              tokenProvider: (forceRefresh) async =>
                  forceRefresh ? 'fresh-token' : 'expired-token',
            ),
          ),
          logger: logger,
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-retry-fail',
        );

        expect(success, isFalse);
        expect(httpClient.requests.length, 2);
        expect(
          httpClient.requests[0].headers['authorization'],
          'Bearer expired-token',
        );
        expect(
          httpClient.requests[1].headers['authorization'],
          'Bearer fresh-token',
        );

        final logEvents = logger.getEvents();
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.info &&
                e.message.contains(
                  'Cloud family scheduler returned 401 Unauthorized; attempting token refresh and retry...',
                ),
          ),
          isTrue,
        );
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.warning &&
                e.message.contains(
                  'Cloud family scheduler responded with status 401',
                ),
          ),
          isTrue,
        );
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing on 401 does not retry and returns false if refreshed token is null',
      () async {
        final logger = AppLogger();
        final httpClient = _TestHttpClient((req) async {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Unauthorized'}),
            401,
          );
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(
            _MockUser(
              tokenProvider: (forceRefresh) async =>
                  forceRefresh ? null : 'expired-token',
            ),
          ),
          logger: logger,
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-null-refresh',
        );

        expect(success, isFalse);
        expect(httpClient.requests.length, 1);

        final logEvents = logger.getEvents();
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.warning &&
                e.message.contains(
                  'Failed to refresh ID token after 401 Unauthorized for user user-123',
                ),
          ),
          isTrue,
        );
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing on 401 does not retry and returns false if refreshed token is empty',
      () async {
        final logger = AppLogger();
        final httpClient = _TestHttpClient((req) async {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Unauthorized'}),
            401,
          );
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(
            _MockUser(
              tokenProvider: (forceRefresh) async =>
                  forceRefresh ? '' : 'expired-token',
            ),
          ),
          logger: logger,
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-empty-refresh',
        );

        expect(success, isFalse);
        expect(httpClient.requests.length, 1);

        final logEvents = logger.getEvents();
        expect(
          logEvents.any(
            (e) =>
                e.level == LogLevel.warning &&
                e.message.contains(
                  'Failed to refresh ID token after 401 Unauthorized for user user-123',
                ),
          ),
          isTrue,
        );
        expect(errorHandler.errors, isEmpty);
      },
    );

    test(
      'triggerFamilyScheduleProcessing handles error during token refresh gracefully and reports it',
      () async {
        final httpClient = _TestHttpClient((req) async {
          return http.Response('Unauthorized', 401);
        });

        final refreshException = Exception('Failed to refresh Firebase token');
        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(
            _MockUser(
              tokenProvider: (forceRefresh) async {
                if (forceRefresh) throw refreshException;
                return 'expired-token';
              },
            ),
          ),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-refresh-throw',
        );

        expect(success, isFalse);
        expect(httpClient.requests.length, 1);
        expect(errorHandler.errors.length, 1);
        expect(errorHandler.errors.first, refreshException);
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

    test(
      'triggerFamilyScheduleProcessing handles request timeout gracefully and reports it',
      () async {
        final httpClient = _TestHttpClient((req) async {
          throw TimeoutException('Request timed out');
        });

        final client = CloudFamilySchedulerClient(
          baseUrl: 'http://localhost:5001',
          httpClient: httpClient,
          auth: _MockFirebaseAuth(_MockUser()),
          errorHandler: errorHandler,
        );

        final success = await client.triggerFamilyScheduleProcessing(
          familyId: 'family-timeout',
        );
        expect(success, isFalse);
        expect(errorHandler.errors.length, 1);
        expect(errorHandler.errors.first, isA<TimeoutException>());
      },
    );

    test('dispose closes underlying httpClient', () {
      final httpClient = _TestHttpClient(
        (req) async => http.Response('ok', 200),
      );
      final client = CloudFamilySchedulerClient(httpClient: httpClient);
      expect(httpClient.isClosed, isFalse);
      client.dispose();
      expect(httpClient.isClosed, isTrue);
    });

    test(
      'cloudFamilySchedulerClientProvider disposes client on container disposal',
      () {
        final container = ProviderContainer();
        final client = container.read(cloudFamilySchedulerClientProvider);
        expect(client, isNotNull);
        container.dispose();
      },
    );
  });
}
