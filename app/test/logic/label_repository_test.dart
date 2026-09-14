import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LabelRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = LabelRepository(firestore: firestore);
  });

  group('LabelRepository tests', () {
    test('personal labels stream emits empty list initially', () async {
      final stream = repo.watchPersonalLabels('user-1');
      final initial = await stream.first;
      expect(initial, isEmpty);
    });

    test(
      'savePersonalLabel persists label and stream emits it sorted',
      () async {
        final labelB = TaskLabel.create(
          id: 'L-b',
          name: 'Beta',
          colorKey: 'rose',
          iconKey: 'star',
        );
        final labelA = TaskLabel.create(
          id: 'L-a',
          name: 'Alpha',
          colorKey: 'coral',
          iconKey: 'tag',
        );

        await repo.savePersonalLabel('user-1', labelB);
        await repo.savePersonalLabel('user-1', labelA);

        final list = await repo.watchPersonalLabels('user-1').first;
        expect(list.length, equals(2));
        expect(list[0].name, equals('Alpha'));
        expect(list[1].name, equals('Beta'));
      },
    );

    test('deletePersonalLabel removes label from user collection', () async {
      final label = TaskLabel.create(
        id: 'L-1',
        name: 'Shopping',
        colorKey: 'tangerine',
        iconKey: 'shopping',
      );

      await repo.savePersonalLabel('user-1', label);
      var list = await repo.watchPersonalLabels('user-1').first;
      expect(list.length, equals(1));

      await repo.deletePersonalLabel('user-1', 'L-1');
      list = await repo.watchPersonalLabels('user-1').first;
      expect(list, isEmpty);
    });

    test('family labels stream emits empty list initially', () async {
      final stream = repo.watchFamilyLabels('family-1');
      final initial = await stream.first;
      expect(initial, isEmpty);
    });

    test(
      'saveFamilyLabel persists label and deleteFamilyLabel removes it',
      () async {
        final label = TaskLabel.create(
          id: 'L-fam-1',
          name: 'Groceries',
          colorKey: 'emerald',
          iconKey: 'shopping',
          scope: TaskLabelScope.family,
        );

        await repo.saveFamilyLabel('family-1', label);
        var list = await repo.watchFamilyLabels('family-1').first;
        expect(list.length, equals(1));
        expect(list.first.name, equals('Groceries'));
        expect(list.first.scope, equals(TaskLabelScope.family));

        await repo.deleteFamilyLabel('family-1', 'L-fam-1');
        list = await repo.watchFamilyLabels('family-1').first;
        expect(list, isEmpty);
      },
    );

    test('LabelPalette and LabelIcons return fallback items gracefully', () {
      final fallbackColor = LabelPalette.getItem('nonexistent');
      expect(fallbackColor.key, equals('coral'));

      final fallbackNullColor = LabelPalette.getItem(null);
      expect(fallbackNullColor.key, equals('coral'));

      final fallbackIcon = LabelIcons.getItem('nonexistent');
      expect(fallbackIcon.key, equals('tag'));
    });

    test('LabelPalette.all contains 16 unique colors with valid names', () {
      expect(LabelPalette.all.length, equals(16));

      final keys = LabelPalette.all.map((c) => c.key).toSet();
      expect(keys.length, equals(16));

      for (final colorItem in LabelPalette.all) {
        expect(colorItem.key, isNotEmpty);
        expect(colorItem.name, isNotEmpty);
        expect(colorItem.lightColor, isNotNull);
        expect(colorItem.darkColor, isNotNull);
      }
    });

    test('LabelPalette resolves all 8 pastel color additions correctly', () {
      const expectedPastels = {
        'peach': ('Peach', 0xFFFF8A65, 0xFFFFAB91),
        'cream': ('Cream', 0xFFFBC02D, 0xFFFFF59D),
        'mint': ('Mint', 0xFF66BB6A, 0xFFA5D6A7),
        'sage': ('Sage', 0xFF78909C, 0xFFA5B892),
        'sky': ('Sky', 0xFF4FC3F7, 0xFF81D4FA),
        'periwinkle': ('Periwinkle', 0xFF7986CB, 0xFF9FA8DA),
        'lavender': ('Lavender', 0xFFBA68C8, 0xFFCE93D8),
        'blush': ('Blush', 0xFFF06292, 0xFFF48FB1),
      };

      for (final entry in expectedPastels.entries) {
        final key = entry.key;
        final (name, lightValue, darkValue) = entry.value;

        final item = LabelPalette.getItem(key);
        expect(item.key, equals(key));
        expect(item.name, equals(name));
        expect(item.lightColor.toARGB32(), equals(lightValue));
        expect(item.darkColor.toARGB32(), equals(darkValue));

        // Test case insensitivity and whitespace trimming
        final uppercaseItem = LabelPalette.getItem('  ${key.toUpperCase()}  ');
        expect(uppercaseItem.key, equals(key));
      }
    });

    test('allLabelsMapProvider merges personal and family labels', () async {
      final container = ProviderContainer(
        overrides: [
          personalLabelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              TaskLabel.create(
                id: 'lbl-p1',
                name: 'Personal Label',
                colorKey: 'coral',
                iconKey: 'tag',
              ),
            ]),
          ),
          familyLabelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              TaskLabel.create(
                id: 'lbl-f1',
                name: 'Family Label',
                colorKey: 'emerald',
                iconKey: 'star',
                scope: TaskLabelScope.family,
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(allLabelsMapProvider, (_, _) {});
      addTearDown(subscription.close);

      while (container.read(allLabelsMapProvider).length < 2) {
        await container.pump();
      }

      final map = container.read(allLabelsMapProvider);
      expect(map.length, equals(2));
      expect(map['lbl-p1']?.name, equals('Personal Label'));
      expect(map['lbl-f1']?.name, equals('Family Label'));
    });

    test('allLabelsMapProvider asserts on ID collision in debug mode', () async {
      final container = ProviderContainer(
        overrides: [
          personalLabelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              TaskLabel.create(
                id: 'colliding-id',
                name: 'Personal Label',
                colorKey: 'coral',
                iconKey: 'tag',
              ),
            ]),
          ),
          familyLabelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              TaskLabel.create(
                id: 'colliding-id',
                name: 'Family Label',
                colorKey: 'emerald',
                iconKey: 'star',
                scope: TaskLabelScope.family,
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        personalLabelsStreamProvider,
        (_, _) {},
      );
      final subscriptionFam = container.listen(
        familyLabelsStreamProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(subscriptionFam.close);

      while (container.read(personalLabelsStreamProvider).value == null ||
          container.read(familyLabelsStreamProvider).value == null) {
        await container.pump();
      }

      expect(
        () => container.read(allLabelsMapProvider),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              'Duplicate label ID found across personal and family label sets',
            ),
          ),
        ),
      );
    });
  });
}
