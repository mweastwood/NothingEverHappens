import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_settings.dart';

class UserSettingsRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  UserSettingsRepository({FirebaseFirestore? firestore, required String userId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

  DocumentReference<UserSettings> get _settingsRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('agile')
        .withConverter<UserSettings>(
          fromFirestore: (snapshot, _) =>
              UserSettings.fromJson(snapshot.data() ?? {}),
          toFirestore: (settings, _) => settings.toJson(),
        );
  }

  Stream<UserSettings> getSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      return snapshot.data() ?? const UserSettings(hoursAvailable: 8.0);
    });
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _settingsRef.set(settings, SetOptions(merge: true));
  }
}
