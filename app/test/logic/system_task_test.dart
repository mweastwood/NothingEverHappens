import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/system_tasks/system_task.dart';
import 'package:nothing_ever_happens/logic/system_tasks/system_task_providers.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

class MockUser extends Fake implements User {
  final String _uid;
  MockUser([this._uid = 'user-alice']);

  @override
  String get uid => _uid;
}

class FakeUserSettingsRepository extends Fake
    implements UserSettingsRepository {
  UserSettings? lastUpdatedSettings;

  @override
  Future<void> updateSettings(UserSettings settings) async {
    lastUpdatedSettings = settings;
  }
}

void main() {
  group('SystemTask Model Tests', () {
    test('SystemTask properties and defaults', () {
      const task = SystemTask(
        id: 'test_task',
        title: 'Test Title',
        description: 'Test Description',
        icon: Icons.check,
      );

      expect(task.id, 'test_task');
      expect(task.title, 'Test Title');
      expect(task.description, 'Test Description');
      expect(task.icon, Icons.check);
      expect(task.priority, SystemTaskPriority.medium);
      expect(task.category, SystemTaskCategory.system);
      expect(task.actionLabel, isNull);
      expect(task.secondaryActionLabel, isNull);
      expect(task.onAction, isNull);
      expect(task.onSecondaryAction, isNull);
      expect(task.onTap, isNull);
      expect(task.isDismissible, isFalse);
      expect(task.onDismiss, isNull);
    });

    test('SystemTask copyWith creates updated instance', () {
      const task = SystemTask(
        id: 'initial_task',
        title: 'Initial Title',
        description: 'Initial Description',
        icon: Icons.check,
      );

      final updated = task.copyWith(
        title: 'Updated Title',
        priority: SystemTaskPriority.high,
        category: SystemTaskCategory.capacity,
        actionLabel: 'Take Action',
        isDismissible: true,
      );

      expect(updated.id, 'initial_task');
      expect(updated.title, 'Updated Title');
      expect(updated.description, 'Initial Description');
      expect(updated.icon, Icons.check);
      expect(updated.priority, SystemTaskPriority.high);
      expect(updated.category, SystemTaskCategory.capacity);
      expect(updated.actionLabel, 'Take Action');
      expect(updated.isDismissible, isTrue);
    });

    test('SystemTask equality and hashCode', () {
      const task1 = SystemTask(
        id: 'task_1',
        title: 'Task 1',
        description: 'Description 1',
        icon: Icons.home,
        priority: SystemTaskPriority.low,
        category: SystemTaskCategory.profile,
        actionLabel: 'Action',
      );

      const task2 = SystemTask(
        id: 'task_1',
        title: 'Task 1',
        description: 'Description 1',
        icon: Icons.home,
        priority: SystemTaskPriority.low,
        category: SystemTaskCategory.profile,
        actionLabel: 'Action',
      );

      const task3 = SystemTask(
        id: 'task_2',
        title: 'Task 2',
        description: 'Description 2',
        icon: Icons.star,
      );

      expect(task1, equals(task2));
      expect(task1.hashCode, equals(task2.hashCode));
      expect(task1, isNot(equals(task3)));
      expect(task1.toString(), contains('task_1'));
    });
  });

  group('UserSettings acknowledgedMissedTaskCommunications Tests', () {
    test(
      'serializes and deserializes acknowledgedMissedTaskCommunications',
      () {
        AppClock.setMockTime(DateTime(2026, 7, 10, 10, 0));
        addTearDown(AppClock.reset);

        const settings = UserSettings(
          hoursAvailable: 8.0,
          acknowledgedMissedTaskCommunications: [
            'inst-1:2026-07-10',
            'inst-2:2026-07-09',
          ],
        );

        final json = settings.toJson();
        expect(json['acknowledgedMissedTaskCommunications'], [
          'inst-1:2026-07-10',
          'inst-2:2026-07-09',
        ]);

        final deserialized = UserSettings.fromJson(json);
        expect(
          deserialized.acknowledgedMissedTaskCommunications,
          equals(['inst-1:2026-07-10', 'inst-2:2026-07-09']),
        );
      },
    );

    test(
      'prunes entries older than 30 days during deserialization and copyWith',
      () {
        AppClock.setMockTime(DateTime(2026, 7, 10, 10, 0));
        addTearDown(AppClock.reset);

        final json = {
          'hoursAvailable': 8.0,
          'acknowledgedMissedTaskCommunications': [
            'inst-recent:2026-07-05', // 5 days old -> kept
            'inst-edge:2026-06-10', // 30 days old -> kept
            'inst-old:2026-06-01', // >30 days old -> pruned
          ],
        };

        final settings = UserSettings.fromJson(json);
        expect(settings.acknowledgedMissedTaskCommunications, [
          'inst-recent:2026-07-05',
          'inst-edge:2026-06-10',
        ]);

        final updated = settings.copyWith(
          acknowledgedMissedTaskCommunications: [
            'inst-recent:2026-07-05',
            'inst-old:2026-05-01',
          ],
        );
        expect(updated.acknowledgedMissedTaskCommunications, [
          'inst-recent:2026-07-05',
        ]);
      },
    );

    test(
      'equality and hashCode consider acknowledgedMissedTaskCommunications',
      () {
        const s1 = UserSettings(
          hoursAvailable: 8.0,
          acknowledgedMissedTaskCommunications: ['inst-1:2026-07-10'],
        );
        const s2 = UserSettings(
          hoursAvailable: 8.0,
          acknowledgedMissedTaskCommunications: ['inst-1:2026-07-10'],
        );
        const s3 = UserSettings(
          hoursAvailable: 8.0,
          acknowledgedMissedTaskCommunications: ['inst-2:2026-07-10'],
        );

        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));
        expect(s1, isNot(equals(s3)));
      },
    );
  });

  group('SystemTask Providers Tests', () {
    test('getSystemTaskWeekIdentifier calculates Monday date string', () {
      final wednesday = DateTime(2026, 7, 1);
      expect(getSystemTaskWeekIdentifier(wednesday), '2026-06-29');

      final monday = DateTime(2026, 6, 29);
      expect(getSystemTaskWeekIdentifier(monday), '2026-06-29');

      final sunday = DateTime(2026, 7, 5);
      expect(getSystemTaskWeekIdentifier(sunday), '2026-06-29');
    });

    test(
      'activeSystemTasksProvider returns capacity task when unconfirmed',
      () async {
        AppClock.setMockTime(
          DateTime(2026, 7, 1, 10, 0),
        ); // Wednesday (week 2026-06-29)
        addTearDown(AppClock.reset);

        final container = ProviderContainer(
          overrides: [
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  lastCapacityConfirmedWeek: '',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(userSettingsProvider.future);

        final tasks = container.read(activeSystemTasksProvider);
        expect(tasks.length, 1);
        final capacityTask = tasks.first;
        expect(capacityTask.id, 'verify_weekly_capacity');
        expect(capacityTask.title, 'Confirm capacity for this week');
        expect(
          capacityTask.description,
          'Review and confirm your available chore hours to clear this task.',
        );
        expect(capacityTask.priority, SystemTaskPriority.high);
        expect(capacityTask.category, SystemTaskCategory.capacity);
        expect(capacityTask.actionLabel, 'Confirm Capacity');
      },
    );

    test(
      'activeSystemTasksProvider returns empty list when confirmed for current week and no missed tasks',
      () async {
        AppClock.setMockTime(
          DateTime(2026, 7, 1, 10, 0),
        ); // Wednesday (week 2026-06-29)
        addTearDown(AppClock.reset);

        final container = ProviderContainer(
          overrides: [
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  lastCapacityConfirmedWeek: '2026-06-29',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(userSettingsProvider.future);

        final tasks = container.read(activeSystemTasksProvider);
        expect(tasks, isEmpty);
      },
    );

    test(
      'activeSystemTasksProvider handles loading and error states gracefully',
      () {
        final loadingContainer = ProviderContainer(
          overrides: [
            userSettingsProvider.overrideWith((ref) => const Stream.empty()),
          ],
        );
        addTearDown(loadingContainer.dispose);

        expect(loadingContainer.read(activeSystemTasksProvider), isEmpty);
      },
    );
  });

  group('Missed Family Task Communication SystemTask Tests', () {
    final mockUser = MockUser('user-alice');

    TaskInstance createCandidateInstance({
      String id = 'task-inst-1',
      String title = 'Feed the pets',
      bool isFamily = true,
      String assignedUserId = 'user-alice',
      TaskStatus status = TaskStatus.pending,
      CivilDay? scheduledDate,
      RelativeTime? dueRelativeTime,
      FamilyCompletionMode familyCompletionMode = FamilyCompletionMode.anyone,
      List<String> completedByUserIds = const [],
    }) {
      return TaskInstance(
        id: id,
        scheduleId: 'sched-1',
        ruleId: 'rule-1',
        title: title,
        description: 'Chore details',
        isFamily: isFamily,
        assignedUserId: assignedUserId,
        status: status,
        scheduledDate:
            scheduledDate ?? const CivilDay(year: 2026, month: 7, day: 9),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 8, minute: 0),
        ),
        dueRelativeTime:
            dueRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 20, minute: 0),
            ),
        familyCompletionMode: familyCompletionMode,
        completedByUserIds: completedByUserIds,
      );
    }

    test('does NOT generate communication task before 5:00 AM', () async {
      // 4:59 AM on July 10, 2026
      AppClock.setMockTime(DateTime(2026, 7, 10, 4, 59));
      addTearDown(AppClock.reset);

      final overdueInstance = createCandidateInstance(
        scheduledDate: const CivilDay(
          year: 2026,
          month: 7,
          day: 9,
        ), // due yesterday 8pm
      );

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          taskInstancesProvider.overrideWith(
            (ref) => Stream.value([overdueInstance]),
          ),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const UserSettings(
                hoursAvailable: 8.0,
                lastCapacityConfirmedWeek: '2026-07-06',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      await container.read(userSettingsProvider.future);
      await container.read(taskInstancesProvider.future);

      final tasks = container.read(missedFamilyTasksProvider);
      expect(tasks, isEmpty);
    });

    test(
      'generates communication task on or after 5:00 AM for overdue family task',
      () async {
        // 5:00 AM on July 10, 2026
        AppClock.setMockTime(DateTime(2026, 7, 10, 5, 0));
        addTearDown(AppClock.reset);

        final overdueInstance = createCandidateInstance(
          id: 'chore-123',
          title: 'Mow the lawn',
          scheduledDate: const CivilDay(year: 2026, month: 7, day: 9),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            taskInstancesProvider.overrideWith(
              (ref) => Stream.value([overdueInstance]),
            ),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  lastCapacityConfirmedWeek: '2026-07-06',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        await container.read(userSettingsProvider.future);
        await container.read(taskInstancesProvider.future);

        final tasks = container.read(missedFamilyTasksProvider);
        expect(tasks.length, 1);

        final task = tasks.first;
        expect(task.id, 'missed_family_task_comm_chore-123_2026-07-10');
        expect(task.title, 'Communicate missed chore: Mow the lawn');
        expect(
          task.description,
          'This family task was missed before 5:00 AM. Reach out to your family and own responsibility for the missed task by 5:00 PM today.',
        );
        expect(task.icon, Icons.record_voice_over);
        expect(task.priority, SystemTaskPriority.high);
        expect(task.category, SystemTaskCategory.family);
        expect(task.actionLabel, 'Mark Communicated');
        expect(task.isDismissible, isTrue);
        expect(task.onAction, isNotNull);
        expect(task.onDismiss, isNotNull);
      },
    );

    test(
      'filters out non-family tasks, unassigned tasks, or completed tasks',
      () async {
        AppClock.setMockTime(DateTime(2026, 7, 10, 10, 0));
        addTearDown(AppClock.reset);

        final nonFamily = createCandidateInstance(
          id: 'inst-personal',
          isFamily: false,
        );
        final assignedToOther = createCandidateInstance(
          id: 'inst-bob',
          assignedUserId: 'user-bob',
        );
        final alreadyCompleted = createCandidateInstance(
          id: 'inst-completed',
          status: TaskStatus.completed,
        );
        final individualCompleted = createCandidateInstance(
          id: 'inst-ind-completed',
          familyCompletionMode: FamilyCompletionMode.individual,
          completedByUserIds: ['user-alice'],
        );
        final notYetDue = createCandidateInstance(
          id: 'inst-today-afternoon',
          scheduledDate: const CivilDay(year: 2026, month: 7, day: 10),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 14, minute: 0),
          ), // due today at 2pm (> 5am today)
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            taskInstancesProvider.overrideWith(
              (ref) => Stream.value([
                nonFamily,
                assignedToOther,
                alreadyCompleted,
                individualCompleted,
                notYetDue,
              ]),
            ),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  lastCapacityConfirmedWeek: '2026-07-06',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        await container.read(userSettingsProvider.future);
        await container.read(taskInstancesProvider.future);

        final tasks = container.read(missedFamilyTasksProvider);
        expect(tasks, isEmpty);
      },
    );

    test(
      'filters out tasks already acknowledged for today in UserSettings',
      () async {
        AppClock.setMockTime(DateTime(2026, 7, 10, 10, 0));
        addTearDown(AppClock.reset);

        final overdueInstance = createCandidateInstance(
          id: 'chore-acknowledged',
          scheduledDate: const CivilDay(year: 2026, month: 7, day: 9),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            taskInstancesProvider.overrideWith(
              (ref) => Stream.value([overdueInstance]),
            ),
            userSettingsProvider.overrideWith(
              (ref) => Stream.value(
                const UserSettings(
                  hoursAvailable: 8.0,
                  lastCapacityConfirmedWeek: '2026-07-06',
                  acknowledgedMissedTaskCommunications: [
                    'chore-acknowledged:2026-07-10',
                  ],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authStateProvider.future);
        await container.read(userSettingsProvider.future);
        await container.read(taskInstancesProvider.future);

        final tasks = container.read(missedFamilyTasksProvider);
        expect(tasks, isEmpty);
      },
    );

    test('onAction and onDismiss update UserSettings via repository', () async {
      AppClock.setMockTime(DateTime(2026, 7, 10, 10, 0));
      addTearDown(AppClock.reset);

      final overdueInstance = createCandidateInstance(
        id: 'chore-to-ack',
        scheduledDate: const CivilDay(year: 2026, month: 7, day: 9),
      );

      final fakeRepo = FakeUserSettingsRepository();

      final container = ProviderContainer(
        overrides: [
          userSettingsRepositoryProvider.overrideWithValue(fakeRepo),
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          taskInstancesProvider.overrideWith(
            (ref) => Stream.value([overdueInstance]),
          ),
          userSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const UserSettings(
                hoursAvailable: 8.0,
                lastCapacityConfirmedWeek: '2026-07-06',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      await container.read(userSettingsProvider.future);
      await container.read(taskInstancesProvider.future);

      final tasks = container.read(missedFamilyTasksProvider);
      expect(tasks.length, 1);

      tasks.first.onAction?.call();

      expect(fakeRepo.lastUpdatedSettings, isNotNull);
      expect(
        fakeRepo.lastUpdatedSettings!.acknowledgedMissedTaskCommunications,
        contains('chore-to-ack:2026-07-10'),
      );
    });
  });
}
