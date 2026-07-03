// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nothing_ever_happens/firebase_options_dev.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String projectId = 'nothing-ever-happens-dev';
  final uuid = const Uuid();

  Future<void> clearFirestoreEmulator(String projectId) async {
    final url =
        'http://localhost:8080/emulator/v1/projects/$projectId/databases/(default)/documents';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to clear Firestore emulator: ${response.body}');
    }
  }

  Future<void> clearAuthEmulator(String projectId) async {
    final url =
        'http://localhost:9099/emulator/v1/projects/$projectId/accounts';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to clear Auth emulator: ${response.body}');
    }
  }

  setUpAll(() async {
    print('[setUpAll] Initializing Firebase...');
    if (Firebase.apps.isEmpty) {
      FirebaseOptions options;
      try {
        options = DefaultFirebaseOptions.currentPlatform;
      } catch (_) {
        // Fallback to web options for unsupported platforms (like Linux desktop)
        options = DefaultFirebaseOptions.web;
      }
      await Firebase.initializeApp(options: options);
    }
    // Configure client SDKs to use the local emulators
    print('[setUpAll] Configuring emulators...');
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    print('[setUpAll] Emulators configured.');
  });

  Future<void> signOutAndWait() async {
    print('[signOutAndWait] Signing out...');
    await FirebaseAuth.instance.signOut();
    print('[signOutAndWait] Waiting for authStateChanges to emit null...');
    await FirebaseAuth.instance.authStateChanges().firstWhere(
      (user) => user == null,
    );
    print('[signOutAndWait] Sign out complete.');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  setUp(() async {
    print('[setUp] Starting setup...');
    print('[setUp] Clearing Firestore emulator...');
    await clearFirestoreEmulator(projectId);
    print('[setUp] Clearing Auth emulator...');
    await clearAuthEmulator(projectId);
    await signOutAndWait();
    print('[setUp] Setup complete.');
  });

  Future<User> registerAndSignIn(String email, String password) async {
    print('[registerAndSignIn] Starting for email: $email');
    final auth = FirebaseAuth.instance;
    UserCredential creds;
    try {
      print('[registerAndSignIn] Creating user...');
      creds = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('[registerAndSignIn] User created: ${creds.user?.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print(
          '[registerAndSignIn] Email already in use. Signing in instead...',
        );
        creds = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('[registerAndSignIn] Signed in user: ${creds.user?.uid}');
      } else {
        print('[registerAndSignIn] FirebaseAuthException: $e');
        rethrow;
      }
    }

    // Wait for auth state changes to propagate in FirebaseAuth
    print('[registerAndSignIn] Waiting for authStateChanges to propagate...');
    await auth.authStateChanges().firstWhere(
      (user) => user?.uid == creds.user?.uid,
    );
    print('[registerAndSignIn] authStateChanges propagated.');

    // Wait for Firestore to synchronize with the new credentials
    final db = FirebaseFirestore.instance;
    int attempts = 0;
    const maxAttempts =
        100; // Increased to 100 to allow plenty of time for slow virtualized CI environments
    print('[registerAndSignIn] Starting Firestore synchronization loop...');
    while (attempts < maxAttempts) {
      try {
        print(
          '[registerAndSignIn] Attempt ${attempts + 1}/$maxAttempts: Reading user document...',
        );
        final doc = await db.collection('users').doc(creds.user!.uid).get();
        print(
          '[registerAndSignIn] Success! Firestore auth is synchronized (doc exists: ${doc.exists}).',
        );
        break; // Success! Firestore auth is synchronized.
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          print(
            '[registerAndSignIn] Attempt ${attempts + 1}/$maxAttempts: Firestore returned permission-denied. Retrying...',
          );
          attempts++;
          await Future.delayed(const Duration(milliseconds: 150));
        } else {
          print('[registerAndSignIn] Unexpected FirebaseException: $e');
          rethrow;
        }
      } catch (e) {
        print('[registerAndSignIn] Unexpected exception: $e');
        rethrow;
      }
    }
    if (attempts >= maxAttempts) {
      print(
        '[registerAndSignIn] ERROR: Firestore auth failed to synchronize after $maxAttempts attempts.',
      );
      throw Exception(
        'Firestore auth failed to sync for UID: ${creds.user!.uid}',
      );
    }

    // Add extra settling delay after Firestore sync to prevent auth races
    await Future.delayed(const Duration(milliseconds: 500));

    return creds.user!;
  }

  Future<void> expectPermissionDenied(Future<dynamic> functionCall) async {
    print('[expectPermissionDenied] Executing operation...');
    try {
      await functionCall;
      print(
        '[expectPermissionDenied] ERROR: Operation succeeded but should have failed.',
      );
      fail('Expected permission-denied but operation succeeded.');
    } on FirebaseException catch (e) {
      print(
        '[expectPermissionDenied] Caught FirebaseException with code: ${e.code}',
      );
      expect(e.code, 'permission-denied');
    } catch (e) {
      print('[expectPermissionDenied] ERROR: Caught unexpected exception: $e');
      fail('Expected FirebaseException with permission-denied but got: $e');
    }
  }

  group('Firestore Security Rules - Integration Tests', () {
    testWidgets(
      'Users collection - allows reading/writing own profile and denies writing others',
      (WidgetTester tester) async {
        // 1. Sign in Alice
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;

        final db = FirebaseFirestore.instance;

        // Alice writes to her own profile - should succeed
        await expectLater(
          db.collection('users').doc(aliceUid).set({
            'displayName': 'Alice',
            'email': aliceEmail,
          }),
          completes,
        );

        // Alice reads her own profile - should succeed
        final doc = await db.collection('users').doc(aliceUid).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], 'Alice');

        // Alice tries to write to Bob's profile - should fail (permission-denied)
        await expectPermissionDenied(
          db.collection('users').doc('bob-uid').set({
            'displayName': 'Bob Clone',
          }),
        );
      },
    );

    testWidgets(
      'Families collection - allows members to read and joining users to add themselves',
      (WidgetTester tester) async {
        print('[FamiliesTest] 1. Sign in Alice and create a family...');
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;

        final db = FirebaseFirestore.instance;
        final familyId = 'fam-${uuid.v4()}';

        print('[FamiliesTest] Alice creating family document...');
        await expectLater(
          db.collection('families').doc(familyId).set({
            'name': 'The Simpsons',
            'members': {
              aliceUid: {'role': 'parent', 'displayName': 'Alice'},
            },
          }),
          completes,
        );

        print('[FamiliesTest] 2. Sign in Bob (non-member)...');
        final bobEmail = 'bob_${uuid.v4()}@example.com';
        await signOutAndWait();
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;

        print(
          '[FamiliesTest] Bob trying to read family document (expect deny)...',
        );
        await expectPermissionDenied(
          db.collection('families').doc(familyId).get(),
        );

        print(
          '[FamiliesTest] Bob adding himself to the family (expect allow)...',
        );
        await expectLater(
          db.collection('families').doc(familyId).update({
            'members.$bobUid': {'role': 'non-parent', 'displayName': 'Bob'},
          }),
          completes,
        );

        print(
          '[FamiliesTest] Bob reading the family document now (expect allow)...',
        );
        // Small delay to let update resolve in Firestore indexes
        await Future.delayed(const Duration(milliseconds: 200));
        final doc = await db.collection('families').doc(familyId).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], 'The Simpsons');
      },
    );

    testWidgets(
      'Instances collection - members can create, but only parents can delete',
      (WidgetTester tester) async {
        // 1. Sign in Alice (parent)
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;

        final db = FirebaseFirestore.instance;
        final familyId = 'fam-${uuid.v4()}';

        // Alice creates family with Alice as parent and Bob as non-parent
        final bobEmail = 'bob_${uuid.v4()}@example.com';
        // We need Bob's UID to add him. We'll register Bob first to get his UID, then register Alice.
        await signOutAndWait();
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;

        await signOutAndWait();
        await registerAndSignIn(aliceEmail, 'password123');

        await db.collection('families').doc(familyId).set({
          'name': 'The Simpsons',
          'members': {
            aliceUid: {'role': 'parent', 'displayName': 'Alice'},
            bobUid: {'role': 'non-parent', 'displayName': 'Bob'},
          },
        });

        // 2. Sign in Bob (non-parent member)
        await signOutAndWait();
        await registerAndSignIn(bobEmail, 'password123');

        final instanceId = 'inst-${uuid.v4()}';
        final instanceDocRef = db
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .doc(instanceId);

        // Bob (non-parent member) creates an instance - should succeed
        await expectLater(
          instanceDocRef.set({'title': 'Clean room'}),
          completes,
        );

        // Bob tries to delete the instance - should fail (permission-denied)
        await expectPermissionDenied(instanceDocRef.delete());

        // 3. Sign in Alice (parent)
        await signOutAndWait();
        await registerAndSignIn(aliceEmail, 'password123');

        // Alice (parent) deletes the instance - should succeed
        await expectLater(instanceDocRef.delete(), completes);
      },
    );
  });
}
