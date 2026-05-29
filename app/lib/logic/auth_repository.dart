import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nothing_ever_happens/main.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On Web, use the FirebaseAuth popup directly
        final UserCredential userCredential = await _firebaseAuth
            .signInWithPopup(GoogleAuthProvider());
        return userCredential.user;
      } else {
        if (!_googleSignInInitialized) {
          final String serverClientId =
              AppConfig.environment == AppEnvironment.prod
              ? '936469690744-8bthibeb317ifso2jc25ra9jmlaggdac.apps.googleusercontent.com'
              : '631207034652-91uutp0kkbmaaltqlg5858et5pal7era.apps.googleusercontent.com';
          await _googleSignIn.initialize(serverClientId: serverClientId);
          _googleSignInInitialized = true;
        }

        // On Mobile, use the native Google Sign In flow
        // GoogleSignIn 7.x uses authenticate() instead of signIn()
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          // accessToken is no longer directly available or needed for basic auth
        );

        final UserCredential userCredential = await _firebaseAuth
            .signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      if (!kIsWeb &&
          e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        // User canceled the sign-in flow
        return null;
      }
      // Handle other errors (log it, rethrow it, etc.)
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }
}
