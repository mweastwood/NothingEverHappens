import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_settings.dart';
import 'firestore_paths.dart';
import 'auth_repository.dart';
import 'task_repository.dart';
import 'hive_local_data_source.dart';
import 'telemetry_service.dart';
import 'crashlytics_service.dart';
import 'subscription_service.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final subscriptionState = ref.watch(subscriptionServiceProvider);
  final telemetryService = ref.watch(telemetryServiceProvider);
  final crashlyticsService = ref.watch(crashlyticsServiceProvider);

  final repo = UserSettingsRepository(
    firestore: firestore,
    userId: user?.uid ?? '',
    isActivePremium: subscriptionState.isActivePremium,
    localDataSource: hiveDataSource,
    telemetryService: telemetryService,
    crashlyticsService: crashlyticsService,
  );

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});

class UserSettingsRepository {
  final FirebaseFirestore? _firestore;
  final String _userId;
  final bool _isActivePremium;
  final HiveLocalDataSource _localDataSource;
  final TelemetryService? _telemetryService;
  final CrashlyticsService? _crashlyticsService;
  StreamSubscription? _remoteSettingsSub;

  UserSettingsRepository({
    FirebaseFirestore? firestore,
    required String userId,
    bool isActivePremium = false,
    required HiveLocalDataSource localDataSource,
    TelemetryService? telemetryService,
    CrashlyticsService? crashlyticsService,
  }) : _firestore = firestore,
       _userId = userId,
       _isActivePremium = isActivePremium,
       _localDataSource = localDataSource,
       _telemetryService = telemetryService,
       _crashlyticsService = crashlyticsService {
    final initialSettings = _localDataSource.getSettings();
    _telemetryService?.setTelemetryEnabled(initialSettings.telemetryEnabled);
    _crashlyticsService?.setCrashlyticsCollectionEnabled(
      initialSettings.crashReportingEnabled,
    );
    if (_isActivePremium && _userId.isNotEmpty) {
      _startListeningToRemoteSettings();
    }
  }

  void _startListeningToRemoteSettings() {
    if (_firestore == null || _userId.isEmpty) return;
    final docRef = _firestore
        .collection(FirestorePaths.users)
        .doc(_userId)
        .collection(FirestorePaths.settings)
        .doc('agile');

    _remoteSettingsSub?.cancel();
    _remoteSettingsSub = docRef.snapshots().listen(
      (snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          final rawData = Map<String, dynamic>.from(snapshot.data()!);
          final remoteData = UserSettings.fromJson(rawData);
          await _localDataSource.saveSettings(remoteData);
          await _telemetryService?.setTelemetryEnabled(
            remoteData.telemetryEnabled,
          );
          await _crashlyticsService?.setCrashlyticsCollectionEnabled(
            remoteData.crashReportingEnabled,
          );
        }
      },
      onError: (_) {
        // Silent error handler for remote settings stream
      },
    );
  }

  void dispose() {
    _remoteSettingsSub?.cancel();
  }

  DocumentReference<UserSettings>? _settingsRefForUser(String userId) {
    if (_firestore == null || userId.isEmpty) return null;
    return _firestore
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection(FirestorePaths.settings)
        .doc('agile')
        .withConverter<UserSettings>(
          fromFirestore: (snapshot, _) =>
              UserSettings.fromJson(snapshot.data() ?? {}),
          toFirestore: (settings, _) => settings.toJson(),
        );
  }

  Stream<UserSettings> getSettings() {
    return _localDataSource.watchSettings();
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _localDataSource.saveSettings(settings);
    await _telemetryService?.setTelemetryEnabled(settings.telemetryEnabled);
    await _crashlyticsService?.setCrashlyticsCollectionEnabled(
      settings.crashReportingEnabled,
    );
    if (_isActivePremium && _userId.isNotEmpty) {
      final ref = _settingsRefForUser(_userId);
      if (ref != null) {
        try {
          await ref.set(settings, SetOptions(merge: true));
        } catch (e) {
          // Local Hive save succeeded; background firestore sync can fail silently if offline/free
        }
      }
    }
  }
}

final userSettingsProvider = StreamProvider<UserSettings>((ref) {
  final repo = ref.watch(userSettingsRepositoryProvider);
  if (repo != null) {
    return repo.getSettings();
  }
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  return hiveDataSource.watchSettings();
});
