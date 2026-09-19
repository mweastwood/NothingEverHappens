import 'package:core/core.dart';
import 'package:test/test.dart';

class _FakeSnapshotMetadata {
  final bool hasPendingWrites = false;
  final bool isFromCache = false;
  const _FakeSnapshotMetadata();
}

class _FakeDocumentSnapshot {
  final String id;
  final Map<String, dynamic> dataMap;
  final _FakeSnapshotMetadata metadata = const _FakeSnapshotMetadata();

  _FakeDocumentSnapshot({
    required this.id,
    required this.dataMap,
  });

  Map<String, dynamic> data() => dataMap;
}

void main() {
  group('TaskInstance labelIds tests', () {
    test('default instantiation has empty labelIds', () {
      final inst = TaskInstance(
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Instance Test',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 14),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
      );
      expect(inst.labelIds, isEmpty);
    });

    test('accepts labelIds in constructor', () {
      final inst = TaskInstance(
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Instance Test',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 14),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        labelIds: const ['L-1', 'L-2'],
      );
      expect(inst.labelIds, equals(['L-1', 'L-2']));
    });

    test('serialization round-trip (toMap / fromMap)', () {
      final inst = TaskInstance(
        id: 'I-100',
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Instance with labels',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 14),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        labelIds: ['L-family-1', 'L-family-2'],
      );

      final map = inst.toMap();
      expect(map['labelIds'], equals(['L-family-1', 'L-family-2']));

      final restored = TaskInstance.fromMap(map, id: 'I-100');
      expect(restored.labelIds, equals(['L-family-1', 'L-family-2']));
    });

    test('fromMap defaults labelIds to empty when missing', () {
      final inst = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test',
        'description': 'Desc',
      }, id: 'I-200');
      expect(inst.labelIds, isEmpty);
    });

    test('fromFirestore parses labelIds correctly', () {
      final fakeSnapshot = _FakeDocumentSnapshot(
        id: 'I-doc-300',
        dataMap: {
          'scheduleId': 'S-1',
          'ruleId': 'R-1',
          'title': 'Firestore Instance',
          'description': 'Desc',
          'labelIds': ['L-alpha', 'L-beta'],
        },
      );

      final inst = TaskInstance.fromFirestore(fakeSnapshot);
      expect(inst.id, equals('I-doc-300'));
      expect(inst.labelIds, equals(['L-alpha', 'L-beta']));
    });

    test('copyWith updates or clears labelIds', () {
      final inst = TaskInstance(
        scheduleId: 'S-1',
        ruleId: 'R-1',
        title: 'Instance',
        description: 'Desc',
        scheduledDate: const CivilDay(year: 2026, month: 9, day: 14),
        startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
        dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
        labelIds: ['L-1'],
      );

      final updated = inst.copyWith(labelIds: ['L-99']);
      expect(updated.labelIds, equals(['L-99']));

      final cleared = updated.copyWith(clearLabelIds: true);
      expect(cleared.labelIds, isEmpty);

      final preserved = updated.copyWith(title: 'New Title');
      expect(preserved.labelIds, equals(['L-99']));
    });
  });

  group('TaskInstance scheduledDate deserialization tests', () {
    test('deserializes scheduledDate when represented as Map', () {
      final inst = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': {'year': 2026, 'month': 8, 'day': 30},
      });
      expect(inst.scheduledDate,
          equals(const CivilDay(year: 2026, month: 8, day: 30)));
    });

    test('deserializes scheduledDate when represented as ISO-8601 String', () {
      final inst = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': '2026-08-30',
      });
      expect(inst.scheduledDate,
          equals(const CivilDay(year: 2026, month: 8, day: 30)));
    });

    test('defaults scheduledDate to today when missing or null', () {
      final nowCivilDay = CivilDay.fromDateTime(DateTime.now());
      final instNull = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': null,
      });
      expect(instNull.scheduledDate, equals(nowCivilDay));

      final instMissing = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
      });
      expect(instMissing.scheduledDate, equals(nowCivilDay));
    });

    test('falls back gracefully to today when string is malformed', () {
      final nowCivilDay = CivilDay.fromDateTime(DateTime.now());
      final inst = TaskInstance.fromMap({
        'scheduleId': 'S-1',
        'ruleId': 'R-1',
        'title': 'Test Instance',
        'scheduledDate': 'invalid-date',
      });
      expect(inst.scheduledDate, equals(nowCivilDay));
    });
  });
}
