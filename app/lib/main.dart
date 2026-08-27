import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'firebase_options_dev.dart' as dev;
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'logic/crashlytics_service.dart';
import 'logic/auth_repository.dart';
import 'logic/unified_task_repository.dart';
import 'logic/task_sync_service.dart';
import 'logic/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'logic/hive_local_data_source.dart';
import 'logic/telemetry_service.dart';
import 'logic/remote_config_service.dart';
import 'logic/utils/app_version.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: dev.DefaultFirebaseOptions.currentPlatform,
      );
    }

    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final hiveDataSource = HiveLocalDataSource();
      await hiveDataSource.init();
      final syncService = TaskSyncService(
        firestore: FirebaseFirestore.instance,
        localDataSource: hiveDataSource,
        userId: currentUser.uid,
        isActivePremium: false,
      );
      final repo = UnifiedTaskRepository(
        localDataSource: hiveDataSource,
        syncService: syncService,
        userId: currentUser.uid,
        firestore: FirebaseFirestore.instance,
        notificationService: PlatformNotificationService(),
      );
      await repo.triggerMissedPolicyProcessing();
    }

    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: dev.DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalAutoDetectLongPolling: true,
      );
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  if (!kIsWeb) {
    Workmanager()
        .initialize(callbackDispatcher)
        .then((_) {
          Workmanager().registerPeriodicTask(
            "scheduler-periodic-task",
            "periodicEvaluationTask",
            frequency: const Duration(minutes: 15),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          );
        })
        .catchError((e) {
          debugPrint("Workmanager initialization error: $e");
        });
  }

  final hiveDataSource = HiveLocalDataSource();
  try {
    await hiveDataSource.init();
  } catch (e) {
    debugPrint("Hive initialization error: $e");
  }

  final settings = hiveDataSource.getSettings();

  unawaited(() async {
    try {
      final launchCount = await hiveDataSource.incrementAppLaunchCount();
      final platform = kIsWeb ? 'web' : Platform.operatingSystem;
      final appVersion = AppVersion.current;

      if (Firebase.apps.isNotEmpty) {
        final telemetryService = FirebaseTelemetryService(
          analytics: FirebaseAnalytics.instance,
          enabled: settings.telemetryEnabled,
          defaultPlatform: platform,
          defaultAppVersion: appVersion,
        );
        await telemetryService.logAppLaunch(
          platform: platform,
          appVersion: appVersion,
          launchCount: launchCount,
        );

        final remoteConfigService = FirebaseRemoteConfigService(
          remoteConfig: FirebaseRemoteConfig.instance,
        );
        await remoteConfigService.initialize();
        await remoteConfigService.fetchAndActivate();
      }
    } catch (e) {
      debugPrint("Telemetry app launch error: $e");
    }
  }());

  mainCommon(hiveDataSource);
}

void setupGlobalErrorHandlers(ProviderContainer container) {
  FlutterError.onError = (errorDetails) {
    container
        .read(crashlyticsServiceProvider)
        .recordFlutterFatalError(errorDetails);
    FlutterError.presentError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    container
        .read(crashlyticsServiceProvider)
        .recordError(error, stack, fatal: true);
    return true;
  };
}

void mainCommon(
  HiveLocalDataSource hiveDataSource, [
  ProviderContainer? container,
]) {
  final providerContainer =
      container ??
      ProviderContainer(
        overrides: [
          hiveLocalDataSourceProvider.overrideWithValue(hiveDataSource),
        ],
      );

  setupGlobalErrorHandlers(providerContainer);

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return DynamicColorBuilder(
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

        return MaterialApp(
          key: ValueKey(user == null),
          title: 'Nothing Ever Happens',
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) =>
                  user == null ? const LoginScreen() : const HomeScreen(),
            );
          },
        );
      },
    );
  }
}

enum AppEnvironment { dev, prod }

class AppConfig {
  static AppEnvironment environment = AppEnvironment.dev;
}
