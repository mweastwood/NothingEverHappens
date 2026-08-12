import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_state_exporter.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

void main() {
  group('AppStateExporter', () {
    late HiveLocalDataSource localDataSource;

    setUp(() {
      localDataSource = HiveLocalDataSource();
      localDataSource.isFallbackInMemoryMode = true;
    });

    test('sanitizeForJson converts complex types correctly', () {
      final exporter = AppStateExporter(hiveDataSource: localDataSource);

      final now = DateTime.utc(2026, 8, 12, 5, 0, 0);
      final timestamp = Timestamp.fromDate(now);
      final civilDay = const CivilDay(year: 2026, month: 8, day: 12);
      final relativeTime = const RelativeTime(
        dayOffset: 1,
        time: TimeOfDay(hour: 14, minute: 30),
      );
      final duration = const Duration(minutes: 45);

      final rawData = {
        'dateTime': now,
        'timestamp': timestamp,
        'civilDay': civilDay,
        'relativeTime': relativeTime,
        'duration': duration,
        'priority': TaskPriority.high,
        'nestedMap': {
          'list': [now, timestamp, civilDay],
        },
      };

      final sanitized = exporter.sanitizeForJson(rawData);
      expect(sanitized, isA<Map<String, dynamic>>());
      expect(sanitized['dateTime'], '2026-08-12T05:00:00.000Z');
      expect(sanitized['timestamp'], '2026-08-12T05:00:00.000Z');
      expect(sanitized['civilDay'], {'year': 2026, 'month': 8, 'day': 12});
      expect(
        sanitized['relativeTime'],
        {'dayOffset': 1, 'hour': 14, 'minute': 30},
      );
      expect(sanitized['duration'], 2700000);
      expect(sanitized['priority'], 'high');

      final jsonString = jsonEncode(sanitized);
      expect(jsonString, isNotEmpty);
    });

    test('exportStateRaw assembles Hive and FakeFirestore state correctly',
        () async {
      final fakeFirestore = FakeFirebaseFirestore();

      final task = TaskSchedule(
        id: 'task-1',
        title: 'Test Task',
        description: 'Testing exporter',
        schedules: const [],
        activeOccurrenceIndex: 0,
        updatedAt: DateTime.utc(2026, 8, 12),
      );
      final instance = TaskInstance(
        id: 'inst-1',
        scheduleId: 'task-1',
        ruleId: 'rule-1',
        title: 'Test Instance',
        scheduledDate: const CivilDay(year: 2026, month: 8, day: 12),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        notificationRelativeTimes: const [],
        updatedAt: DateTime.utc(2026, 8, 12),
      );

      await localDataSource.saveTask(task);
      await localDataSource.saveInstance(instance);
      await localDataSource.markDirty('task-1');
      await localDataSource.setMigrationCompleted(true);

      const uid = 'user-123';
      await fakeFirestore.collection('users').doc(uid).set({
        'displayName': 'Test User',
        'email': 'test@example.com',
        'familyId': 'fam-1',
      });
      await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('agile')
          .set({'hoursAvailable': 10.0});
      await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc('task-1')
          .set({'title': 'Remote Task'});
      await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('instances')
          .doc('inst-1')
          .set({'title': 'Remote Instance'});
      await fakeFirestore.collection('families').doc('fam-1').set({
        'name': 'Test Family',
      });

      final exporter = AppStateExporter(
        firestore: fakeFirestore,
        hiveDataSource: localDataSource,
      );

      final raw = await exporter.exportStateRaw();

      expect(raw['exportMetadata'], isNotNull);
      expect(raw['exportMetadata']['platform'], isNotNull);

      final localState = raw['localHiveState'];
      expect(localState['inMemoryFallback'], isTrue);
      expect(localState['tasks'], hasLength(1));
      expect(localState['tasks'][0]['id'], 'task-1');
      expect(localState['instances'], hasLength(1));
      expect(localState['instances'][0]['id'], 'inst-1');
      expect(localState['syncMeta']['dirty_tasks'], contains('task-1'));
      expect(localState['syncMeta']['migration_completed'], isTrue);
    });

    test('exportStateRaw handles missing user or Firestore errors gracefully',
        () async {
      final exporter = AppStateExporter(
        firestore: null,
        hiveDataSource: localDataSource,
      );

      final raw = await exporter.exportStateRaw();

      expect(raw['exportMetadata'], isNotNull);
      expect(raw['exportMetadata']['isOffline'], isFalse);
      expect(raw['localHiveState'], isNotNull);
      expect(raw['remoteFirebaseState']['status'], 'error');
      expect(raw['remoteFirebaseState']['errorMessage'], isNotNull);
    });

    test('exportStateJson produces pretty and compact JSON strings', () async {
      final exporter = AppStateExporter(
        firestore: null,
        hiveDataSource: localDataSource,
      );

      final prettyJson = await exporter.exportStateJson(pretty: true);
      final compactJson = await exporter.exportStateJson(pretty: false);

      expect(prettyJson, contains('\n'));
      expect(compactJson, isNot(contains('\n')));

      final decoded = jsonDecode(prettyJson);
      expect(decoded['exportMetadata'], isNotNull);
    });
  });
}
