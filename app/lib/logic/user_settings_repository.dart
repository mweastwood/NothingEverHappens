import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_settings.dart';
import 'auth_repository.dart';
import 'task_repository.dart';
import 'hive_local_data_source.dart';
import 'telemetry_service.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  final user = ref.watch(authStateProvider).value;
  final telemetryService = ref.watch(telemetryServiceProvider);
  return UserSettingsRepository(
    firestore: firestore,
    userId: user?.uid ?? '',
    localDataSource: hiveDataSource,
    telemetryService: telemetryService,
  );
});

class UserSettingsRepository {
  final FirebaseFirestore? _firestore;
  final String _userId;
  final HiveLocalDataSource _localDataSource;
  final TelemetryService? _telemetryService;

  UserSettingsRepository({
    FirebaseFirestore? firestore,
    required String userId,
    required HiveLocalDataSource localDataSource,
    TelemetryService? telemetryService,
  }) : _firestore = firestore,
       _userId = userId,
       _localDataSource = localDataSource,
       _telemetryService = telemetryService;

  DocumentReference<UserSettings>? _settingsRefForUser(String userId) {
    if (_firestore == null || userId.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
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

final userSettingsProvider = StreamProvider<UserSettings>((ref) {
  final repo = ref.watch(userSettingsRepositoryProvider);
  if (repo != null) {
    return repo.getSettings();
  }
  final hiveDataSource = ref.watch(hiveLocalDataSourceProvider);
  return hiveDataSource.watchSettings();
});
