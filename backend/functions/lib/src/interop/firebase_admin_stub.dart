export 'abstract_admin.dart';
import 'abstract_admin.dart';

FirestoreDatabase getFirebaseAdminDb([dynamic jsDb]) {
  throw UnsupportedError(
      'Firebase Admin JS is only available when compiled to JS.');
}

AuthService getFirebaseAdminAuth() {
  throw UnsupportedError(
      'Firebase Admin JS is only available when compiled to JS.');
}

void initializeFirebaseAdmin() {
  // No-op on VM stub
}

Future<T> safePromiseToFuture<T>(dynamic jsPromiseOrObject) {
  if (jsPromiseOrObject == null) {
    throw StateError(
      'Expected a JavaScript Promise/thenable but received object without a "then" method: null',
    );
  }
  if (jsPromiseOrObject is Future<T>) {
    return jsPromiseOrObject;
  }
  if (jsPromiseOrObject is Future) {
    return jsPromiseOrObject.then((v) => v as T);
  }
  throw StateError(
    'Expected a JavaScript Promise/thenable but received object without a "then" method: $jsPromiseOrObject',
  );
}
