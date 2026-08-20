import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/system_tasks/system_task.dart';
import 'package:nothing_ever_happens/logic/system_tasks/system_task_providers.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';

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
      'activeSystemTasksProvider returns empty list when confirmed for current week',
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
}
