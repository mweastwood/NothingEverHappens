import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options_dev.dart' as dev;
import 'screens/task_list_screen.dart';
import 'screens/login_screen.dart';
import 'logic/auth_repository.dart';
import 'logic/task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: dev.DefaultFirebaseOptions.currentPlatform,
  );
  mainCommon();
}

void mainCommon() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthRepository>().authStateChanges,
          initialData: null,
        ),
        ProxyProvider<User?, TaskRepository?>(
          update: (context, user, previous) {
            if (user == null) return null;
            return TaskRepository(userId: user.uid);
          },
        ),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          ColorScheme lightScheme;
          ColorScheme darkScheme;

          if (lightDynamic != null && darkDynamic != null) {
            lightScheme = lightDynamic;
            darkScheme = darkDynamic;
          } else {
            lightScheme = ColorScheme.fromSeed(
              seedColor: Colors.white,
              dynamicSchemeVariant: DynamicSchemeVariant.neutral,
            );
            darkScheme = ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
              dynamicSchemeVariant: DynamicSchemeVariant.neutral,
            );
          }

          return Consumer<User?>(
            builder: (context, user, _) {
              return MaterialApp(
                title: 'Nothing Ever Happens',
                theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
                darkTheme: ThemeData(
                  colorScheme: darkScheme,
                  useMaterial3: true,
                ),
                themeMode: ThemeMode.system,
                home: user == null
                    ? const LoginScreen()
                    : const TaskListScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
