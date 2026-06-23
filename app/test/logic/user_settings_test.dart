import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

void main() {
  group('UserSettings Model Unit Tests', () {
    test('default instantiation has 8.0 hoursAvailable', () {
      const settings = UserSettings(hoursAvailable: 8.0);
      expect(settings.hoursAvailable, 8.0);
      expect(settings.showPendingTasks, isFalse);
      expect(settings.showLastSpawnedDate, isFalse);
      expect(settings.showRecentlyResolvedTasks, isFalse);
    });

    test('fromJson handles empty JSON by falling back to 8.0 and false', () {
      final settings = UserSettings.fromJson(const {});
      expect(settings.hoursAvailable, 8.0);
      expect(settings.showPendingTasks, isFalse);
      expect(settings.showLastSpawnedDate, isFalse);
      expect(settings.showRecentlyResolvedTasks, isFalse);
    });

    test('fromJson handles valid JSON input', () {
      final settings = UserSettings.fromJson(const {
        'hoursAvailable': 12.5,
        'showPendingTasks': true,
        'showLastSpawnedDate': true,
        'showRecentlyResolvedTasks': true,
      });
      expect(settings.hoursAvailable, 12.5);
      expect(settings.showPendingTasks, isTrue);
      expect(settings.showLastSpawnedDate, isTrue);
      expect(settings.showRecentlyResolvedTasks, isTrue);
    });

    test('toJson serializes correctly', () {
      const settings = UserSettings(
        hoursAvailable: 6.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      expect(settings.toJson(), {
        'hoursAvailable': 6.0,
        'showPendingTasks': true,
        'showLastSpawnedDate': true,
        'showRecentlyResolvedTasks': true,
      });
    });

    test('copyWith updates value correctly', () {
      const settings = UserSettings(
        hoursAvailable: 8.0,
        showPendingTasks: false,
        showLastSpawnedDate: false,
        showRecentlyResolvedTasks: false,
      );
      final updated = settings.copyWith(
        hoursAvailable: 4.5,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      expect(updated.hoursAvailable, 4.5);
      expect(updated.showPendingTasks, isTrue);
      expect(updated.showLastSpawnedDate, isTrue);
      expect(updated.showRecentlyResolvedTasks, isTrue);

      final copyOfSame = updated.copyWith();
      expect(copyOfSame.hoursAvailable, 4.5);
      expect(copyOfSame.showPendingTasks, isTrue);
      expect(copyOfSame.showLastSpawnedDate, isTrue);
      expect(copyOfSame.showRecentlyResolvedTasks, isTrue);
    });

    test('equality and hashCode work as expected', () {
      const s1 = UserSettings(
        hoursAvailable: 5.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      const s2 = UserSettings(
        hoursAvailable: 5.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      const s3 = UserSettings(
        hoursAvailable: 6.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      const s4 = UserSettings(
        hoursAvailable: 5.0,
        showPendingTasks: false,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      const s5 = UserSettings(
        hoursAvailable: 5.0,
        showPendingTasks: true,
        showLastSpawnedDate: false,
        showRecentlyResolvedTasks: true,
      );
      const s6 = UserSettings(
        hoursAvailable: 5.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: false,
      );

      expect(s1, s2);
      expect(s1.hashCode, s2.hashCode);
      expect(s1, isNot(s3));
      expect(s1, isNot(s4));
      expect(s1, isNot(s5));
      expect(s1, isNot(s6));
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
      const updated = UserSettings(
        hoursAvailable: 15.0,
        showPendingTasks: true,
        showLastSpawnedDate: true,
        showRecentlyResolvedTasks: true,
      );
      await repository.updateSettings(updated);

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('agile')
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), {
        'hoursAvailable': 15.0,
        'showPendingTasks': true,
        'showLastSpawnedDate': true,
        'showRecentlyResolvedTasks': true,
      });

      final settingsFromRepository = await repository.getSettings().first;
      expect(settingsFromRepository.hoursAvailable, 15.0);
      expect(settingsFromRepository.showPendingTasks, isTrue);
      expect(settingsFromRepository.showLastSpawnedDate, isTrue);
      expect(settingsFromRepository.showRecentlyResolvedTasks, isTrue);
    });
  });
}
