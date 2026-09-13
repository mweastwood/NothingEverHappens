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

    test('LabelPalette and LabelIcons return fallback items gracefully', () {
      final fallbackColor = LabelPalette.getItem('nonexistent');
      expect(fallbackColor.key, equals('coral'));

      final fallbackIcon = LabelIcons.getItem('nonexistent');
      expect(fallbackIcon.key, equals('tag'));
    });
  });
}
