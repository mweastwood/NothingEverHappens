import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:rxdart/rxdart.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/dashboard_stats.dart';
import 'package:nothing_ever_happens/logic/family.dart';
import 'package:nothing_ever_happens/logic/family_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'user-alice';
}

void main() {
  setUp(() {
    AppClock.setMockTime(DateTime(2026, 7, 10, 12, 0)); // Reference date
  });

  tearDown(() {
    AppClock.reset();
  });

  final dummyStart = const RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 9, minute: 0),
  );
  final dummyDue = const RelativeTime(
    dayOffset: 0,
    time: TimeOfDay(hour: 17, minute: 0),
  );

  group('personalLastWeekStatsProvider', () {
    testWidgets(
      'aggregates personal tasks within rolling 7-day window and ignores out-of-range tasks',
      (tester) async {
        final schedule1 = TaskSchedule(
          id: 's-1',
          title: 'Task 1',
          description: 'Desc',
          estimatedDuration: const Duration(minutes: 60),
          schedules: [],
        );
        final schedule2 = TaskSchedule(
          id: 's-2',
          title: 'Task 2',
          description: 'Desc',
          estimatedDuration: const Duration(minutes: 30),
          schedules: [],
        );

        final tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([
          schedule1,
          schedule2,
        ]);
        final instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([
          // 1. Completed inside window (2026-07-10) -> 60m
          TaskInstance(
            id: 'i-1',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Task 1',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 10),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedByUserId: 'user-alice',
          ),
          // 2. Completed inside window (2026-07-05) -> 30m
          TaskInstance(
            id: 'i-2',
            scheduleId: schedule2.id,
            ruleId: 'r-2',
            title: 'Task 2',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 5),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedByUserId: 'user-alice',
          ),
          // 3. Completed OUTSIDE window (2026-07-03, which is 7 days before today)
          TaskInstance(
            id: 'i-3',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Task 1',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 3),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.completed,
            completedByUserId: 'user-alice',
          ),
          // 4. Skipped inside window (2026-07-08)
          TaskInstance(
            id: 'i-4',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Task 1',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 8),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.skipped,
            completedByUserId: 'user-alice',
          ),
          // 5. Past pending (missed) inside window (2026-07-06)
          TaskInstance(
            id: 'i-5',
            scheduleId: schedule2.id,
            ruleId: 'r-2',
            title: 'Task 2',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 6),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            status: TaskStatus.pending,
            assignedUserId: 'user-alice',
          ),
        ]);
        final authSubject = BehaviorSubject<User?>.seeded(MockUser());

        addTearDown(() {
          tasksSubject.close();
          instancesSubject.close();
          authSubject.close();
        });

        late PersonalLastWeekStats stats;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => authSubject.stream),
              taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
              taskInstancesProvider.overrideWith(
                (ref) => instancesSubject.stream,
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                stats = ref.watch(personalLastWeekStatsProvider);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(stats.completedCount, 2);
        expect(stats.completedHours, 1.5); // 60m + 30m = 1.5h
        expect(stats.skippedCount, 1);
        expect(stats.missedCount, 1);
        expect(stats.completionRate, 2 / (2 + 1 + 1)); // 50%
        expect(stats.hasActivity, isTrue);
        expect(stats.dailyStats.length, 7);
      },
    );
  });

  group('familyLastWeekStatsProvider', () {
    testWidgets('returns null when user is not in a family', (tester) async {
      late FamilyLastWeekStats? stats;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyProfileStreamProvider.overrideWith(
              (ref) => BehaviorSubject<FamilyProfile?>.seeded(null).stream,
            ),
            taskSchedulesProvider.overrideWith(
              (ref) => BehaviorSubject<List<TaskSchedule>>.seeded([]).stream,
            ),
            taskInstancesProvider.overrideWith(
              (ref) => BehaviorSubject<List<TaskInstance>>.seeded([]).stream,
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              stats = ref.watch(familyLastWeekStatsProvider);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(stats, isNull);
    });

    testWidgets(
      'strictly filters for isFamily == true and breaks down by member',
      (tester) async {
        final schedule1 = TaskSchedule(
          id: 's-fam',
          title: 'Family Dishes',
          description: 'Desc',
          estimatedDuration: const Duration(minutes: 45),
          isFamily: true,
          schedules: [],
        );
        final schedule2 = TaskSchedule(
          id: 's-priv',
          title: 'Secret Task',
          description: 'Desc',
          estimatedDuration: const Duration(minutes: 60),
          isFamily: false,
          schedules: [],
        );

        final profileSubject = BehaviorSubject<FamilyProfile?>.seeded(
          const FamilyProfile(familyId: 'fam-100', familyRole: 'parent'),
        );
        final familySubject = BehaviorSubject<Family?>.seeded(
          const Family(
            id: 'fam-100',
            name: 'Smiths',
            members: {
              'user-alice': FamilyMember(
                userId: 'user-alice',
                displayName: 'Alice',
                email: 'alice@example.com',
                role: FamilyRole.parent,
              ),
              'user-bob': FamilyMember(
                userId: 'user-bob',
                displayName: 'Bob',
                email: 'bob@example.com',
                role: FamilyRole.parent,
              ),
            },
          ),
        );
        final tasksSubject = BehaviorSubject<List<TaskSchedule>>.seeded([
          schedule1,
          schedule2,
        ]);
        final instancesSubject = BehaviorSubject<List<TaskInstance>>.seeded([
          // 1. Family task completed by Alice (45 min)
          TaskInstance(
            id: 'i-fam-1',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Family Dishes',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 10),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            isFamily: true,
            status: TaskStatus.completed,
            completedByUserId: 'user-alice',
          ),
          // 2. Family task completed by Bob (45 min)
          TaskInstance(
            id: 'i-fam-2',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Family Dishes',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 9),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            isFamily: true,
            status: TaskStatus.completed,
            completedByUserId: 'user-bob',
          ),
          // 3. Family task skipped by Bob
          TaskInstance(
            id: 'i-fam-3',
            scheduleId: schedule1.id,
            ruleId: 'r-1',
            title: 'Family Dishes',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 8),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            isFamily: true,
            status: TaskStatus.skipped,
            completedByUserId: 'user-bob',
          ),
          // 4. Private non-family task completed by Alice (MUST BE EXCLUDED)
          TaskInstance(
            id: 'i-priv-1',
            scheduleId: schedule2.id,
            ruleId: 'r-2',
            title: 'Secret Task',
            description: 'Desc',
            scheduledDate: CivilDay(year: 2026, month: 7, day: 10),
            startRelativeTime: dummyStart,
            dueRelativeTime: dummyDue,
            isFamily: false,
            status: TaskStatus.completed,
            completedByUserId: 'user-alice',
          ),
        ]);

        addTearDown(() {
          profileSubject.close();
          familySubject.close();
          tasksSubject.close();
          instancesSubject.close();
        });

        late FamilyLastWeekStats? stats;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              familyProfileStreamProvider.overrideWith(
                (ref) => profileSubject.stream,
              ),
              familyStreamProvider(
                'fam-100',
              ).overrideWith((ref) => familySubject.stream),
              taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
              taskInstancesProvider.overrideWith(
                (ref) => instancesSubject.stream,
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                stats = ref.watch(familyLastWeekStatsProvider);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(stats, isNotNull);
        expect(stats!.familyName, 'Smiths');
        expect(
          stats!.totalCompletedCount,
          2,
        ); // 1 for Alice, 1 for Bob (private excluded)
        expect(stats!.totalCompletedHours, 1.5); // 45m + 45m = 90m = 1.5h
        expect(stats!.totalSkippedCount, 1);
        expect(stats!.completionRate, 2 / 3);

        final alice = stats!.memberStats.firstWhere(
          (m) => m.userId == 'user-alice',
        );
        expect(alice.completedCount, 1);
        expect(alice.completedHours, 0.75);
        expect(alice.contributionPercentage, 0.5);

        final bob = stats!.memberStats.firstWhere(
          (m) => m.userId == 'user-bob',
        );
        expect(bob.completedCount, 1);
        expect(bob.completedHours, 0.75);
        expect(bob.skippedCount, 1);
        expect(bob.contributionPercentage, 0.5);
      },
    );
  });
}
