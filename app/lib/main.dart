import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options_dev.dart' as dev;
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'logic/auth_repository.dart';
import 'logic/task_repository.dart';
import 'logic/error_handler.dart';
import 'logic/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: dev.DefaultFirebaseOptions.currentPlatform,
  );

  // Enable persistence for Web
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

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
        Provider<ErrorHandler>(create: (_) => ErrorHandler()),
        Provider<NotificationService>(
          create: (_) => PlatformNotificationService(),
        ),
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthRepository>().authStateChanges,
          initialData: null,
        ),
        ProxyProvider2<User?, NotificationService, TaskRepository?>(
          update: (context, user, notificationService, previous) {
            if (user == null) return null;
            return TaskRepository(
              userId: user.uid,
              notificationService: notificationService,
            );
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
              seedColor: const Color(0xFFffd9f6),
            );
            darkScheme = ColorScheme.fromSeed(
              seedColor: const Color(0xFFffd9f6),
              brightness: Brightness.dark,
            );
          }

          return Consumer<User?>(
            builder: (context, user, _) {
              return MaterialApp(
                title: 'Nothing Ever Happens',
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
                darkTheme: ThemeData(
                  colorScheme: darkScheme,
                  useMaterial3: true,
                ),
                themeMode: ThemeMode.system,
                home: user == null ? const LoginScreen() : const HomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

enum AppEnvironment { dev, prod }

class AppConfig {
  static AppEnvironment environment = AppEnvironment.dev;
}
