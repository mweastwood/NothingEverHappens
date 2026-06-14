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
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  setUp(() async {
    await clearFirestoreEmulator(projectId);
    await clearAuthEmulator(projectId);
    await FirebaseAuth.instance.signOut();
  });

  Future<User> registerAndSignIn(String email, String password) async {
    final auth = FirebaseAuth.instance;
    try {
      final creds = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return creds.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final creds = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return creds.user!;
      } else {
        rethrow;
      }
    }
  }

  Future<void> expectPermissionDenied(Future<dynamic> functionCall) async {
    try {
      await functionCall;
      fail('Expected permission-denied but operation succeeded.');
    } on FirebaseException catch (e) {
      expect(e.code, 'permission-denied');
    } catch (e) {
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
        // 1. Sign in Alice and create a family
        final aliceEmail = 'alice_${uuid.v4()}@example.com';
        final aliceUser = await registerAndSignIn(aliceEmail, 'password123');
        final aliceUid = aliceUser.uid;

        final db = FirebaseFirestore.instance;
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
        await FirebaseAuth.instance.signOut();
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;

        // Bob tries to read the family document - should fail (permission-denied)
        await expectPermissionDenied(
          db.collection('families').doc(familyId).get(),
        );

        // Bob adds himself to the family (join functionality allowed in rules)
        await expectLater(
          db.collection('families').doc(familyId).update({
            'members.$bobUid': {'role': 'non-parent', 'displayName': 'Bob'},
          }),
          completes,
        );

        // Bob reads the family document now - should succeed
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
        await FirebaseAuth.instance.signOut();
        final bobUser = await registerAndSignIn(bobEmail, 'password123');
        final bobUid = bobUser.uid;

        await FirebaseAuth.instance.signOut();
        await registerAndSignIn(aliceEmail, 'password123');

        await db.collection('families').doc(familyId).set({
          'name': 'The Simpsons',
          'members': {
            aliceUid: {'role': 'parent', 'displayName': 'Alice'},
            bobUid: {'role': 'non-parent', 'displayName': 'Bob'},
          },
        });

        // 2. Sign in Bob (non-parent member)
        await FirebaseAuth.instance.signOut();
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
        await FirebaseAuth.instance.signOut();
        await registerAndSignIn(aliceEmail, 'password123');

        // Alice (parent) deletes the instance - should succeed
        await expectLater(instanceDocRef.delete(), completes);
      },
    );
  });
}
