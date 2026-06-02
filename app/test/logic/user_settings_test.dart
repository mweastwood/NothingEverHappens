import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

void main() {
  group('UserSettings Model Unit Tests', () {
    test('default instantiation has 8.0 hoursAvailable', () {
      const settings = UserSettings(hoursAvailable: 8.0);
      expect(settings.hoursAvailable, 8.0);
    });

    test('fromJson handles empty JSON by falling back to 8.0', () {
      final settings = UserSettings.fromJson(const {});
      expect(settings.hoursAvailable, 8.0);
    });

    test('fromJson handles valid JSON input', () {
      final settings = UserSettings.fromJson(const {'hoursAvailable': 12.5});
      expect(settings.hoursAvailable, 12.5);
    });

    test('toJson serializes correctly', () {
      const settings = UserSettings(hoursAvailable: 6.0);
      expect(settings.toJson(), {'hoursAvailable': 6.0});
    });

    test('copyWith updates value correctly', () {
      const settings = UserSettings(hoursAvailable: 8.0);
      final updated = settings.copyWith(hoursAvailable: 4.5);
      expect(updated.hoursAvailable, 4.5);

      final copyOfSame = updated.copyWith();
      expect(copyOfSame.hoursAvailable, 4.5);
    });

    test('equality and hashCode work as expected', () {
      const s1 = UserSettings(hoursAvailable: 5.0);
      const s2 = UserSettings(hoursAvailable: 5.0);
      const s3 = UserSettings(hoursAvailable: 6.0);

      expect(s1, s2);
      expect(s1.hashCode, s2.hashCode);
      expect(s1, isNot(s3));
    });
  });

  group('UserSettingsRepository Unit Tests', () {
    late FakeFirebaseFirestore firestore;
    late UserSettingsRepository repository;
    const userId = 'test-user';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = UserSettingsRepository(firestore: firestore, userId: userId);
    });

    test(
      'getSettings returns default 8.0 hoursAvailable when document does not exist',
      () async {
        final settings = await repository.getSettings().first;
        expect(settings.hoursAvailable, 8.0);
      },
    );

    test('getSettings returns stored settings when document exists', () async {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 10.0});

      final settings = await repository.getSettings().first;
      expect(settings.hoursAvailable, 10.0);
    });

    test('updateSettings creates or updates settings in Firestore', () async {
      const updated = UserSettings(hoursAvailable: 15.0);
      await repository.updateSettings(updated);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), {'hoursAvailable': 15.0});

      final settingsFromRepository = await repository.getSettings().first;
      expect(settingsFromRepository.hoursAvailable, 15.0);
    });
  });
}
