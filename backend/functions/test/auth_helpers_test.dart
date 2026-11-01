import 'package:functions/src/handlers/auth_helpers.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('extractHeader', () {
    test('returns exact key match and unwraps List values', () {
      expect(
        extractHeader({'x-api-key': 'secret-1'}, ['x-api-key']),
        equals('secret-1'),
      );
      expect(
        extractHeader(
          {
            'x-api-key': ['first-val', 'second-val'],
          },
          ['x-api-key'],
        ),
        equals('first-val'),
      );
      expect(extractHeader({'x-api-key': <String>[]}, ['x-api-key']), isNull);
    });

    test('matches case-insensitively when exact key is absent', () {
      expect(
        extractHeader({'X-Service-Secret': 'sec'}, ['x-service-secret']),
        equals('sec'),
      );
      expect(
        extractHeader(
          {
            'Authorization': ['Bearer tok'],
          },
          ['authorization'],
        ),
        equals('Bearer tok'),
      );
      expect(extractHeader({'other': 'val'}, ['x-service-secret']), isNull);
    });
  });

  group('extractBearerToken', () {
    test('extracts non-empty trimmed Bearer token', () {
      expect(
        extractBearerToken({'Authorization': 'Bearer my-jwt-token'}),
        equals('my-jwt-token'),
      );
      expect(
        extractBearerToken({'authorization': 'Bearer   spaced-token  '}),
        equals('spaced-token'),
      );
    });

    test('returns null when missing, non-Bearer, or empty token', () {
      expect(extractBearerToken({}), isNull);
      expect(extractBearerToken({'Authorization': 'Basic abc123'}), isNull);
      expect(extractBearerToken({'Authorization': 'Bearer '}), isNull);
      expect(extractBearerToken({'Authorization': 'Bearer    '}), isNull);
    });
  });

  group('hasValidServiceSecret', () {
    test('validates against x-service-secret, x-api-key, and Bearer token', () {
      expect(
        hasValidServiceSecret({
          'x-service-secret': 's3cr3t',
        }, envSecret: 's3cr3t'),
        isTrue,
      );
      expect(
        hasValidServiceSecret({'X-Api-Key': 's3cr3t'}, envSecret: 's3cr3t'),
        isTrue,
      );
      expect(
        hasValidServiceSecret({
          'Authorization': 'Bearer s3cr3t',
        }, envSecret: 's3cr3t'),
        isTrue,
      );
      expect(
        hasValidServiceSecret({
          'x-service-secret': 'wrong',
        }, envSecret: 's3cr3t'),
        isFalse,
      );
      expect(
        hasValidServiceSecret({'x-service-secret': 's3cr3t'}, envSecret: ''),
        isFalse,
      );
    });
  });

  group('verifyBearerIdToken', () {
    test(
      'returns hasToken=false when Authorization Bearer token is absent',
      () async {
        final auth = MockAuthService();
        final result = await verifyBearerIdToken({}, auth: auth);
        expect(result.hasToken, isFalse);
        expect(result.isValid, isFalse);
        expect(result.decodedToken, isNull);
        expect(result.error, isNull);
        expect(auth.verifiedTokens, isEmpty);
      },
    );

    test('returns decodedToken when verification succeeds', () async {
      final auth = MockAuthService()
        ..onVerifyIdToken = (token) async => const DecodedIdToken(
              uid: 'u-42',
              email: 'u42@example.com',
              admin: true,
            );
      final result = await verifyBearerIdToken({
        'Authorization': 'Bearer valid-jwt',
      }, auth: auth);
      expect(result.hasToken, isTrue);
      expect(result.isValid, isTrue);
      expect(result.decodedToken?.uid, equals('u-42'));
      expect(result.decodedToken?.email, equals('u42@example.com'));
      expect(result.decodedToken?.admin, isTrue);
      expect(auth.verifiedTokens, equals(['valid-jwt']));
    });

    test('captures error when verifyIdToken throws', () async {
      final auth = MockAuthService()
        ..onVerifyIdToken = (token) async => throw Exception('Token expired');
      final result = await verifyBearerIdToken({
        'authorization': 'Bearer expired-jwt',
      }, auth: auth);
      expect(result.hasToken, isTrue);
      expect(result.isValid, isFalse);
      expect(result.decodedToken, isNull);
      expect(result.error, isNotNull);
    });
  });

  group('parseFlexibleTimestamp', () {
    test(
      'parses DateTime, num, numeric String, and ISO-8601 String to UTC',
      () {
        final dt = DateTime(2026, 9, 10, 12, 0);
        expect(parseFlexibleTimestamp(dt), equals(dt.toUtc()));

        const epochMs = 1725964800000;
        final expectedUtc = DateTime.fromMillisecondsSinceEpoch(
          epochMs,
          isUtc: true,
        );
        expect(parseFlexibleTimestamp(epochMs), equals(expectedUtc));
        expect(parseFlexibleTimestamp(1725964800000.0), equals(expectedUtc));
        expect(parseFlexibleTimestamp('1725964800000'), equals(expectedUtc));
        expect(
          parseFlexibleTimestamp('  1725964800000.0  '),
          equals(expectedUtc),
        );
        expect(
          parseFlexibleTimestamp('2026-09-10T10:40:00Z'),
          equals(DateTime.utc(2026, 9, 10, 10, 40)),
        );
      },
    );

    test(
      'parses Firestore-style seconds/nanoseconds Map and object methods',
      () {
        expect(
          parseFlexibleTimestamp({
            'seconds': 1725964800,
            'nanoseconds': 500000000,
          }),
          equals(
            DateTime.fromMillisecondsSinceEpoch(1725964800500, isUtc: true),
          ),
        );
        expect(
          parseFlexibleTimestamp({'_seconds': 1725964800, '_nanoseconds': 0}),
          equals(
            DateTime.fromMillisecondsSinceEpoch(1725964800000, isUtc: true),
          ),
        );
        expect(
          parseFlexibleTimestamp(
            _FakeTimestampWithToDate(DateTime.utc(2026, 9, 10)),
          ),
          equals(DateTime.utc(2026, 9, 10)),
        );
        expect(
          parseFlexibleTimestamp(_FakeTimestampWithToMillis(1725964800000)),
          equals(
            DateTime.fromMillisecondsSinceEpoch(1725964800000, isUtc: true),
          ),
        );
        expect(
          parseFlexibleTimestamp(
            _FakeTimestampWithToIsoString('2026-09-10T10:40:00.000Z'),
          ),
          equals(DateTime.utc(2026, 9, 10, 10, 40)),
        );
      },
    );

    test('returns fallback when input is null, empty, or invalid', () {
      final fallback = DateTime.utc(2026, 1, 1);
      expect(parseFlexibleTimestamp(null), isNull);
      expect(
        parseFlexibleTimestamp(null, fallback: fallback),
        equals(fallback),
      );
      expect(
        parseFlexibleTimestamp('   ', fallback: fallback),
        equals(fallback),
      );
      expect(
        parseFlexibleTimestamp('not-a-timestamp', fallback: fallback),
        equals(fallback),
      );
    });
  });

  group('commitOperationsInChunks', () {
    test('does not commit any batches when operations list is empty', () async {
      final db = MockFirestoreDatabase();
      final count = await commitOperationsInChunks(db, []);
      expect(count, equals(0));
      expect(db.committedBatches, isEmpty);
    });

    test(
      'splits operations across multiple batches according to chunkSize',
      () async {
        final db = MockFirestoreDatabase();
        final col = db.collection('items');
        final ops = List.generate(
          5,
          (i) => (WriteBatch batch) {
            batch.set(col.doc('item_$i'), {'index': i});
          },
        );

        final batchesCommitted = await commitOperationsInChunks(
          db,
          ops,
          chunkSize: 2,
        );

        expect(batchesCommitted, equals(3));
        expect(db.committedBatches.length, equals(3));
        expect(db.committedBatches[0].setOperations.length, equals(2));
        expect(db.committedBatches[1].setOperations.length, equals(2));
        expect(db.committedBatches[2].setOperations.length, equals(1));
      },
    );
  });
}

class _FakeTimestampWithToDate {
  final DateTime _dt;
  _FakeTimestampWithToDate(this._dt);
  DateTime toDate() => _dt;
}

class _FakeTimestampWithToMillis {
  final int _ms;
  _FakeTimestampWithToMillis(this._ms);
  int toMillis() => _ms;
}

class _FakeTimestampWithToIsoString {
  final String _iso;
  _FakeTimestampWithToIsoString(this._iso);
  String toISOString() => _iso;
}
