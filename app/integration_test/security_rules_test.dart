// ignore_for_file: avoid_print, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nothing_ever_happens/firebase_options_dev.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void print(Object? object) {
  final msg = object?.toString() ?? 'null';
  try {
    html.window.console.log(msg);
  } catch (_) {}
}

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

  setUpAll(() async {
    print('[setUpAll] Initializing default FirebaseApp...');
    if (Firebase.apps.isEmpty) {
      FirebaseOptions options;
      try {
        options = DefaultFirebaseOptions.currentPlatform;
      } catch (_) {
        options = DefaultFirebaseOptions.web;
      }
      await Firebase.initializeApp(options: options);
    }
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

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
    return creds.user!;
  }

  Future<void> syncFirestoreAuth(String uid, Map<String, dynamic> data) async {
    final db = FirebaseFirestore.instance;
    int attempts = 0;
    const maxAttempts = 100;
    print('[syncFirestoreAuth] Starting sync loop for UID: $uid');
    while (attempts < maxAttempts) {
      try {
        await db.collection('users').doc(uid).set(data);
        print('[syncFirestoreAuth] Sync success for UID: $uid');
        return;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'unavailable') {
          print(
            '[syncFirestoreAuth] Attempt ${attempts + 1}/$maxAttempts failed with ${e.code}. Retrying...',
          );
          attempts++;
          await Future.delayed(const Duration(milliseconds: 150));
        } else {
          print('[syncFirestoreAuth] Unexpected FirebaseException: $e');
          rethrow;
        }
      }
    }
    throw Exception('Failed to sync Firestore auth for UID: $uid');
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
        final db = FirebaseFirestore.instance;
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;

        // Alice writes to her own profile - serves as initial sync
        await syncFirestoreAuth(aliceUid, {
          'displayName': 'Alice',
          'email': aliceEmail,
        });

        // Alice reads her own profile - should succeed
        final doc = await db
            .collection('users')
            .doc(aliceUid)
            .get(const GetOptions(source: Source.server));
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
        final db = FirebaseFirestore.instance;

        // 1. Sign in Alice and create a family
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;
        await syncFirestoreAuth(aliceUid, {
          'displayName': 'Alice',
          'email': aliceEmail,
        });

        final familyId = 'fam-${uuid.v4()}';

        // Alice creates family - should succeed
        await expectLater(
          db.collection('families').doc(familyId).set({
            'name': 'The Simpsons',
            'members': {
              aliceUid: {'role': 'parent', 'displayName': 'Alice'},
            },
          }),
          completes,
        );

        // 2. Sign in Bob (non-member)
        final bobEmail = 'bob_${uuid.v4()}@example.com';
        await signOutAndWait();
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;
        await syncFirestoreAuth(bobUid, {
          'displayName': 'Bob',
          'email': bobEmail,
        });

        // Bob tries to read the family document - should fail (permission-denied)
        await expectPermissionDenied(
          db
              .collection('families')
              .doc(familyId)
              .get(const GetOptions(source: Source.server)),
        );

        // Bob adds himself to the family (join functionality allowed in rules)
        await expectLater(
          db.collection('families').doc(familyId).update({
            'members.$bobUid': {'role': 'non-parent', 'displayName': 'Bob'},
          }),
          completes,
        );

        // Bob reads the family document now - should succeed
        final doc = await db
            .collection('families')
            .doc(familyId)
            .get(const GetOptions(source: Source.server));
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], 'The Simpsons');
      },
    );

    testWidgets(
      'Instances collection - members can create, but only parents can delete',
      (WidgetTester tester) async {
        final db = FirebaseFirestore.instance;

        // 1. Register Bob first to get his UID, then register Alice
        final bobEmail = 'bob_${uuid.v4()}@example.com';
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;
        await syncFirestoreAuth(bobUid, {
          'displayName': 'Bob',
          'email': bobEmail,
        });

        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        await signOutAndWait();
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;
        await syncFirestoreAuth(aliceUid, {
          'displayName': 'Alice',
          'email': aliceEmail,
        });

        final familyId = 'fam-${uuid.v4()}';

        // Alice creates family with Alice as parent and Bob as non-parent
        await expectLater(
          db.collection('families').doc(familyId).set({
            'name': 'The Simpsons',
            'members': {
              aliceUid: {'role': 'parent', 'displayName': 'Alice'},
              bobUid: {'role': 'non-parent', 'displayName': 'Bob'},
            },
          }),
          completes,
        );

        // 2. Sign in Bob (non-parent member)
        await signOutAndWait();
        await registerAndSignIn(bobEmail, 'password123');
        await syncFirestoreAuth(bobUid, {
          'displayName': 'Bob',
          'email': bobEmail,
        });

        final instanceId = 'inst-${uuid.v4()}';

        // Bob (non-parent member) creates an instance - should succeed
        await expectLater(
          db
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .doc(instanceId)
              .set({'title': 'Clean room'}),
          completes,
        );

        // Bob tries to delete the instance - should fail (permission-denied)
        await expectPermissionDenied(
          db
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .doc(instanceId)
              .delete(),
        );

        // 3. Sign in Alice (parent)
        await signOutAndWait();
        await registerAndSignIn(aliceEmail, 'password123');
        await syncFirestoreAuth(aliceUid, {
          'displayName': 'Alice',
          'email': aliceEmail,
        });

        // Alice (parent) deletes the instance - should succeed
        await expectLater(
          db
              .collection('families')
              .doc(familyId)
              .collection('instances')
              .doc(instanceId)
              .delete(),
          completes,
        );
      },
    );
  });
}
