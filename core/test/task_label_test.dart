import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('TaskLabel model tests', () {
    test('create generates unique id and default scope', () {
      final label = TaskLabel.create(
        name: 'Groceries',
        colorKey: 'tangerine',
        iconKey: 'shopping',
      );

      expect(label.id, startsWith('L-'));
      expect(label.name, equals('Groceries'));
      expect(label.colorKey, equals('tangerine'));
      expect(label.iconKey, equals('shopping'));
      expect(label.scope, equals(TaskLabelScope.personal));
      expect(label.createdAt, isNotNull);
      expect(label.updatedAt, isNull);
    });

    test('serialization round-trip (toJson / fromJson)', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final label = TaskLabel(
        id: 'L-1234',
        name: 'Cleaning',
        colorKey: 'teal',
        iconKey: 'cleaning',
        scope: TaskLabelScope.family,
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      final json = label.toJson();
      final restored = TaskLabel.fromJson(json);

      expect(restored, equals(label));
      expect(restored.id, equals('L-1234'));
      expect(restored.name, equals('Cleaning'));
      expect(restored.colorKey, equals('teal'));
      expect(restored.iconKey, equals('cleaning'));
      expect(restored.scope, equals(TaskLabelScope.family));
      expect(restored.createdAt, equals(now));
      expect(restored.updatedAt, equals(now.add(const Duration(hours: 1))));
    });

    test('fromFirestore handles map data and doc id', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final fakeSnapshot = _FakeDocumentSnapshot(
        id: 'L-doc-567',
        dataMap: {
          'name': 'Yard Work',
          'colorKey': 'emerald',
          'iconKey': 'yard',
          'scope': 'family',
          'createdAt': now.toIso8601String(),
        },
      );

      final label = TaskLabel.fromFirestore(fakeSnapshot);
      expect(label.id, equals('L-doc-567'));
      expect(label.name, equals('Yard Work'));
      expect(label.colorKey, equals('emerald'));
      expect(label.iconKey, equals('yard'));
      expect(label.scope, equals(TaskLabelScope.family));
    });

    test('copyWith updates fields correctly', () {
      final label = TaskLabel.create(
        id: 'L-1',
        name: 'Old Name',
        colorKey: 'coral',
        iconKey: 'tag',
      );

      final updated = label.copyWith(
        name: 'New Name',
        colorKey: 'grape',
      );

      expect(updated.id, equals('L-1'));
      expect(updated.name, equals('New Name'));
      expect(updated.colorKey, equals('grape'));
      expect(updated.iconKey, equals('tag'));
    });

    test('TaskLabelScope.fromString fallbacks gracefully', () {
      expect(TaskLabelScope.fromString('personal'),
          equals(TaskLabelScope.personal));
      expect(
          TaskLabelScope.fromString('family'), equals(TaskLabelScope.family));
      expect(TaskLabelScope.fromString('unknown'),
          equals(TaskLabelScope.personal));
      expect(TaskLabelScope.fromString(null), equals(TaskLabelScope.personal));
    });
  });
}

class _FakeDocumentSnapshot {
  final String id;
  final Map<String, dynamic> dataMap;

  _FakeDocumentSnapshot({required this.id, required this.dataMap});

  Map<String, dynamic> data() => dataMap;
}
