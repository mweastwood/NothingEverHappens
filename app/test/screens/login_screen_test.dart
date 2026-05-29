import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/screens/login_screen.dart';
import 'package:provider/provider.dart';
import '../test_helper.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>()])
import 'login_screen_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late ErrorHandler errorHandler;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    errorHandler = ErrorHandler();
    LoginScreen.debugDisableAnimations = true;
  });

  tearDown(() {
    LoginScreen.debugDisableAnimations = false;
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: mockAuthRepository),
        Provider<ErrorHandler>.value(value: errorHandler),
      ],
      child: const LoginScreen(),
    );
  }

  testGoldens('LoginScreen renders correctly in initial state', (tester) async {
    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'login_screen');
  });

  testGoldens('LoginScreen renders loading state when sign-in is in progress', (
    tester,
  ) async {
    final completer =
        Completer<
          dynamic
        >(); // Using dynamic to avoid needing FirebaseAuth mock imports here
    when(
      mockAuthRepository.signInWithGoogle(),
    ).thenAnswer((_) async => await completer.future);

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
      ),
      surfaceSize: const Size(400, 800),
    );

    // Tap the sign-in button
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in with Google'));
    await tester.pump(); // Start the async operation

    // Verify button is disabled (loading state should be true)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Signing in...'), findsOneWidget);

    // Capture loading state screenshot
    await screenMatchesGolden(tester, 'login_screen_loading');

    // Clean up future to avoid uncompleted future leak in test
    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testGoldens('LoginScreen renders error dialog when sign-in fails', (
    tester,
  ) async {
    // Force the repository to throw an exception
    when(mockAuthRepository.signInWithGoogle()).thenAnswer(
      (_) =>
          Future.error(Exception('Failed to connect to authentication server')),
    );

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(
        theme: ThemeData.light(useMaterial3: true).copyWith(
          shadowColor: Colors.transparent,
          textTheme: ThemeData.light(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Ahem'),
        ),
      ),
      surfaceSize: const Size(800, 800),
    );

    // Tap the sign-in button
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in with Google'));
    await tester
        .pumpAndSettle(); // Complete async operation and transition to error state

    // Verify error dialog elements exist
    expect(find.text('Error Occurred'), findsOneWidget);
    expect(
      find.text('Exception: Failed to connect to authentication server'),
      findsOneWidget,
    );

    // Capture error state screenshot
    await screenMatchesGolden(tester, 'login_screen_error');
  });
}
