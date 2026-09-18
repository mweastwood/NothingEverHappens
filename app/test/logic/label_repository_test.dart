import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
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

    test('watchPersonalLabels sorts by order then alphabetically', () async {
      final label1 = TaskLabel.create(
        id: 'L-1',
        name: 'Zeta',
        colorKey: 'coral',
        iconKey: 'tag',
        order: 0,
      );
      final label2 = TaskLabel.create(
        id: 'L-2',
        name: 'Alpha',
        colorKey: 'teal',
        iconKey: 'star',
        order: 0,
      );
      final label3 = TaskLabel.create(
        id: 'L-3',
        name: 'Beta',
        colorKey: 'rose',
        iconKey: 'tag',
        order: 1,
      );

      await repo.savePersonalLabel('user-1', label1);
      await repo.savePersonalLabel('user-1', label2);
      await repo.savePersonalLabel('user-1', label3);

      final list = await repo.watchPersonalLabels('user-1').first;
      expect(list.length, 3);
      expect(list[0].name, 'Alpha');
      expect(list[1].name, 'Zeta');
      expect(list[2].name, 'Beta');
    });

    test(
      'reorderPersonalLabels updates order via batch and stream reflects new order',
      () async {
        final labelA = TaskLabel.create(
          id: 'L-a',
          name: 'Alpha',
          colorKey: 'coral',
          iconKey: 'tag',
          order: 0,
        );
        final labelB = TaskLabel.create(
          id: 'L-b',
          name: 'Beta',
          colorKey: 'rose',
          iconKey: 'star',
          order: 1,
        );
        final labelC = TaskLabel.create(
          id: 'L-c',
          name: 'Gamma',
          colorKey: 'mint',
          iconKey: 'yard',
          order: 2,
        );

        await repo.savePersonalLabel('user-1', labelA);
        await repo.savePersonalLabel('user-1', labelB);
        await repo.savePersonalLabel('user-1', labelC);

        // Reorder to: Gamma (0), Alpha (1), Beta (2)
        await repo.reorderPersonalLabels('user-1', [labelC, labelA, labelB]);

        final updatedList = await repo.watchPersonalLabels('user-1').first;
        expect(updatedList.map((l) => l.name).toList(), [
          'Gamma',
          'Alpha',
          'Beta',
        ]);
        expect(updatedList[0].order, 0);
        expect(updatedList[1].order, 1);
        expect(updatedList[2].order, 2);
      },
    );

    test(
      'reorderFamilyLabels updates order via batch and stream reflects new order',
      () async {
        final label1 = TaskLabel.create(
          id: 'L-f1',
          name: 'Chores',
          colorKey: 'teal',
          iconKey: 'cleaning',
          scope: TaskLabelScope.family,
          order: 0,
        );
        final label2 = TaskLabel.create(
          id: 'L-f2',
          name: 'Groceries',
          colorKey: 'emerald',
          iconKey: 'shopping',
          scope: TaskLabelScope.family,
          order: 1,
        );

        await repo.saveFamilyLabel('family-1', label1);
        await repo.saveFamilyLabel('family-1', label2);

        // Reorder to: Groceries (0), Chores (1)
        await repo.reorderFamilyLabels('family-1', [label2, label1]);

        final updatedList = await repo.watchFamilyLabels('family-1').first;
        expect(updatedList.map((l) => l.name).toList(), [
          'Groceries',
          'Chores',
        ]);
        expect(updatedList[0].order, 0);
        expect(updatedList[1].order, 1);
      },
    );

    test('watchPersonalLabels and watchFamilyLabels handle empty id', () async {
      expect(await repo.watchPersonalLabels('').first, isEmpty);
      expect(await repo.watchFamilyLabels('').first, isEmpty);
    });

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

    test(
      'LabelIcons.all contains 36 unique icons with valid names and icon data',
      () {
        expect(LabelIcons.all.length, equals(36));

        final keys = LabelIcons.all.map((i) => i.key).toSet();
        expect(keys.length, equals(36));

        for (final iconItem in LabelIcons.all) {
          expect(iconItem.key, isNotEmpty);
          expect(iconItem.name, isNotEmpty);
          expect(iconItem.icon, isNotNull);
        }
      },
    );

    test(
      'LabelIcons resolves all 18 new icon additions correctly and falls back to tag',
      () {
        const expectedNewIcons = {
          'church': ('Church', Icons.church_outlined),
          'hospital': ('Medical', Icons.local_hospital_outlined),
          'close': ('Cross Mark', Icons.close_outlined),
          'flight': ('Travel', Icons.flight_outlined),
          'event': ('Event', Icons.event_outlined),
          'favorite': ('Heart', Icons.favorite_outline),
          'book': ('Reading', Icons.menu_book_outlined),
          'music': ('Music', Icons.music_note_outlined),
          'computer': ('Tech', Icons.computer_outlined),
          'phone': ('Calls', Icons.phone_outlined),
          'celebration': ('Celebration', Icons.celebration_outlined),
          'sports': ('Sports', Icons.sports_soccer_outlined),
          'park': ('Outdoors', Icons.park_outlined),
          'lightbulb': ('Ideas', Icons.lightbulb_outline),
          'beach': ('Vacation', Icons.beach_access_outlined),
          'mail': ('Mail', Icons.mail_outlined),
          'cut': ('Grooming', Icons.content_cut_outlined),
          'walk': ('Walk', Icons.directions_walk_outlined),
        };

        for (final entry in expectedNewIcons.entries) {
          final key = entry.key;
          final (name, expectedIcon) = entry.value;

          final item = LabelIcons.getItem(key);
          expect(item.key, equals(key));
          expect(item.name, equals(name));
          expect(item.icon, equals(expectedIcon));
          expect(LabelIcons.getIcon(key), equals(expectedIcon));

          // Test case insensitivity and whitespace trimming
          final uppercaseItem = LabelIcons.getItem('  ${key.toUpperCase()}  ');
          expect(uppercaseItem.key, equals(key));
        }

        // Test fallback behavior
        expect(LabelIcons.getItem('unknown_key').key, equals('tag'));
        expect(LabelIcons.getItem(null).key, equals('tag'));
        expect(LabelIcons.getIcon('unknown_key'), equals(Icons.label_outlined));
        expect(LabelIcons.getIcon(null), equals(Icons.label_outlined));
      },
    );

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
