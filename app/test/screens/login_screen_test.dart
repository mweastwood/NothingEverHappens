import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mockito/annotations.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/screens/login_screen.dart';
import 'package:provider/provider.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>()])
import 'login_screen_test.mocks.dart';

void main() {
  testGoldens('LoginScreen renders correctly', (tester) async {
    final mockAuthRepository = MockAuthRepository();

    await tester.pumpWidgetBuilder(
      Provider<AuthRepository>.value(
        value: mockAuthRepository,
        child: const LoginScreen(),
      ),
      wrapper: materialAppWrapper(),
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'login_screen');
  });
}
