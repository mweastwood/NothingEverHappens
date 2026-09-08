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
