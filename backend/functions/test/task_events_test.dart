import 'package:functions/src/handlers/task_events.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:functions/src/models/task_event.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('validateTaskEvent', () {
    test('validates a valid task event', () {
      final payload = {
        'userId': 'user_123',
        'providerId': 'petal_count',
        'entityType': 'supplement',
        'externalId': 'preset_prenatal_morning',
        'date': '2026-08-30',
        'action': 'completed',
      };

      final result = validateTaskEvent(payload);
      expect(result.valid, isTrue);
      expect(result.event, isNotNull);
      expect(result.event?.userId, equals('user_123'));
      expect(result.event?.action, equals('completed'));
    });

    test('rejects payload missing required fields', () {
      final payload = {
        'userId': 'user_123',
        'date': '2026-08-30',
      };

      final result = validateTaskEvent(payload);
      expect(result.valid, isFalse);
      expect(
          result.error, contains('Missing or invalid required string field'));
    });

    test('rejects invalid date format', () {
      final payload = {
        'userId': 'user_123',
        'providerId': 'twelve_stars',
        'entityType': 'prayer',
        'externalId': 'rosary',
        'date': '30-08-2026',
        'action': 'completed',
      };

      final result = validateTaskEvent(payload);
      expect(result.valid, isFalse);
      expect(result.error, contains('YYYY-MM-DD'));
    });

    test('rejects unknown action', () {
      final payload = {
        'userId': 'user_123',
        'providerId': 'twelve_stars',
        'entityType': 'prayer',
        'externalId': 'rosary',
        'date': '2026-08-30',
        'action': 'invalid_action',
      };

      final result = validateTaskEvent(payload);
      expect(result.valid, isFalse);
      expect(result.error, contains('Invalid action'));
    });

    test('rejects null or non-map payload', () {
      expect(validateTaskEvent(null).valid, isFalse);
      expect(validateTaskEvent('string').valid, isFalse);
    });
  });

  group('authenticateTaskEventRequest', () {
    test('authenticates via valid service secret header (x-service-secret)',
        () async {
      final headers = {'x-service-secret': 'super_secret_token'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        envSecret: 'super_secret_token',
      );
      expect(result.authenticated, isTrue);
    });

    test('authenticates via valid service secret header (x-api-key)', () async {
      final headers = {'x-api-key': 'api_key_secret'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        envSecret: 'api_key_secret',
      );
      expect(result.authenticated, isTrue);
    });

    test('authenticates via valid Bearer service secret', () async {
      final headers = {'authorization': 'Bearer bearer_secret'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        envSecret: 'bearer_secret',
      );
      expect(result.authenticated, isTrue);
    });

    test('authenticates via valid Firebase ID token matching target userId',
        () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken =
          (token) async => const DecodedIdToken(uid: 'user_123');

      final headers = {'authorization': 'Bearer valid_id_token'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        auth: mockAuth,
      );
      expect(result.authenticated, isTrue);
    });

    test('authenticates admin Firebase ID token even if uid differs', () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken =
          (token) async => const DecodedIdToken(uid: 'admin_user', admin: true);

      final headers = {'authorization': 'Bearer admin_id_token'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        auth: mockAuth,
      );
      expect(result.authenticated, isTrue);
    });

    test(
        'rejects token when uid does not match target userId and not admin (403)',
        () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async =>
          const DecodedIdToken(uid: 'other_user', admin: false);

      final headers = {'authorization': 'Bearer foreign_token'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        auth: mockAuth,
      );
      expect(result.authenticated, isFalse);
      expect(result.status, equals(403));
      expect(result.error, contains('Forbidden'));
    });

    test('rejects invalid/expired Firebase ID token (401)', () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken =
          (token) async => throw Exception('Token expired');

      final headers = {'authorization': 'Bearer expired_token'};
      final result = await authenticateTaskEventRequest(
        headers,
        'user_123',
        auth: mockAuth,
      );
      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
      expect(result.error, contains('Invalid or expired'));
    });

    test('rejects missing authentication credentials (401)', () async {
      final headers = <String, dynamic>{};
      final result = await authenticateTaskEventRequest(headers, 'user_123');
      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
      expect(result.error, contains('Missing or invalid authentication'));
    });
  });

  group('processExternalTaskEvent', () {
    test(
        'updates an existing TaskInstance when marked completed and synchronizes completedByUserIds',
        () async {
      final mockDb = MockFirestoreDatabase();
      final instancesCol =
          mockDb.collection('users').doc('user_123').collection('instances');
      final existingDoc = instancesCol.doc('inst_existing_123');
      existingDoc.docData = {
        'scheduledDate': '2026-08-30',
        'status': 'pending',
        'completedByUserIds': ['other_user'],
      };

      instancesCol.cannedDocs = [
        MockDocumentSnapshot(
            'inst_existing_123', existingDoc.docData, true, existingDoc)
      ];

      const event = ExternalTaskEvent(
        userId: 'user_123',
        providerId: 'petal_count',
        entityType: 'supplement',
        externalId: 'preset_prenatal_morning',
        date: '2026-08-30',
        action: 'completed',
      );

      final result = await processExternalTaskEvent(mockDb, event);
      expect(result.success, isTrue);
      expect(result.instanceId, equals('inst_existing_123'));
      expect(result.createdNewInstance, isFalse);
      expect(existingDoc.updateCalls.length, equals(1));
      final updateData = existingDoc.updateCalls.first;
      expect(updateData['status'], equals('completed'));
      expect(updateData['completedByUserId'], equals('user_123'));
      expect(
          updateData['completedByUserIds'], equals(['other_user', 'user_123']));
    });

    test(
        'updates an existing TaskInstance when marked uncompleted and removes userId from completedByUserIds',
        () async {
      final mockDb = MockFirestoreDatabase();
      final instancesCol =
          mockDb.collection('users').doc('user_123').collection('instances');
      final existingDoc = instancesCol.doc('inst_existing_123');
      existingDoc.docData = {
        'scheduledDate': '2026-08-30',
        'status': 'completed',
        'completedByUserId': 'user_123',
        'completedByUserIds': ['user_123', 'family_member_2'],
      };

      instancesCol.cannedDocs = [
        MockDocumentSnapshot(
            'inst_existing_123', existingDoc.docData, true, existingDoc)
      ];

      const event = ExternalTaskEvent(
        userId: 'user_123',
        providerId: 'petal_count',
        entityType: 'supplement',
        externalId: 'preset_prenatal_morning',
        date: '2026-08-30',
        action: 'uncompleted',
      );

      final result = await processExternalTaskEvent(mockDb, event);
      expect(result.success, isTrue);
      expect(result.instanceId, equals('inst_existing_123'));
      expect(result.actionApplied, equals('uncompleted'));
      expect(existingDoc.updateCalls.length, equals(1));
      final updateData = existingDoc.updateCalls.first;
      expect(updateData['status'], equals('pending'));
      expect(updateData['completedAt'], isNull);
      expect(updateData['completedByUserId'], isNull);
      expect(updateData['completedByUserIds'], equals(['family_member_2']));
    });

    test('updates an existing TaskInstance when marked dismissed', () async {
      final mockDb = MockFirestoreDatabase();
      final instancesCol =
          mockDb.collection('users').doc('user_123').collection('instances');
      final existingDoc = instancesCol.doc('inst_existing_123');
      existingDoc.docData = {
        'scheduledDate': '2026-08-30',
        'status': 'pending',
      };

      instancesCol.cannedDocs = [
        MockDocumentSnapshot(
            'inst_existing_123', existingDoc.docData, true, existingDoc)
      ];

      const event = ExternalTaskEvent(
        userId: 'user_123',
        providerId: 'petal_count',
        entityType: 'supplement',
        externalId: 'preset_prenatal_morning',
        date: '2026-08-30',
        action: 'dismissed',
      );

      final result = await processExternalTaskEvent(mockDb, event);
      expect(result.success, isTrue);
      expect(result.instanceId, equals('inst_existing_123'));
      expect(result.actionApplied, equals('dismissed'));
      final updateData = existingDoc.updateCalls.first;
      expect(updateData['status'], equals('dismissed'));
    });

    test('creates a new TaskInstance (JIT) when no existing instance matches',
        () async {
      final mockDb = MockFirestoreDatabase();
      final instancesCol =
          mockDb.collection('users').doc('user_123').collection('instances');
      instancesCol.cannedDocs = []; // No existing instance

      const event = ExternalTaskEvent(
        userId: 'user_123',
        providerId: 'twelve_stars',
        entityType: 'prayer',
        externalId: 'rosary',
        date: '2026-08-30',
        action: 'completed',
      );

      final result = await processExternalTaskEvent(mockDb, event);
      expect(result.success, isTrue);
      expect(result.createdNewInstance, isTrue);
      expect(result.instanceId, isNotNull);

      final newDoc = instancesCol.documents[result.instanceId];
      expect(newDoc, isNotNull);
      expect(newDoc!.setCalls.length, equals(1));
      final setData = newDoc.setCalls.first;
      expect(setData['scheduledDate'], equals('2026-08-30'));
      expect(setData['status'], equals('completed'));
      expect(setData['completedByUserIds'], equals(['user_123']));
      expect(
          setData['integrationBinding']['providerId'], equals('twelve_stars'));
      expect(setData['integrationBinding']['externalId'], equals('rosary'));
    });
  });

  group('handleReportExternalTaskEvent', () {
    test('rejects non-POST requests with 405', () async {
      final req = TestHttpRequest(method: 'GET');
      final res = TestHttpResponse();

      await handleReportExternalTaskEvent(req, res);
      expect(res.statusCode, equals(405));
    });

    test('rejects invalid payload with 400', () async {
      final req = TestHttpRequest(method: 'POST', body: {});
      final res = TestHttpResponse();

      await handleReportExternalTaskEvent(req, res);
      expect(res.statusCode, equals(400));
    });

    test('rejects unauthorized request with 401', () async {
      final req = TestHttpRequest(
        method: 'POST',
        headers: {},
        body: {
          'userId': 'user_123',
          'providerId': 'p',
          'entityType': 'e',
          'externalId': 'id',
          'date': '2026-08-30',
          'action': 'completed',
        },
      );
      final res = TestHttpResponse();

      await handleReportExternalTaskEvent(req, res);
      expect(res.statusCode, equals(401));
    });
  });
}
