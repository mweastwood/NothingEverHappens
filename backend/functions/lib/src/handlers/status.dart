import '../interop/firebase_functions.dart';

Map<String, dynamic> getStatusPayload({DateTime? now}) {
  return {
    'status': 'ok',
    'service': 'Nothing Ever Happens Cloud Functions',
    'version': '1.0.0',
    'timestamp': (now ?? DateTime.now().toUtc()).toIso8601String(),
  };
}

Future<void> handleStatus(HttpRequest req, HttpResponse res) async {
  res.status(200).json(getStatusPayload());
}
