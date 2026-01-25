import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

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
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }
}
