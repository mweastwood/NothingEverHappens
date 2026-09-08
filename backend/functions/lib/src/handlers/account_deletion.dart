import '../interop/firebase_admin.dart';
import '../interop/firebase_functions.dart';
import '../interop/node_interop.dart';
import '../models/account_deletion.dart';

/// Authenticates an incoming request using a Firebase Auth ID Token in the Authorization Bearer header.
Future<AccountDeletionAuthResult> authenticateUserRequest(
  Map<String, dynamic> headers, {
  AuthService? auth,
}) async {
  final authHeaderRaw = headers['authorization'] ?? headers['Authorization'];
  final authHeader = authHeaderRaw is List
      ? (authHeaderRaw.isNotEmpty ? authHeaderRaw.first.toString() : null)
      : authHeaderRaw?.toString();

  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final idToken = authHeader.substring(7).trim();
    if (idToken.isNotEmpty) {
      try {
        final firebaseAuth = auth ?? getFirebaseAdminAuth();
        final decodedToken = await firebaseAuth.verifyIdToken(idToken);
        return AccountDeletionAuthResult(
          authenticated: true,
          user: AuthenticatedUser(
            uid: decodedToken.uid,
            email: decodedToken.email,
          ),
        );
      } catch (_) {
        return const AccountDeletionAuthResult(
          authenticated: false,
          status: 401,
          error: 'Unauthorized: Invalid or expired authentication token.',
        );
      }
    }
  }

  return const AccountDeletionAuthResult(
    authenticated: false,
    status: 401,
    error: 'Unauthorized: Missing or invalid Authorization header.',
  );
}

/// Executes cascading deletion of user Firestore data, family membership, pending invites, and Auth profile.
Future<AccountDeletionResult> deleteUserAccountData(
  FirestoreDatabase db,
  AuthService auth,
  String userId, {
  String? userEmail,
}) async {
  // 1. Fetch user doc to discover familyId and profile data before deletion
  final userRef = db.collection('users').doc(userId);
  final userDoc = await userRef.get();
  final userData = userDoc.exists ? userDoc.data() : null;
  final familyId = userData?['familyId'] as String?;
  final email = userEmail ?? (userData?['email'] as String?);

  // 2. Family membership cleanup
  if (familyId != null && familyId.trim().isNotEmpty) {
    final familyRef = db.collection('families').doc(familyId);
    final familyDoc = await familyRef.get();
    if (familyDoc.exists) {
      final familyData = familyDoc.data() ?? {};
      final members = (familyData['members'] as Map?) ?? {};
      final remainingMemberIds =
          members.keys.where((mId) => mId != userId).toList();

      if (remainingMemberIds.isEmpty) {
        // Sole member: recursively delete the family document and all subcollections
        await db.recursiveDelete(familyRef);
      } else {
        // Multi-member family: remove user from members map
        await familyRef.update({
          'members.$userId': FieldValue.delete(),
        });
      }
    }
  }

  // 3. Invites cleanup (where toEmail or fromEmail matches)
  if (email != null && email.trim().isNotEmpty) {
    final normalizedEmail = email.trim().toLowerCase();
    final results = await Future.wait([
      db.collection('invites').where('toEmail', '==', normalizedEmail).get(),
      db.collection('invites').where('fromEmail', '==', normalizedEmail).get(),
    ]);
    final toSnap = results[0];
    final fromSnap = results[1];

    final batch = db.batch();
    var count = 0;
    final seenIds = <String>{};

    for (final doc in [...toSnap.docs, ...fromSnap.docs]) {
      if (!seenIds.contains(doc.id)) {
        seenIds.add(doc.id);
        batch.delete(doc.ref);
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  // 4. User data cleanup: purge user document and all subcollections
  await db.recursiveDelete(userRef);

  // 5. Firebase Auth record deletion
  try {
    await auth.deleteUser(userId);
  } catch (err) {
    if (err is FirebaseAuthException && err.code == 'auth/user-not-found') {
      // Ignored: already deleted
    } else if (err.toString().contains('auth/user-not-found')) {
      // Ignored: already deleted
    } else {
      rethrow;
    }
  }

  return AccountDeletionResult(
    success: true,
    message: 'Account and associated data successfully deleted',
    userId: userId,
  );
}

/// HTTP Handler for processing account deletion requests.
Future<void> handleDeleteUserAccount(
  HttpRequest req,
  HttpResponse res, {
  FirestoreDatabase? db,
  AuthService? auth,
}) async {
  if (req.method != 'POST' && req.method != 'DELETE') {
    res.status(405).json(
        {'success': false, 'error': 'Method Not Allowed. Use POST or DELETE.'});
    return;
  }

  final authResult = await authenticateUserRequest(req.headers, auth: auth);
  if (!authResult.authenticated || authResult.user == null) {
    logWarn('Unauthorized account deletion attempt: ${authResult.error}');
    res
        .status(authResult.status ?? 401)
        .json({'success': false, 'error': authResult.error});
    return;
  }

  try {
    final firestoreDb = db ?? getFirebaseAdminDb();
    final firebaseAuth = auth ?? getFirebaseAdminAuth();

    final result = await deleteUserAccountData(
      firestoreDb,
      firebaseAuth,
      authResult.user!.uid,
      userEmail: authResult.user!.email,
    );
    logInfo('Successfully deleted account for user: ${authResult.user!.uid}');
    res.status(200).json(result.toJson());
  } catch (error) {
    final errorMessage = error.toString().replaceFirst('Exception: ', '');
    logError('Error deleting account for user ${authResult.user?.uid}:', error);
    res.status(500).json({'success': false, 'error': errorMessage});
  }
}
