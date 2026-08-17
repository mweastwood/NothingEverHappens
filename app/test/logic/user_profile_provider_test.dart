import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_profile_provider.dart';

import 'user_profile_provider_test.mocks.dart';

@GenerateMocks([User])
void main() {
  group('extractFirstName helper', () {
    test('extracts single name', () {
      expect(extractFirstName('Alice'), 'Alice');
    });

    test('extracts first name from multi-word string', () {
      expect(extractFirstName('Alice Smith'), 'Alice');
      expect(extractFirstName('John Michael Doe'), 'John');
    });

    test('handles leading and trailing whitespace', () {
      expect(extractFirstName('   Sarah Connor   '), 'Sarah');
    });

    test('extracts name from email address', () {
      expect(extractFirstName('bob.jones@example.com'), 'bob');
      expect(extractFirstName('alice_smith@domain.org'), 'alice');
      expect(extractFirstName('john-doe@company.net'), 'john');
      expect(extractFirstName('simple@example.com'), 'simple');
    });

    test('falls back to User for empty, whitespace, or invalid inputs', () {
      expect(extractFirstName(''), 'User');
      expect(extractFirstName('   '), 'User');
      expect(extractFirstName('@example.com'), 'User');
    });
  });

  group('userNameProvider', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('resolves from family member displayName', () async {
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(fakeFirestore),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          familyProfileStreamProvider.overrideWith(
            (ref) => Stream.value(
              const FamilyProfile(familyId: 'fam-1', familyRole: 'parent'),
            ),
          ),
          familyStreamProvider('fam-1').overrideWith(
            (ref) => Stream.value(
              const Family(
                id: 'fam-1',
                name: 'Smiths',
                members: {
                  'user-1': FamilyMember(
                    userId: 'user-1',
                    displayName: 'Alice Smith',
                    email: 'alice@example.com',
                    role: FamilyRole.parent,
                  ),
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(userNameProvider('user-1').future);
      expect(result, 'Alice');
    });

    test(
      'resolves from family member email when displayName is empty',
      () async {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(
                const FamilyProfile(familyId: 'fam-1', familyRole: 'parent'),
              ),
            ),
            familyStreamProvider('fam-1').overrideWith(
              (ref) => Stream.value(
                const Family(
                  id: 'fam-1',
                  name: 'Smiths',
                  members: {
                    'user-2': FamilyMember(
                      userId: 'user-2',
                      displayName: '   ',
                      email: 'bob.builder@example.com',
                      role: FamilyRole.parent,
                    ),
                  },
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(userNameProvider('user-2').future);
        expect(result, 'bob');
      },
    );

    test(
      'resolves to you when userId matches the current authenticated user',
      () async {
        final mockUser = MockUser();
        when(mockUser.uid).thenReturn('current-user-id');
        when(mockUser.displayName).thenReturn('Charlie Brown');
        when(mockUser.email).thenReturn('charlie@example.com');

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          userNameProvider('current-user-id').future,
        );
        expect(result, 'you');
      },
    );

    test(
      'resolves to you when userId matches current authenticated user even in family',
      () async {
        final mockUser = MockUser();
        when(mockUser.uid).thenReturn('user-1');

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(
                const FamilyProfile(familyId: 'fam-1', familyRole: 'parent'),
              ),
            ),
            familyStreamProvider('fam-1').overrideWith(
              (ref) => Stream.value(
                const Family(
                  id: 'fam-1',
                  name: 'Smiths',
                  members: {
                    'user-1': FamilyMember(
                      userId: 'user-1',
                      displayName: 'Alice Smith',
                      email: 'alice@example.com',
                      role: FamilyRole.parent,
                    ),
                  },
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(userNameProvider('user-1').future);
        expect(result, 'you');
      },
    );

    test(
      'resolves from Firestore users collection when family and auth do not match',
      () async {
        await fakeFirestore.collection('users').doc('user-firestore').set({
          'displayName': 'Emma Watson',
          'email': 'emma@example.com',
        });

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          userNameProvider('user-firestore').future,
        );
        expect(result, 'Emma');
      },
    );

    test(
      'resolves from Firestore email when displayName is empty in Firestore',
      () async {
        await fakeFirestore.collection('users').doc('user-firestore-email').set(
          {'displayName': '', 'email': 'frank.castle@marvel.com'},
        );

        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          userNameProvider('user-firestore-email').future,
        );
        expect(result, 'frank');
      },
    );

    test(
      'falls back to User when no profile, family, auth, or Firestore match',
      () async {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            familyProfileStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          userNameProvider('unknown-user').future,
        );
        expect(result, 'User');
      },
    );
  });
}
