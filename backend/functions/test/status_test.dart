import 'package:functions/src/handlers/status.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:test/test.dart';

void main() {
  group('status endpoint', () {
    test('getStatusPayload returns valid schema and status', () {
      final fixedTime = DateTime.parse('2026-08-30T12:00:00Z');
      final payload = getStatusPayload(now: fixedTime);

      expect(payload['status'], equals('ok'));
      expect(
          payload['service'], equals('Nothing Ever Happens Cloud Functions'));
      expect(payload['version'], equals('1.0.0'));
      expect(payload['timestamp'], equals('2026-08-30T12:00:00.000Z'));
    });

    test('handleStatus sets HTTP status 200 and JSON body', () async {
      final req = TestHttpRequest(method: 'GET');
      final res = TestHttpResponse();

      await handleStatus(req, res);

      expect(res.statusCode, equals(200));
      expect(res.responseData, isA<Map<String, dynamic>>());
      final data = res.responseData as Map<String, dynamic>;
      expect(data['status'], equals('ok'));
      expect(data['service'], equals('Nothing Ever Happens Cloud Functions'));
      expect(data['version'], equals('1.0.0'));
      expect(DateTime.tryParse(data['timestamp'] as String), isNotNull);
    });
  });
}
