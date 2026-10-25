import 'package:functions/src/handlers/auth_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('extractHeader', () {
    test('returns exact key match and unwraps List values', () {
      expect(
        extractHeader({'x-api-key': 'secret-1'}, ['x-api-key']),
        equals('secret-1'),
      );
      expect(
        extractHeader({
          'x-api-key': ['first-val', 'second-val'],
        }, [
          'x-api-key'
        ]),
        equals('first-val'),
      );
      expect(
        extractHeader({'x-api-key': <String>[]}, ['x-api-key']),
        isNull,
      );
    });

    test('matches case-insensitively when exact key is absent', () {
      expect(
        extractHeader({'X-Service-Secret': 'sec'}, ['x-service-secret']),
        equals('sec'),
      );
      expect(
        extractHeader({
          'Authorization': ['Bearer tok'],
        }, [
          'authorization'
        ]),
        equals('Bearer tok'),
      );
      expect(
        extractHeader({'other': 'val'}, ['x-service-secret']),
        isNull,
      );
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
        hasValidServiceSecret(
          {'x-service-secret': 's3cr3t'},
          envSecret: 's3cr3t',
        ),
        isTrue,
      );
      expect(
        hasValidServiceSecret(
          {'X-Api-Key': 's3cr3t'},
          envSecret: 's3cr3t',
        ),
        isTrue,
      );
      expect(
        hasValidServiceSecret(
          {'Authorization': 'Bearer s3cr3t'},
          envSecret: 's3cr3t',
        ),
        isTrue,
      );
      expect(
        hasValidServiceSecret(
          {'x-service-secret': 'wrong'},
          envSecret: 's3cr3t',
        ),
        isFalse,
      );
      expect(
        hasValidServiceSecret(
          {'x-service-secret': 's3cr3t'},
          envSecret: '',
        ),
        isFalse,
      );
    });
  });
}
