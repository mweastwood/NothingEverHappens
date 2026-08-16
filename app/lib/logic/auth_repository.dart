import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nothing_ever_happens/main.dart';
import 'app_logger.dart';
import 'hive_local_data_source.dart';
import 'notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    logger: ref.watch(appLoggerProvider),
    localDataSource: ref.watch(hiveLocalDataSourceProvider),
    notificationService: ref.watch(notificationServiceProvider),
  ),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppLogger? _logger;
  final HiveLocalDataSource? _localDataSource;
  final NotificationService? _notificationService;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppLogger? logger,
    HiveLocalDataSource? localDataSource,
    NotificationService? notificationService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _logger = logger,
       _localDataSource = localDataSource,
       _notificationService = notificationService;

  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      final User? user;
      if (kIsWeb) {
        // On Web, use the FirebaseAuth popup directly
        final UserCredential userCredential = await _firebaseAuth
            .signInWithPopup(GoogleAuthProvider());
        user = userCredential.user;
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
        user = userCredential.user;
      }
      _logger?.info(
        'auth',
        'Google sign-in succeeded',
        data: {'uid': user?.uid},
      );
      return user;
    } catch (e) {
      _logger?.error('auth', 'Google sign-in failed', error: e);
      if (!kIsWeb &&
          e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        // Log details to console to assist development/diagnostics
        debugPrint('Google Sign-In canceled catch block triggered:');
        debugPrint('  Error: $e');
        debugPrint('  Description: ${e.description}');
        debugPrint('  Details: ${e.details}');

        // Throw a descriptive exception so the user/developer is informed
        // that a cancellation code can represent a signing certificate/SHA-1 mismatch.
        throw GoogleSignInException(
          code: e.code,
          description:
              'Sign-in was canceled or failed due to configuration. If you selected '
              'an account and this happened, it is likely due to a developer configuration '
              'mismatch (e.g., missing SHA-1 signature fingerprint in the Firebase Console '
              'for your debug or release signing key).',
          details: e.details,
        );
      }
      // Handle other errors (log it, rethrow it, etc.)
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInAnonymously();
      _logger?.info(
        'auth',
        'Anonymous sign-in succeeded',
        data: {'uid': userCredential.user?.uid},
      );
      return userCredential.user;
    } catch (e) {
      _logger?.error('auth', 'Anonymous sign-in failed', error: e);
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _logger?.info('auth', 'User signing out');
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _localDataSource?.resetAllData();
    await _notificationService?.cancelAllNotifications();
  }
}
