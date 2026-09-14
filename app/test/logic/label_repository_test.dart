import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
  });
}
