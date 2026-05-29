import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/main.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<GoogleSignIn>(),
  MockSpec<User>(),
  MockSpec<UserCredential>(),
  MockSpec<GoogleSignInAccount>(),
  MockSpec<GoogleSignInAuthentication>(),
])
import 'auth_repository_test.mocks.dart';

void main() {
  group('AuthRepository', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockGoogleSignIn mockGoogleSignIn;
    late AuthRepository authRepository;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockGoogleSignIn = MockGoogleSignIn();
      authRepository = AuthRepository(
        firebaseAuth: mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
      );
      // Reset environment to dev for each test
      AppConfig.environment = AppEnvironment.dev;
    });

    test('currentUser returns firebaseAuth currentUser', () {
      final mockUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

      expect(authRepository.currentUser, mockUser);
    });

    test('authStateChanges returns firebaseAuth authStateChanges', () {
      final mockUser = MockUser();
      final stream = Stream<User?>.value(mockUser);
      when(mockFirebaseAuth.authStateChanges()).thenAnswer((_) => stream);

      expect(authRepository.authStateChanges, stream);
    });

    test('signOut signs out of both firebaseAuth and googleSignIn', () async {
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      await authRepository.signOut();

      verify(mockFirebaseAuth.signOut()).called(1);
      verify(mockGoogleSignIn.signOut()).called(1);
    });

    test('signInWithGoogle success on Mobile flow', () async {
      final mockGoogleUser = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();

      when(
        mockGoogleSignIn.authenticate(),
      ).thenAnswer((_) => Future.value(mockGoogleUser));
      when(mockGoogleUser.authentication).thenReturn(mockGoogleAuth);
      when(mockGoogleAuth.idToken).thenReturn('mock-id-token');
      when(
        mockFirebaseAuth.signInWithCredential(any),
      ).thenAnswer((_) => Future.value(mockUserCredential));
      when(mockUserCredential.user).thenReturn(mockUser);

      final user = await authRepository.signInWithGoogle();

      expect(user, mockUser);
      verify(
        mockGoogleSignIn.initialize(
          serverClientId:
              '631207034652-91uutp0kkbmaaltqlg5858et5pal7era.apps.googleusercontent.com',
        ),
      ).called(1);
      verify(mockGoogleSignIn.authenticate()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
    });

    test(
      'signInWithGoogle throws detailed exception on Mobile flow when canceled',
      () async {
        when(mockGoogleSignIn.authenticate()).thenThrow(
          GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'canceled',
          ),
        );

        expect(
          () => authRepository.signInWithGoogle(),
          throwsA(
            isA<GoogleSignInException>().having(
              (e) => e.description,
              'description',
              contains('configuration'),
            ),
          ),
        );
      },
    );

    test(
      'signInWithGoogle initializes GoogleSignIn with dev client ID when AppConfig.environment is dev',
      () async {
        AppConfig.environment = AppEnvironment.dev;
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) => Future.value(mockGoogleUser));
        when(mockGoogleUser.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('mock-id-token');
        when(
          mockFirebaseAuth.signInWithCredential(any),
        ).thenAnswer((_) => Future.value(mockUserCredential));
        when(mockUserCredential.user).thenReturn(mockUser);

        await authRepository.signInWithGoogle();

        verify(
          mockGoogleSignIn.initialize(
            serverClientId:
                '631207034652-91uutp0kkbmaaltqlg5858et5pal7era.apps.googleusercontent.com',
          ),
        ).called(1);
      },
    );

    test(
      'signInWithGoogle initializes GoogleSignIn with prod client ID when AppConfig.environment is prod',
      () async {
        AppConfig.environment = AppEnvironment.prod;
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) => Future.value(mockGoogleUser));
        when(mockGoogleUser.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('mock-id-token');
        when(
          mockFirebaseAuth.signInWithCredential(any),
        ).thenAnswer((_) => Future.value(mockUserCredential));
        when(mockUserCredential.user).thenReturn(mockUser);

        await authRepository.signInWithGoogle();

        verify(
          mockGoogleSignIn.initialize(
            serverClientId:
                '936469690744-8bthibeb317ifso2jc25ra9jmlaggdac.apps.googleusercontent.com',
          ),
        ).called(1);
      },
    );
  });
}
