import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('TaskLabel model tests', () {
    test('create generates unique id, default scope, and default order', () {
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
      expect(label.order, equals(0));
      expect(label.createdAt, isNotNull);
      expect(label.updatedAt, isNull);
    });

    test('create accepts custom order and scope', () {
      final label = TaskLabel.create(
        name: 'Groceries',
        colorKey: 'tangerine',
        iconKey: 'shopping',
        scope: TaskLabelScope.family,
        order: 5,
      );

      expect(label.scope, equals(TaskLabelScope.family));
      expect(label.order, equals(5));
    });

    test('serialization round-trip (toJson / fromJson)', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final label = TaskLabel(
        id: 'L-1234',
        name: 'Cleaning',
        colorKey: 'teal',
        iconKey: 'cleaning',
        scope: TaskLabelScope.family,
        order: 3,
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
      expect(restored.order, equals(3));
      expect(restored.createdAt, equals(now));
      expect(restored.updatedAt, equals(now.add(const Duration(hours: 1))));
    });

    test('fromFirestore handles map data with and without order', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final fakeSnapshotWithOrder = _FakeDocumentSnapshot(
        id: 'L-doc-567',
        dataMap: {
          'name': 'Yard Work',
          'colorKey': 'emerald',
          'iconKey': 'yard',
          'scope': 'family',
          'order': 7,
          'createdAt': now.toIso8601String(),
        },
      );

      final labelWithOrder = TaskLabel.fromFirestore(fakeSnapshotWithOrder);
      expect(labelWithOrder.id, equals('L-doc-567'));
      expect(labelWithOrder.name, equals('Yard Work'));
      expect(labelWithOrder.colorKey, equals('emerald'));
      expect(labelWithOrder.iconKey, equals('yard'));
      expect(labelWithOrder.scope, equals(TaskLabelScope.family));
      expect(labelWithOrder.order, equals(7));

      // Backwards compatibility: order missing defaults to 0
      final fakeSnapshotWithoutOrder = _FakeDocumentSnapshot(
        id: 'L-doc-568',
        dataMap: {
          'name': 'Legacy Label',
          'colorKey': 'coral',
          'iconKey': 'tag',
          'createdAt': now.toIso8601String(),
        },
      );

      final labelWithoutOrder =
          TaskLabel.fromFirestore(fakeSnapshotWithoutOrder);
      expect(labelWithoutOrder.order, equals(0));
    });

    test('copyWith updates fields correctly including order', () {
      final label = TaskLabel.create(
        id: 'L-1',
        name: 'Old Name',
        colorKey: 'coral',
        iconKey: 'tag',
        order: 1,
      );

      final updated = label.copyWith(
        name: 'New Name',
        colorKey: 'grape',
        order: 4,
      );

      expect(updated.id, equals('L-1'));
      expect(updated.name, equals('New Name'));
      expect(updated.colorKey, equals('grape'));
      expect(updated.iconKey, equals('tag'));
      expect(updated.order, equals(4));

      final preservedOrder = label.copyWith(name: 'Another Name');
      expect(preservedOrder.order, equals(1));
    });

    test('equality and hashCode take order into account', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final label1 = TaskLabel(
        id: 'L-1',
        name: 'Label',
        colorKey: 'coral',
        iconKey: 'tag',
        order: 1,
        createdAt: now,
      );
      final label2 = TaskLabel(
        id: 'L-1',
        name: 'Label',
        colorKey: 'coral',
        iconKey: 'tag',
        order: 2,
        createdAt: now,
      );
      final label1Duplicate = TaskLabel(
        id: 'L-1',
        name: 'Label',
        colorKey: 'coral',
        iconKey: 'tag',
        order: 1,
        createdAt: now,
      );

      expect(label1, equals(label1Duplicate));
      expect(label1.hashCode, equals(label1Duplicate.hashCode));
      expect(label1, isNot(equals(label2)));
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

    test('TaskInstance preserves labelIds in serialization and copyWith', () {
      final inst = TaskInstance(
        id: 'I-100',
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Clean Garage',
        description: 'Sweep and organize',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 16),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 12, minute: 0),
        labelIds: ['L-1', 'L-2', 'L-3'],
      );

      expect(inst.labelIds, equals(['L-1', 'L-2', 'L-3']));

      final map = inst.toMap();
      expect(map['labelIds'], equals(['L-1', 'L-2', 'L-3']));

      final restored = TaskInstance.fromMap(map, id: 'I-100');
      expect(restored.labelIds, equals(['L-1', 'L-2', 'L-3']));

      final updated = inst.copyWith(labelIds: ['L-4']);
      expect(updated.labelIds, equals(['L-4']));

      final cleared = inst.copyWith(clearLabelIds: true);
      expect(cleared.labelIds, isEmpty);
    });

    test('TaskSchedule preserves labelIds in serialization and copyWith', () {
      final schedule = TaskSchedule(
        id: 'S-100',
        title: 'Weekly Chores',
        description: 'Chores for the home',
        labelIds: ['L-10', 'L-20'],
      );

      expect(schedule.labelIds, equals(['L-10', 'L-20']));

      final map = schedule.toMap();
      expect(map['labelIds'], equals(['L-10', 'L-20']));

      final restored = TaskSchedule.fromMap(map, id: 'S-100');
      expect(restored.labelIds, equals(['L-10', 'L-20']));

      final updated = schedule.copyWith(labelIds: ['L-30']);
      expect(updated.labelIds, equals(['L-30']));

      final cleared = schedule.copyWith(clearLabelIds: true);
      expect(cleared.labelIds, isEmpty);
    });
  });
}

class _FakeDocumentSnapshot {
  final String id;
  final Map<String, dynamic> dataMap;

  _FakeDocumentSnapshot({required this.id, required this.dataMap});

  Map<String, dynamic> data() => dataMap;
}
