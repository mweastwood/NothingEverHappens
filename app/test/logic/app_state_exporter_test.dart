import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_state_exporter.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

class MockAuthRepository extends Mock implements AuthRepository {
  final fb_auth.User? _mockUser;
  MockAuthRepository(this._mockUser);

  @override
  fb_auth.User? get currentUser => _mockUser;
}

class MockUserMetadata extends Mock implements fb_auth.UserMetadata {
  @override
  DateTime? get creationTime => null;

  @override
  DateTime? get lastSignInTime => null;
}

class MockUser extends Mock implements fb_auth.User {
  @override
  String get uid => 'user-123';

  @override
  String? get email => 'test@example.com';

  @override
  bool get isAnonymous => false;

  @override
  bool get emailVerified => true;

  @override
  fb_auth.UserMetadata get metadata => MockUserMetadata();
}

void main() {
  group('AppStateExporter', () {
    late HiveLocalDataSource localDataSource;

    setUp(() {
      localDataSource = HiveLocalDataSource();
      localDataSource.isFallbackInMemoryMode = true;
    });

    test('maskEmail handles various email inputs correctly', () {
      expect(AppStateExporter.maskEmail(null), null);
      expect(AppStateExporter.maskEmail(''), '');
      expect(AppStateExporter.maskEmail('   '), '');
      expect(
        AppStateExporter.maskEmail('john.doe@example.com'),
        'j***@example.com',
      );
      expect(AppStateExporter.maskEmail('a@b.com'), 'a***@b.com');
      expect(AppStateExporter.maskEmail('invalid-email'), '***');
    });

    test('maskPii handles various PII string inputs correctly', () {
      expect(AppStateExporter.maskPii(null), null);
      expect(AppStateExporter.maskPii(''), '');
      expect(AppStateExporter.maskPii('   '), '');
      expect(AppStateExporter.maskPii('John Doe'), 'J***');
      expect(AppStateExporter.maskPii('+15551234567'), '+***');
      expect(
        AppStateExporter.maskPii('https://example.com/avatar.jpg'),
        'h***',
      );
    });

    test(
      'sanitizeForJson converts complex types and masks email and PII fields',
      () {
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
        'email': 'user@example.com',
        'toEmail': 'invitee@example.com',
        'fromEmail': 'inviter@example.com',
        'emails': ['one@example.com', 'two@example.com'],
        'primary_email': 'primary@example.com',
        'email_address': 'address@example.com',
        'displayName': 'John Doe',
        'phoneNumber': '+15551234567',
        'photoURL': 'https://example.com/avatar.png',
        'title': 'Secret task',
        'description': 'Sensitive details',
        'notes': 'Private notes',
        'bio': 'Developer bio',
        'sender': 'Alice Sender',
        'recipient': 'Bob Recipient',
        'inviter': 'Charlie Inviter',
        'invitee': 'David Invitee',
        'member': 'Eve Member',
        'nestedMap': {
          'list': [now, timestamp, civilDay],
          'userEmail': 'nested@example.com',
          'comment': 'Private comment',
        },
      };

      final sanitized = exporter.sanitizeForJson(rawData);
      expect(sanitized, isA<Map<String, dynamic>>());
      expect(sanitized['dateTime'], '2026-08-12T05:00:00.000Z');
      expect(sanitized['timestamp'], '2026-08-12T05:00:00.000Z');
      expect(sanitized['civilDay'], {'year': 2026, 'month': 8, 'day': 12});
      expect(sanitized['relativeTime'], {
        'dayOffset': 1,
        'hour': 14,
        'minute': 30,
      });
      expect(sanitized['duration'], 2700000);
      expect(sanitized['priority'], 'high');
      expect(sanitized['email'], 'u***@example.com');
      expect(sanitized['toEmail'], 'i***@example.com');
      expect(sanitized['fromEmail'], 'i***@example.com');
      expect(sanitized['emails'], ['o***@example.com', 't***@example.com']);
      expect(sanitized['primary_email'], 'p***@example.com');
      expect(sanitized['email_address'], 'a***@example.com');
      expect(sanitized['displayName'], 'J***');
      expect(sanitized['phoneNumber'], '+***');
      expect(sanitized['photoURL'], 'h***');
      expect(sanitized['title'], 'Secret task');
      expect(sanitized['description'], 'Sensitive details');
      expect(sanitized['notes'], 'Private notes');
      expect(sanitized['bio'], 'D***');
      expect(sanitized['sender'], 'A***');
      expect(sanitized['recipient'], 'B***');
      expect(sanitized['inviter'], 'C***');
      expect(sanitized['invitee'], 'D***');
      expect(sanitized['member'], 'E***');
      expect(sanitized['nestedMap']['userEmail'], 'n***@example.com');
      expect(sanitized['nestedMap']['comment'], 'Private comment');

      final jsonString = jsonEncode(sanitized);
      expect(jsonString, isNotEmpty);
    });

    test(
      'exportStateRaw assembles Hive and FakeFirestore state correctly',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final mockUser = MockUser();
        final mockAuthRepo = MockAuthRepository(mockUser);

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
          description: 'Test Instance description',
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
        await fakeFirestore
            .collection('families')
            .doc('fam-1')
            .collection('tasks')
            .doc('ftask-1')
            .set({'title': 'Family Task'});
        await fakeFirestore
            .collection('families')
            .doc('fam-1')
            .collection('instances')
            .doc('finst-1')
            .set({'title': 'Family Instance'});

        final exporter = AppStateExporter(
          firestore: fakeFirestore,
          authRepository: mockAuthRepo,
          hiveDataSource: localDataSource,
        );

        final raw = await exporter.exportStateRaw();

        expect(raw['exportMetadata'], isNotNull);
        expect(raw['exportMetadata']['platform'], isNotNull);

        final localState = raw['localHiveState'];
        expect(localState['inMemoryFallback'], isTrue);
        expect(localState['tasks'], hasLength(1));
        expect(localState['tasks'][0]['id'], 'S-task-1');
        expect(localState['instances'], hasLength(1));
        expect(localState['instances'][0]['id'], 'inst-1');
        expect(localState['syncMeta']['dirty_tasks'], contains('task-1'));
        expect(localState['syncMeta']['migration_completed'], isTrue);

        final remoteState = raw['remoteFirebaseState'];
        expect(remoteState['userProfileDoc']['email'], 't***@example.com');
        expect(remoteState['familyTasks'], hasLength(1));
        expect(remoteState['familyTasks'][0]['id'], 'ftask-1');
        expect(remoteState['familyInstances'], hasLength(1));
        expect(remoteState['familyInstances'][0]['id'], 'finst-1');
      },
    );

    test(
      'exportStateRaw handles missing user or Firestore errors gracefully',
      () async {
        final exporter = AppStateExporter(
          firestore: null,
          hiveDataSource: localDataSource,
        );

        final raw = await exporter.exportStateRaw();

        expect(raw['exportMetadata'], isNotNull);
        expect(raw['exportMetadata']['isOffline'], isTrue);
        expect(raw['localHiveState'], isNotNull);
        expect(raw['remoteFirebaseState']['status'], 'error');
        expect(raw['remoteFirebaseState']['errorMessage'], isNotNull);
      },
    );

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
