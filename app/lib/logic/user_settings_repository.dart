import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_settings.dart';
import 'auth_repository.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return UserSettingsRepository(userId: user.uid);
});

class UserSettingsRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  UserSettingsRepository({FirebaseFirestore? firestore, required String userId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

  DocumentReference<UserSettings> _settingsRefForUser(String userId) {
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

  DocumentReference<UserSettings> get _settingsRef =>
      _settingsRefForUser(_userId);

  Stream<UserSettings> getSettings() {
    return getSettingsForUser(_userId);
  }

  Stream<UserSettings> getSettingsForUser(String userId) {
    return _settingsRefForUser(userId).snapshots().map((snapshot) {
      return snapshot.data() ?? const UserSettings(hoursAvailable: 8.0);
    });
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _settingsRef.set(settings, SetOptions(merge: true));
  }
}
