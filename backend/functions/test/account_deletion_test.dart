import 'package:functions/src/handlers/account_deletion.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('authenticateUserRequest', () {
    test('authenticates a valid Bearer ID token', () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'user_abc_123',
            email: 'tester@example.com',
          );

      final headers = {'authorization': 'Bearer valid_id_token'};
      final result = await authenticateUserRequest(headers, auth: mockAuth);

      expect(result.authenticated, isTrue);
      expect(result.user?.uid, equals('user_abc_123'));
      expect(result.user?.email, equals('tester@example.com'));
    });

    test('handles case-insensitive Authorization header', () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'user_abc_123',
            email: 'tester@example.com',
          );

      final headers = {'Authorization': 'Bearer valid_id_token'};
      final result = await authenticateUserRequest(headers, auth: mockAuth);

      expect(result.authenticated, isTrue);
      expect(result.user?.uid, equals('user_abc_123'));
    });

    test('rejects missing Authorization header with 401', () async {
      final headers = <String, dynamic>{};
      final result = await authenticateUserRequest(headers);

      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
      expect(result.error, contains('Missing or invalid Authorization header'));
    });

    test('rejects malformed Authorization header with 401', () async {
      final headers = {'authorization': 'Basic some_basic_auth_string'};
      final result = await authenticateUserRequest(headers);

      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
    });

    test('rejects invalid or expired token with 401', () async {
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken =
          (token) async => throw Exception('Token expired');

      final headers = {'authorization': 'Bearer expired_token'};
      final result = await authenticateUserRequest(headers, auth: mockAuth);

      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
      expect(result.error, contains('Invalid or expired authentication token'));
    });
  });

  group('deleteUserAccountData', () {
    test(
        'deletes sole family member, purging family, invites, user data, and auth profile',
        () async {
      final mockDb = MockFirestoreDatabase();
      final userRef = mockDb.collection('users').doc('user_sole');
      userRef.docData = {
        'familyId': 'fam_123',
        'email': 'soleuser@example.com',
      };

      final familyRef = mockDb.collection('families').doc('fam_123');
      familyRef.docData = {
        'name': 'Test Family',
        'members': {
          'user_sole': {'role': 'parent', 'email': 'soleuser@example.com'},
        },
      };

      final invite1 = mockDb.collection('invites').doc('inv_1');
      final invite2 = mockDb.collection('invites').doc('inv_2');

      mockDb.collection('invites').onGet = () async {
        return MockQuerySnapshot([
          MockDocumentSnapshot('inv_1', {}, true, invite1),
          MockDocumentSnapshot('inv_2', {}, true, invite2),
        ]);
      };

      final mockAuth = MockAuthService();

      final result = await deleteUserAccountData(
        mockDb,
        mockAuth,
        'user_sole',
        userEmail: 'soleuser@example.com',
      );

      expect(result.success, isTrue);
      expect(result.userId, equals('user_sole'));
      // Family was sole member -> family document recursively deleted
      expect(mockDb.recursiveDeletedRefs, contains(familyRef));
      // User doc recursively deleted
      expect(mockDb.recursiveDeletedRefs, contains(userRef));
      // Auth deleted
      expect(mockAuth.deletedUserIds, contains('user_sole'));
    });

    test('removes user from multi-member family without deleting entire family',
        () async {
      final mockDb = MockFirestoreDatabase();
      final userRef = mockDb.collection('users').doc('user_multi_1');
      userRef.docData = {
        'familyId': 'fam_multi',
        'email': 'member1@example.com',
      };

      final familyRef = mockDb.collection('families').doc('fam_multi');
      familyRef.docData = {
        'name': 'Multi Member Family',
        'members': {
          'user_multi_1': {'role': 'parent'},
          'user_multi_2': {'role': 'parent'},
        },
      };

      final mockAuth = MockAuthService();

      final result = await deleteUserAccountData(
        mockDb,
        mockAuth,
        'user_multi_1',
        userEmail: 'member1@example.com',
      );

      expect(result.success, isTrue);
      // Family should NOT be deleted recursively
      expect(mockDb.recursiveDeletedRefs, isNot(contains(familyRef)));
      // Member should be removed via update
      expect(familyRef.updateCalls.length, equals(1));
      expect(familyRef.updateCalls.first.containsKey('members.user_multi_1'),
          isTrue);
      // User doc recursively deleted
      expect(mockDb.recursiveDeletedRefs, contains(userRef));
      // Auth deleted
      expect(mockAuth.deletedUserIds, contains('user_multi_1'));
    });

    test('handles user without family association gracefully', () async {
      final mockDb = MockFirestoreDatabase();
      final userRef = mockDb.collection('users').doc('user_loner');
      userRef.docData = {
        'email': 'loner@example.com',
      };

      final mockAuth = MockAuthService();

      final result = await deleteUserAccountData(
        mockDb,
        mockAuth,
        'user_loner',
      );

      expect(result.success, isTrue);
      expect(mockDb.recursiveDeletedRefs, contains(userRef));
      expect(mockAuth.deletedUserIds, contains('user_loner'));
    });

    test('ignores auth/user-not-found error if Auth user is already deleted',
        () async {
      final mockDb = MockFirestoreDatabase();
      final userRef = mockDb.collection('users').doc('user_missing');
      userRef.isExisting = false;

      final mockAuth = MockAuthService();
      mockAuth.onDeleteUser = (uid) async {
        throw const FirebaseAuthException(
          code: 'auth/user-not-found',
          message: 'User not found',
        );
      };

      final result = await deleteUserAccountData(
        mockDb,
        mockAuth,
        'user_missing',
      );

      expect(result.success, isTrue);
    });
  });

  group('handleDeleteUserAccount', () {
    test('rejects non-POST/DELETE requests with 405 Method Not Allowed',
        () async {
      final req = TestHttpRequest(method: 'GET');
      final res = TestHttpResponse();

      await handleDeleteUserAccount(req, res);

      expect(res.statusCode, equals(405));
      expect(res.responseData['error'], contains('Method Not Allowed'));
    });

    test('rejects unauthenticated requests with 401 Unauthorized', () async {
      final req = TestHttpRequest(method: 'POST');
      final res = TestHttpResponse();

      await handleDeleteUserAccount(req, res);

      expect(res.statusCode, equals(401));
    });

    test('successfully processes valid POST request with 200 OK', () async {
      final mockDb = MockFirestoreDatabase();
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'user_delete_me',
            email: 'delete_me@example.com',
          );

      final req = TestHttpRequest(
        method: 'POST',
        headers: {'authorization': 'Bearer valid_user_token'},
      );
      final res = TestHttpResponse();

      await handleDeleteUserAccount(req, res, db: mockDb, auth: mockAuth);

      expect(res.statusCode, equals(200));
      expect(res.responseData['success'], isTrue);
      expect(res.responseData['userId'], equals('user_delete_me'));
    });

    test('successfully processes valid DELETE request with 200 OK', () async {
      final mockDb = MockFirestoreDatabase();
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'user_delete_me',
            email: 'delete_me@example.com',
          );

      final req = TestHttpRequest(
        method: 'DELETE',
        headers: {'authorization': 'Bearer valid_user_token'},
      );
      final res = TestHttpResponse();

      await handleDeleteUserAccount(req, res, db: mockDb, auth: mockAuth);

      expect(res.statusCode, equals(200));
      expect(res.responseData['success'], isTrue);
      expect(res.responseData['userId'], equals('user_delete_me'));
    });

    test('returns 500 when backend deletion fails', () async {
      final mockDb = MockFirestoreDatabase();
      final mockAuth = MockAuthService();
      mockAuth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'user_fail',
            email: 'fail@example.com',
          );
      mockAuth.onDeleteUser = (uid) async {
        throw Exception('Database write lock error');
      };

      final req = TestHttpRequest(
        method: 'POST',
        headers: {'authorization': 'Bearer valid_user_token'},
      );
      final res = TestHttpResponse();

      await handleDeleteUserAccount(req, res, db: mockDb, auth: mockAuth);

      expect(res.statusCode, equals(500));
      expect(res.responseData['error'], contains('Database write lock error'));
    });
  });
}
