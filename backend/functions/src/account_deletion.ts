import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export interface AuthenticatedUser {
  uid: string;
  email?: string;
}

export interface AuthValidationResult {
  authenticated: boolean;
  status?: number;
  error?: string;
  user?: AuthenticatedUser;
}

export interface AccountDeletionResult {
  success: boolean;
  message: string;
  userId: string;
}

/**
 * Authenticates an incoming request using a Firebase Auth ID Token in the Authorization Bearer header.
 */
export async function authenticateUserRequest(
  headers: Record<string, string | string[] | undefined>,
  auth?: admin.auth.Auth
): Promise<AuthValidationResult> {
  const authHeaderRaw = headers["authorization"] || headers["Authorization"];
  const authHeader = Array.isArray(authHeaderRaw) ? authHeaderRaw[0] : authHeaderRaw;

  if (typeof authHeader === "string" && authHeader.startsWith("Bearer ")) {
    const idToken = authHeader.substring(7).trim();
    if (idToken) {
      try {
        const firebaseAuth = auth || (admin.apps.length > 0 ? admin.auth() : undefined);
        if (!firebaseAuth) {
          return {
            authenticated: false,
            status: 401,
            error: "Unauthorized: Authentication provider unavailable.",
          };
        }
        const decodedToken = await firebaseAuth.verifyIdToken(idToken);
        return {
          authenticated: true,
          user: {
            uid: decodedToken.uid,
            email: decodedToken.email,
          },
        };
      } catch (err: unknown) {
        return {
          authenticated: false,
          status: 401,
          error: "Unauthorized: Invalid or expired authentication token.",
        };
      }
    }
  }

  return {
    authenticated: false,
    status: 401,
    error: "Unauthorized: Missing or invalid Authorization header.",
  };
}

/**
 * Executes cascading deletion of user Firestore data, family membership, pending invites, and Auth profile.
 */
export async function deleteUserAccountData(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth,
  userId: string,
  userEmail?: string
): Promise<AccountDeletionResult> {
  // 1. Fetch user doc to discover familyId and profile data before deletion
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.exists ? userDoc.data() : undefined;
  const familyId = userData?.familyId;
  const email = userEmail || userData?.email;

  // 2. Family membership cleanup
  if (familyId && typeof familyId === "string" && familyId.trim().length > 0) {
    const familyRef = db.collection("families").doc(familyId);
    const familyDoc = await familyRef.get();
    if (familyDoc.exists) {
      const familyData = familyDoc.data() || {};
      const members = (familyData.members || {}) as Record<string, unknown>;
      const remainingMemberIds = Object.keys(members).filter((mId) => mId !== userId);

      if (remainingMemberIds.length === 0) {
        // Sole member: recursively delete the family document and all subcollections
        if (typeof db.recursiveDelete === "function") {
          await db.recursiveDelete(familyRef);
        } else {
          await familyRef.delete();
        }
      } else {
        // Multi-member family: remove user from members map
        await familyRef.update({
          [`members.${userId}`]: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }

  // 3. Invites cleanup (where toEmail or fromEmail matches)
  if (email && typeof email === "string" && email.trim().length > 0) {
    const normalizedEmail = email.trim().toLowerCase();
    const [toSnap, fromSnap] = await Promise.all([
      db.collection("invites").where("toEmail", "==", normalizedEmail).get(),
      db.collection("invites").where("fromEmail", "==", normalizedEmail).get(),
    ]);

    const batch = db.batch();
    let count = 0;
    const seenIds = new Set<string>();

    toSnap.docs.forEach((doc) => {
      if (!seenIds.has(doc.id)) {
        seenIds.add(doc.id);
        batch.delete(doc.ref);
        count++;
      }
    });

    fromSnap.docs.forEach((doc) => {
      if (!seenIds.has(doc.id)) {
        seenIds.add(doc.id);
        batch.delete(doc.ref);
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
    }
  }

  // 4. User data cleanup: purge user document and all subcollections
  if (typeof db.recursiveDelete === "function") {
    await db.recursiveDelete(userRef);
  } else {
    await userRef.delete();
  }

  // 5. Firebase Auth record deletion
  try {
    await auth.deleteUser(userId);
  } catch (err: unknown) {
    const errorObj = err as { code?: string };
    if (errorObj?.code !== "auth/user-not-found") {
      throw err;
    }
  }

  return {
    success: true,
    message: "Account and associated data successfully deleted",
    userId,
  };
}

/**
 * HTTP Handler for processing account deletion requests.
 */
export async function handleDeleteUserAccount(
  req: { method: string; headers: Record<string, string | string[] | undefined> },
  res: { status: (code: number) => { json: (data: unknown) => void } },
  db?: admin.firestore.Firestore,
  auth?: admin.auth.Auth
): Promise<void> {
  if (req.method !== "POST" && req.method !== "DELETE") {
    res.status(405).json({ success: false, error: "Method Not Allowed. Use POST or DELETE." });
    return;
  }

  const firestoreDb = db || (admin.apps.length > 0 ? admin.firestore() : (undefined as unknown as admin.firestore.Firestore));
  const firebaseAuth = auth || (admin.apps.length > 0 ? admin.auth() : undefined);

  const authResult = await authenticateUserRequest(req.headers, firebaseAuth);
  if (!authResult.authenticated || !authResult.user) {
    logger.warn("Unauthorized account deletion attempt:", authResult.error);
    res.status(authResult.status || 401).json({ success: false, error: authResult.error });
    return;
  }

  if (!firestoreDb || !firebaseAuth) {
    logger.error("Firestore or Auth service unavailable");
    res.status(500).json({ success: false, error: "Firebase services unavailable" });
    return;
  }

  try {
    const result = await deleteUserAccountData(
      firestoreDb,
      firebaseAuth,
      authResult.user.uid,
      authResult.user.email
    );
    logger.info(`Successfully deleted account for user: ${authResult.user.uid}`);
    res.status(200).json(result);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error(`Error deleting account for user ${authResult.user.uid}:`, error);
    res.status(500).json({ success: false, error: errorMessage });
  }
}
