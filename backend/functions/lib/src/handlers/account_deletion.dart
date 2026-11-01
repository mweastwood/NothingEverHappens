import '../interop/firebase_admin.dart';
import '../interop/firebase_functions.dart';
import '../interop/node_interop.dart';
import '../models/account_deletion.dart';
import 'auth_helpers.dart';

/// Authenticates an incoming request using a Firebase Auth ID Token in the Authorization Bearer header.
Future<AccountDeletionAuthResult> authenticateUserRequest(
  Map<String, dynamic> headers, {
  AuthService? auth,
}) async {
  final idToken = extractBearerToken(headers);
  if (idToken != null) {
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
  var familyWasDeleted = false;
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
        familyWasDeleted = true;
      } else {
        // Multi-member family: unassign tasks and instances assigned to the departing user
        final assignedResults = await Future.wait([
          familyRef
              .collection('tasks')
              .where('assignedUserId', '==', userId)
              .get(),
          familyRef
              .collection('instances')
              .where('assignedUserId', '==', userId)
              .get(),
        ]);
        final assignedDocs = [
          ...assignedResults[0].docs,
          ...assignedResults[1].docs,
        ];
        if (assignedDocs.isNotEmpty) {
          final nowUtc = DateTime.now().toUtc();
          const chunkSize = 499;
          for (var i = 0; i < assignedDocs.length; i += chunkSize) {
            final batch = db.batch();
            final end = (i + chunkSize < assignedDocs.length)
                ? i + chunkSize
                : assignedDocs.length;
            for (var j = i; j < end; j++) {
              batch.update(assignedDocs[j].ref, {
                'assignedUserId': null,
                'updatedAt': nowUtc,
              });
            }
            await batch.commit();
          }
        }

        // Remove user from members map and promote a successor parent if needed
        final updates = <String, dynamic>{
          'members.$userId': FieldValue.delete(),
        };
        final departingMember = members[userId] as Map?;
        final isDepartingParent = departingMember?['role'] == 'parent';
        if (isDepartingParent) {
          final hasOtherParent = remainingMemberIds.any((mId) {
            final member = members[mId] as Map?;
            return member?['role'] == 'parent';
          });
          if (!hasOtherParent) {
            final nextParentId = remainingMemberIds.first.toString();
            updates['members.$nextParentId.role'] = 'parent';
            final nextParentUserRef = db.collection('users').doc(nextParentId);
            final nextParentUserDoc = await nextParentUserRef.get();
            if (nextParentUserDoc.exists) {
              await nextParentUserRef.update({'familyRole': 'parent'});
            }
          }
        }
        await familyRef.update(updates);
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

    final docsToDelete = <DocumentSnapshot>[];
    final seenIds = <String>{};

    for (final doc in toSnap.docs) {
      if (seenIds.add(doc.id)) {
        docsToDelete.add(doc);
      }
    }
    for (final doc in fromSnap.docs) {
      final invFamilyId = doc.data()?['familyId'] as String?;
      // Only delete outgoing family invites if the family itself was deleted or does not match an active remaining family
      if (familyWasDeleted ||
          familyId == null ||
          familyId.trim().isEmpty ||
          invFamilyId != familyId) {
        if (seenIds.add(doc.id)) {
          docsToDelete.add(doc);
        }
      }
    }

    if (docsToDelete.isNotEmpty) {
      const chunkSize = 499;
      for (var i = 0; i < docsToDelete.length; i += chunkSize) {
        final batch = db.batch();
        final end = (i + chunkSize < docsToDelete.length)
            ? i + chunkSize
            : docsToDelete.length;
        for (var j = i; j < end; j++) {
          batch.delete(docsToDelete[j].ref);
        }
        await batch.commit();
      }
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
    res.status(405).json({
      'success': false,
      'error': 'Method Not Allowed. Use POST or DELETE.',
    });
    return;
  }

  final authResult = await authenticateUserRequest(req.headers, auth: auth);
  if (!authResult.authenticated || authResult.user == null) {
    logWarn('Unauthorized account deletion attempt: ${authResult.error}');
    res.status(authResult.status ?? 401).json({
      'success': false,
      'error': authResult.error,
    });
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
