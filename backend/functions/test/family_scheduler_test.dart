import 'package:core/core.dart';
import 'package:functions/src/handlers/family_scheduler.dart';
import 'package:functions/src/interop/firebase_admin.dart';
import 'package:functions/src/interop/firebase_functions.dart';
import 'package:functions/src/services/family_scheduler_service.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('FamilyScheduleSummary & FamilySchedulerResult', () {
    test('serializes and deserializes FamilyScheduleSummary', () {
      const summary = FamilyScheduleSummary(
        familyId: 'fam_1',
        tasksEvaluated: 5,
        instancesSpawned: 3,
        instancesUpdated: 1,
        instancesDeleted: 0,
        schedulesUpdated: 1,
      );

      final json = summary.toJson();
      expect(json['familyId'], equals('fam_1'));
      expect(json['tasksEvaluated'], equals(5));
      expect(json['instancesSpawned'], equals(3));
      expect(json['instancesUpdated'], equals(1));
      expect(json['instancesDeleted'], equals(0));
      expect(json['schedulesUpdated'], equals(1));
    });

    test('serializes and deserializes FamilySchedulerResult', () {
      const result = FamilySchedulerResult(
        success: true,
        familiesProcessed: 2,
        totalTasksEvaluated: 10,
        totalInstancesSpawned: 6,
        totalInstancesUpdated: 2,
        totalInstancesDeleted: 0,
        totalSchedulesUpdated: 2,
        durationMs: 42,
        familySummaries: [
          FamilyScheduleSummary(
            familyId: 'fam_1',
            tasksEvaluated: 5,
            instancesSpawned: 3,
          ),
          FamilyScheduleSummary(
            familyId: 'fam_2',
            tasksEvaluated: 5,
            instancesSpawned: 3,
          ),
        ],
      );

      final json = result.toJson();
      expect(json['success'], isTrue);
      expect(json['familiesProcessed'], equals(2));
      expect(json['totalInstancesSpawned'], equals(6));
      expect(json['durationMs'], equals(42));
      expect((json['familySummaries'] as List).length, equals(2));
    });
  });

  group('FamilySchedulerService.processFamily', () {
    late MockFirestoreDatabase db;
    late FamilySchedulerService service;

    setUp(() {
      db = MockFirestoreDatabase();
      service = FamilySchedulerService(db);
    });

    test('returns 0 evaluated when family has no tasks', () async {
      final summary = await service.processFamily('fam_empty');
      expect(summary.tasksEvaluated, equals(0));
      expect(summary.instancesSpawned, equals(0));
      expect(summary.instancesUpdated, equals(0));
      expect(summary.instancesDeleted, equals(0));
    });

    test('ignores non-family tasks in family collection', () async {
      final task = TaskSchedule(
        id: 'task_personal',
        title: 'Personal task mistakenly in family col',
        description: 'Personal chore',
        schedules: [
          DailySchedule(
            id: 'rule_1',
            scheduleId: 'task_personal',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 9, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 10, minute: 0),
          ),
        ],
        isFamily: false,
      );

      final familyTasksCol = db.collection('families/fam_1/tasks');
      familyTasksCol.doc(task.id).set(task.toFirestore());

      final summary = await service.processFamily('fam_1');
      expect(summary.tasksEvaluated, equals(0));
      expect(summary.instancesSpawned, equals(0));
    });

    test('spawns instances for recurring daily family task', () async {
      const startDate = CivilDay(year: 2026, month: 9, day: 10);
      final task = TaskSchedule(
        id: 'task_daily_family',
        title: 'Take out compost',
        description: 'Take compost to bin',
        isFamily: true,
        schedules: [
          DailySchedule(
            id: 'rule_1',
            scheduleId: 'task_daily_family',
            startDate: startDate,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 9, minute: 0),
          ),
        ],
      );

      final familyTasksCol = db.collection('families/fam_1/tasks');
      familyTasksCol.doc(task.id).set(task.toFirestore());

      final now = DateTime.utc(2026, 9, 10, 8, 0);
      final summary = await service.processFamily('fam_1',
          now: now, futureInstancesCount: 2);

      expect(summary.tasksEvaluated, equals(1));
      expect(summary.instancesSpawned, equals(3));
      expect(summary.schedulesUpdated, equals(1));

      // Verify instances were written to families/fam_1/instances
      final instancesCol = db.collection('families/fam_1/instances');
      expect(instancesCol.documents.length, equals(3));

      // Verify instance fields
      final firstInst = instancesCol.documents.values.first.docData!;
      expect(firstInst['scheduleId'], equals(task.id));
      expect(firstInst['isFamily'], isTrue);
      expect(firstInst['status'], equals('pending'));

      // Verify idempotency: re-running at same time spawns 0 new instances
      final secondSummary = await service.processFamily('fam_1',
          now: now, futureInstancesCount: 2);
      expect(secondSummary.tasksEvaluated, equals(1));
      expect(secondSummary.instancesSpawned, equals(0));
      expect(secondSummary.instancesUpdated, equals(0));
      expect(instancesCol.documents.length, equals(3));
    });

    test(
        'evaluates missed occurrence policy and marks overdue instances skipped',
        () async {
      const startDate = CivilDay(year: 2026, month: 9, day: 10);
      final task = TaskSchedule(
        id: 'task_auto_dismiss',
        title: 'Morning stretch',
        description: 'Morning yoga routine',
        isFamily: true,
        schedules: [
          DailySchedule(
            id: 'rule_1',
            scheduleId: 'task_auto_dismiss',
            startDate: startDate,
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 9, minute: 0),
            missedOccurrencePolicy: const MissedOccurrencePolicy(
              policy: MissedPolicy.autoDismiss,
              gracePeriod: Duration(hours: 2),
            ),
          ),
        ],
      );

      final familyTasksCol = db.collection('families/fam_1/tasks');
      familyTasksCol.doc(task.id).set(task.toFirestore());

      // 1. First run at 8:00 AM spawns pending instance
      final nowMorning = DateTime(2026, 9, 10, 8, 0);
      final summaryMorning = await service.processFamily('fam_1',
          now: nowMorning, futureInstancesCount: 0);
      expect(summaryMorning.instancesSpawned, equals(1));

      // 2. Advance time past due time + 2 hour grace period (12:00 PM)
      final nowAfternoon = DateTime(2026, 9, 10, 12, 0);
      final summaryAfternoon = await service.processFamily('fam_1',
          now: nowAfternoon, futureInstancesCount: 0);

      expect(summaryAfternoon.instancesUpdated, equals(1));

      final instancesCol = db.collection('families/fam_1/instances');
      final instData = instancesCol.documents.values.first.docData!;
      expect(instData['status'], equals('skipped'));
      expect(instData['statusReason'], equals('scheduler_auto_dismiss'));
      expect(instData['lastModifiedByPlatform'], equals('cloud_functions'));
      expect(instData['lastModifiedByUserId'], equals('cloud_scheduler'));
    });

    test(
        'completion-relative recurring family task spawns next instance when completed',
        () async {
      final task = TaskSchedule(
        id: 'task_completion_rel',
        title: 'Deep clean fridge',
        description: 'Clean out expired food and wipe shelves',
        isFamily: true,
        schedules: [
          DailySchedule(
            id: 'rule_cr',
            scheduleId: 'task_completion_rel',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 3,
            startRelativeTime: const RelativeTime(hour: 10, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 12, minute: 0),
            schedulingPolicy: const CompletionRelativePolicy(
              interval: Duration(days: 3),
              targetHour: 10,
              targetMinute: 0,
            ),
          ),
        ],
      );

      final familyTasksCol = db.collection('families/fam_1/tasks');
      familyTasksCol.doc(task.id).set(task.toFirestore());

      // 1. Initial run spawns first pending instance
      final now1 = DateTime.utc(2026, 9, 10, 10, 0);
      final summary1 = await service.processFamily('fam_1', now: now1);
      expect(summary1.instancesSpawned, equals(1));

      final instancesCol = db.collection('families/fam_1/instances');
      final firstInstId = instancesCol.documents.keys.first;

      // 2. Mark first instance completed
      final completedInstance = TaskInstance.fromMap(
        instancesCol.documents[firstInstId]!.docData!,
        id: firstInstId,
      ).copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 9, 10, 11, 30),
      );
      instancesCol.doc(firstInstId).set(completedInstance.toFirestore());

      // 3. Before interval elapsed (same day), 0 new instances spawned
      final summarySameDay = await service.processFamily('fam_1', now: now1);
      expect(summarySameDay.instancesSpawned, equals(0));

      // 4. Once completion interval elapsed (Sept 13, 12:00 PM), next instance spawned
      final now2 = DateTime.utc(2026, 9, 13, 12, 0);
      final summary2 = await service.processFamily('fam_1', now: now2);
      expect(summary2.instancesSpawned, equals(1));
      expect(instancesCol.documents.length, equals(2));

      final instancesList = instancesCol.documents.values
          .map((d) => TaskInstance.fromMap(d.docData!, id: d.id))
          .toList();
      final pendingInst =
          instancesList.firstWhere((i) => i.status == TaskStatus.pending);
      expect(pendingInst.scheduledDate,
          equals(const CivilDay(year: 2026, month: 9, day: 13)));
    });
  });

  group('FamilySchedulerService.processAllFamilies', () {
    late MockFirestoreDatabase db;
    late FamilySchedulerService service;

    setUp(() {
      db = MockFirestoreDatabase();
      service = FamilySchedulerService(db);
    });

    test('processes multiple families and aggregates metrics', () async {
      // Setup family 1
      db.collection('families').doc('fam_1').set({'name': 'Smith Family'});
      final task1 = TaskSchedule(
        id: 'task_1',
        title: 'Task 1',
        description: 'First chore',
        isFamily: true,
        schedules: [
          OneOffSchedule(
            id: 'rule_1',
            scheduleId: 'task_1',
            date: const CivilDay(year: 2026, month: 9, day: 10),
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 9, minute: 0),
          ),
        ],
      );
      db
          .collection('families/fam_1/tasks')
          .doc(task1.id)
          .set(task1.toFirestore());

      // Setup family 2
      db.collection('families').doc('fam_2').set({'name': 'Jones Family'});
      final task2 = TaskSchedule(
        id: 'task_2',
        title: 'Task 2',
        description: 'Second chore',
        isFamily: true,
        schedules: [
          OneOffSchedule(
            id: 'rule_2a',
            scheduleId: 'task_2',
            date: const CivilDay(year: 2026, month: 9, day: 10),
            startRelativeTime: const RelativeTime(hour: 10, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 11, minute: 0),
          ),
          OneOffSchedule(
            id: 'rule_2b',
            scheduleId: 'task_2',
            date: const CivilDay(year: 2026, month: 9, day: 11),
            startRelativeTime: const RelativeTime(hour: 10, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 11, minute: 0),
          ),
        ],
      );
      db
          .collection('families/fam_2/tasks')
          .doc(task2.id)
          .set(task2.toFirestore());

      final now = DateTime.utc(2026, 9, 10, 10, 0);
      final result = await service.processAllFamilies(now: now);

      expect(result.success, isTrue);
      expect(result.familiesProcessed, equals(2));
      expect(result.totalTasksEvaluated, equals(2));
      expect(result.totalInstancesSpawned, equals(3));
      expect(result.familySummaries.length, equals(2));
    });

    test('handles empty families collection gracefully', () async {
      final result = await service.processAllFamilies();
      expect(result.success, isTrue);
      expect(result.familiesProcessed, equals(0));
      expect(result.totalInstancesSpawned, equals(0));
    });
  });

  group('authenticateFamilySchedulerRequest', () {
    late MockFirestoreDatabase db;
    late MockAuthService auth;

    setUp(() {
      db = MockFirestoreDatabase();
      auth = MockAuthService();
    });

    test('authenticates valid service secret in x-service-secret', () async {
      final result = await authenticateFamilySchedulerRequest(
        {'x-service-secret': 'test_secret_123'},
        envSecret: 'test_secret_123',
      );
      expect(result.authenticated, isTrue);
      expect(result.isAdmin, isTrue);
    });

    test('authenticates valid service secret in x-api-key', () async {
      final result = await authenticateFamilySchedulerRequest(
        {'x-api-key': 'test_secret_123'},
        envSecret: 'test_secret_123',
      );
      expect(result.authenticated, isTrue);
      expect(result.isAdmin, isTrue);
    });

    test('authenticates valid service secret in Authorization Bearer',
        () async {
      final result = await authenticateFamilySchedulerRequest(
        {'authorization': 'Bearer test_secret_123'},
        envSecret: 'test_secret_123',
      );
      expect(result.authenticated, isTrue);
      expect(result.isAdmin, isTrue);
    });

    test('authenticates admin user for any family or all families', () async {
      auth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'admin_user',
            admin: true,
          );

      final result = await authenticateFamilySchedulerRequest(
        {'authorization': 'Bearer valid_admin_token'},
        auth: auth,
        db: db,
      );
      expect(result.authenticated, isTrue);
      expect(result.isAdmin, isTrue);
    });

    test('authenticates family member for their specific family', () async {
      auth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'member_user',
            admin: false,
          );

      db.collection('families').doc('fam_123').set({
        'name': 'Family',
        'members': {
          'member_user': {'role': 'member'},
        },
      });

      final result = await authenticateFamilySchedulerRequest(
        {'authorization': 'Bearer member_token'},
        familyId: 'fam_123',
        auth: auth,
        db: db,
      );
      expect(result.authenticated, isTrue);
      expect(result.uid, equals('member_user'));
      expect(result.isAdmin, isFalse);
    });

    test('rejects non-member user accessing family with 403', () async {
      auth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'stranger_user',
            admin: false,
          );

      db.collection('families').doc('fam_123').set({
        'name': 'Family',
        'members': {
          'member_user': {'role': 'member'},
        },
      });

      final result = await authenticateFamilySchedulerRequest(
        {'authorization': 'Bearer stranger_token'},
        familyId: 'fam_123',
        auth: auth,
        db: db,
      );
      expect(result.authenticated, isFalse);
      expect(result.status, equals(403));
      expect(result.error, contains('User is not a member'));
    });

    test('rejects non-admin user requesting all families with 403', () async {
      auth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'regular_user',
            admin: false,
          );

      final result = await authenticateFamilySchedulerRequest(
        {'authorization': 'Bearer regular_token'},
        auth: auth,
        db: db,
      );
      expect(result.authenticated, isFalse);
      expect(result.status, equals(403));
      expect(result.error, contains('Admin credentials required'));
    });

    test('rejects missing or invalid credentials with 401', () async {
      final result = await authenticateFamilySchedulerRequest(
        {},
        familyId: 'fam_123',
        auth: auth,
        db: db,
      );
      expect(result.authenticated, isFalse);
      expect(result.status, equals(401));
    });
  });

  group('handleProcessFamilySchedule', () {
    late MockFirestoreDatabase db;
    late MockAuthService auth;

    setUp(() {
      db = MockFirestoreDatabase();
      auth = MockAuthService();
    });

    test('rejects non-POST with 405', () async {
      final req = TestHttpRequest(method: 'GET');
      final res = TestHttpResponse();

      await handleProcessFamilySchedule(req, res, db: db, auth: auth);
      expect(res.statusCode, equals(405));
    });

    test('rejects unauthenticated request with 401', () async {
      final req = TestHttpRequest(
        method: 'POST',
        headers: {},
        body: {'familyId': 'fam_1'},
      );
      final res = TestHttpResponse();

      await handleProcessFamilySchedule(req, res, db: db, auth: auth);
      expect(res.statusCode, equals(401));
    });

    test('successfully processes single family with service secret', () async {
      final req = TestHttpRequest(
        method: 'POST',
        headers: {'x-service-secret': 'sec123'},
        body: {
          'familyId': 'fam_1',
          'now': '2026-09-10T10:00:00Z',
        },
      );
      final res = TestHttpResponse();

      // Setup task in family 1
      final task = TaskSchedule(
        id: 'task_1',
        title: 'Family Dishwashing',
        description: 'Wash dishes after dinner',
        isFamily: true,
        schedules: [
          DailySchedule(
            id: 'rule_1',
            scheduleId: 'task_1',
            startDate: const CivilDay(year: 2026, month: 9, day: 10),
            interval: 1,
            startRelativeTime: const RelativeTime(hour: 8, minute: 0),
            dueRelativeTime: const RelativeTime(hour: 9, minute: 0),
          ),
        ],
      );
      db
          .collection('families/fam_1/tasks')
          .doc(task.id)
          .set(task.toFirestore());

      await handleProcessFamilySchedule(
        req,
        res,
        db: db,
        auth: auth,
        service: FamilySchedulerService(db),
        envSecret: 'sec123',
      );

      expect(res.statusCode, equals(200));
      expect(res.responseData, isNotNull);
      expect(res.responseData['familyId'], equals('fam_1'));
      expect(res.responseData['tasksEvaluated'], equals(1));
      expect(res.responseData['instancesSpawned'], greaterThan(0));
    });

    test('successfully processes all families when admin', () async {
      auth.onVerifyIdToken = (token) async => const DecodedIdToken(
            uid: 'admin_1',
            admin: true,
          );

      final req = TestHttpRequest(
        method: 'POST',
        headers: {'authorization': 'Bearer admin_token'},
        body: {'now': '2026-09-10T10:00:00Z'},
      );
      final res = TestHttpResponse();

      await handleProcessFamilySchedule(
        req,
        res,
        db: db,
        auth: auth,
        service: FamilySchedulerService(db),
      );

      expect(res.statusCode, equals(200));
      expect(res.responseData, isNotNull);
      expect(res.responseData['success'], isTrue);
    });
  });
}
