import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_state_exporter.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/utils/app_version.dart';

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
          'phoneNumbers': ['+15551234567', '+15559876543'],
          'photoURL': 'https://example.com/avatar.png',
          'title': 'Secret task',
          'description': 'Sensitive details',
          'notes': 'Private notes',
          'bio': 'Developer bio',
          'bios': ['First bio', 'Second bio'],
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
        expect(sanitized['phoneNumbers'], ['+***', '+***']);
        expect(sanitized['photoURL'], 'h***');
        expect(sanitized['title'], 'Secret task');
        expect(sanitized['description'], 'Sensitive details');
        expect(sanitized['notes'], 'Private notes');
        expect(sanitized['bio'], 'D***');
        expect(sanitized['bios'], ['F***', 'S***']);
        expect(sanitized['sender'], 'A***');
        expect(sanitized['recipient'], 'B***');
        expect(sanitized['inviter'], 'C***');
        expect(sanitized['invitee'], 'D***');
        expect(sanitized['member'], 'E***');
        expect(sanitized['nestedMap']['userEmail'], 'n***@example.com');
        expect(sanitized['nestedMap']['comment'], 'Private comment');

        final jsonString = jsonEncode(sanitized);
        expect(jsonString, isNotEmpty);
      },
    );

    test(
      'sanitizeForJson preserves object IDs, roles, and status fields '
      'inside nested member or invite objects',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final rawData = {
          'memberId': 'user-123',
          'inviterId': 'user-456',
          'inviteeId': 'user-789',
          'userId': 'user-000',
          'uid': 'user-321',
          'uids': ['user-321', 'user-654'],
          'member_id': 'user-111',
          'memberIds': ['user_123', 'user_456'],
          'member_ids': ['user_789', 'user_000'],
          'member': {
            'id': 'u123',
            'uid': 'u123_uid',
            'memberUid': 'm_uid_456',
            'role': 'admin',
            'status': 'active',
            'displayName': 'Eve Member',
            'joinedAt': DateTime.utc(2026, 1, 1),
          },
          'inviter': {
            'id': 'u456',
            'role': 'member',
            'status': 'pending',
            'email': 'inviter@example.com',
            'name': 'Charlie Inviter',
          },
          'invitee': {
            'id': 'u789',
            'role': 'viewer',
            'status': 'accepted',
            'email': 'invitee@example.com',
            'name': 'David Invitee',
          },
          'membersList': [
            {
              'id': 'u999',
              'role': 'owner',
              'status': 'active',
              'displayName': 'Frank Member',
            },
          ],
          'members': {'user-123': 'admin', 'user-456': 'owner'},
        };

        final sanitized = exporter.sanitizeForJson(rawData);

        expect(sanitized['memberId'], 'user-123');
        expect(sanitized['inviterId'], 'user-456');
        expect(sanitized['inviteeId'], 'user-789');
        expect(sanitized['userId'], 'user-000');
        expect(sanitized['uid'], 'user-321');
        expect(sanitized['uids'], ['user-321', 'user-654']);
        expect(sanitized['member_id'], 'user-111');
        expect(sanitized['memberIds'], ['user_123', 'user_456']);
        expect(sanitized['member_ids'], ['user_789', 'user_000']);

        expect(sanitized['member']['id'], 'u123');
        expect(sanitized['member']['uid'], 'u123_uid');
        expect(sanitized['member']['memberUid'], 'm_uid_456');
        expect(sanitized['member']['role'], 'admin');
        expect(sanitized['member']['status'], 'active');
        expect(sanitized['member']['displayName'], 'E***');
        expect(sanitized['member']['joinedAt'], '2026-01-01T00:00:00.000Z');

        expect(sanitized['inviter']['id'], 'u456');
        expect(sanitized['inviter']['role'], 'member');
        expect(sanitized['inviter']['status'], 'pending');
        expect(sanitized['inviter']['email'], 'i***@example.com');
        expect(sanitized['inviter']['name'], 'C***');

        expect(sanitized['invitee']['id'], 'u789');
        expect(sanitized['invitee']['role'], 'viewer');
        expect(sanitized['invitee']['status'], 'accepted');
        expect(sanitized['invitee']['email'], 'i***@example.com');
        expect(sanitized['invitee']['name'], 'D***');

        expect(sanitized['membersList'][0]['id'], 'u999');
        expect(sanitized['membersList'][0]['role'], 'owner');
        expect(sanitized['membersList'][0]['status'], 'active');
        expect(sanitized['membersList'][0]['displayName'], 'F***');

        expect(sanitized['members']['user-123'], 'admin');
        expect(sanitized['members']['user-456'], 'owner');
      },
    );

    test(
      'sanitizeForJson masks child properties of parent PII maps '
      'while keeping non-PII keys unmasked',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final rawData = {
          'profile': {
            'id': 'p123',
            'nickname': 'Johnny',
            'bio': 'Software developer',
            'details': 'Hidden info',
          },
        };

        final sanitized = exporter.sanitizeForJson(rawData);

        expect(sanitized['profile']['id'], 'p123');
        expect(sanitized['profile']['nickname'], 'J***');
        expect(sanitized['profile']['bio'], 'S***');
        expect(sanitized['profile']['details'], 'H***');
      },
    );

    test(
      'sanitizeForJson masks dictionary words ending in id inside PII maps '
      'without falsely matching non-PII key filter',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final rawData = {
          'member': {
            'id': 'u123',
            'memberId': 'm456',
            'user_id': 'u789',
            'android': 'device_info',
            'paid': 'subscription_status',
            'grid': 'grid_layout_data',
            'liquid': 'fluid_asset_data',
          },
        };

        final sanitized = exporter.sanitizeForJson(rawData);

        // Standard ID keys are preserved
        expect(sanitized['member']['id'], 'u123');
        expect(sanitized['member']['memberId'], 'm456');
        expect(sanitized['member']['user_id'], 'u789');

        // Words ending in 'id' inside PII maps are masked as PII
        expect(sanitized['member']['android'], 'd***');
        expect(sanitized['member']['paid'], 's***');
        expect(sanitized['member']['grid'], 'g***');
        expect(sanitized['member']['liquid'], 'f***');
      },
    );

    test(
      'sanitizeForJson preserves parent PII and email flags '
      'when recursing into nested maps',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final rawData = {
          'member': {
            'nickname': 'SuperAlice',
            'details': 'Private user details',
          },
          'profile': {'userBio': 'Personal description'},
          'emailContainer': {'value': 'nested_contact@example.com'},
        };

        final sanitized = exporter.sanitizeForJson(rawData);

        expect(sanitized['member']['nickname'], 'S***');
        expect(sanitized['member']['details'], 'P***');
        expect(sanitized['profile']['userBio'], 'P***');
        expect(sanitized['emailContainer']['value'], 'n***@example.com');
      },
    );

    test(
      'exportStateRaw falls back to local settings/state for familyId '
      'when userProfileDoc query fails',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final mockUser = MockUser();
        final mockAuthRepo = MockAuthRepository(mockUser);

        await localDataSource.saveRawSettings({
          'hoursAvailable': 8.0,
          'familyId': 'fallback-fam-123',
        });

        await fakeFirestore.collection('families').doc('fallback-fam-123').set({
          'name': 'Fallback Family Name',
        });
        await fakeFirestore
            .collection('families')
            .doc('fallback-fam-123')
            .collection('tasks')
            .doc('ftask-1')
            .set({'title': 'Fallback Task'});

        final exporter = AppStateExporter(
          firestore: fakeFirestore,
          authRepository: mockAuthRepo,
          hiveDataSource: localDataSource,
        );

        final raw = await exporter.exportStateRaw();
        final remoteState = raw['remoteFirebaseState'];

        expect(remoteState['familyDoc'], isNotNull);
        expect(remoteState['familyDoc']['id'], 'fallback-fam-123');
        expect(remoteState['familyDoc']['name'], 'F***');
        expect(remoteState['familyTasks'], hasLength(1));
        expect(remoteState['familyTasks'][0]['id'], 'ftask-1');
      },
    );

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
        expect(raw['exportMetadata']['appVersion'], AppVersion.display);

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

    test(
      'exportStateRaw keeps isOffline false '
      'when partial query error occurs online',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final mockUser = MockUser();
        final mockAuthRepo = MockAuthRepository(mockUser);

        // Populate basic user doc so Firestore is initialized & user is
        // authenticated
        await fakeFirestore.collection('users').doc('user-123').set({
          'displayName': 'Test User',
          'email': 'test@example.com',
        });

        final exporter = AppStateExporter(
          firestore: fakeFirestore,
          authRepository: mockAuthRepo,
          hiveDataSource: localDataSource,
        );

        final raw = await exporter.exportStateRaw();
        final exportMeta = raw['exportMetadata'];
        final remoteState = raw['remoteFirebaseState'];

        expect(exportMeta['isOffline'], isFalse);
        expect(remoteState['status'], 'success');
      },
    );

    testWidgets(
      'shareDebugState completes fast without 2-second timeout delay',
      (WidgetTester tester) async {
        final exporter = AppStateExporter(
          firestore: null,
          hiveDataSource: localDataSource,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => exporter.shareDebugState(context),
                    child: const Text('Share'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    test(
      'sanitizeForJson flags members key for PII sanitization while '
      'preserving roles',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final rawData = {
          'members': {
            'user-123': {
              'displayName': 'Secret Member',
              'email': 'secret@example.com',
              'role': 'parent',
            },
          },
        };

        final sanitized = exporter.sanitizeForJson(rawData);
        expect(sanitized['members']['user-123']['displayName'], 'S***');
        expect(sanitized['members']['user-123']['email'], 's***@example.com');
        expect(sanitized['members']['user-123']['role'], 'parent');
      },
    );

    test(
      'sanitizeForJson recursively routes CivilDay, RelativeTime, TimeOfDay',
      () {
        final exporter = AppStateExporter(hiveDataSource: localDataSource);

        final civilDay = const CivilDay(year: 2026, month: 8, day: 14);
        final relativeTime = const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 10, minute: 15),
        );
        const timeOfDay = TimeOfDay(hour: 12, minute: 30);

        final sanitizedCivilDay = exporter.sanitizeForJson(civilDay);
        final sanitizedRelativeTime = exporter.sanitizeForJson(relativeTime);
        final sanitizedTimeOfDay = exporter.sanitizeForJson(timeOfDay);

        expect(sanitizedCivilDay, {'year': 2026, 'month': 8, 'day': 14});
        expect(sanitizedRelativeTime, {
          'dayOffset': 0,
          'hour': 10,
          'minute': 15,
        });
        expect(sanitizedTimeOfDay, {'hour': 12, 'minute': 30});
      },
    );
  });
}
