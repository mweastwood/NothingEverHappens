import 'package:flutter/material.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';

class TestTaskFactory {
  static TaskSchedule createDaily({
    String id = 'task-1',
    String title = 'Test Task',
    String description = 'Test description',
    TaskPriority priority = TaskPriority.medium,
    bool isFamily = false,
    bool isMaster = false,
    String? assignedUserId,
    String? cycleId,
    CivilDay? startDate,
    int interval = 1,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
    Duration? estimatedDuration,
    bool skipIfNoCapacity = false,
    CivilDay? lastSpawnedDate,
    Map<String, bool> preferredBy = const {},
  }) {
    return TaskSchedule(
      id: id,
      title: title,
      description: description,
      priority: priority,
      isFamily: isFamily,
      isMaster: isMaster,
      assignedUserId: assignedUserId,
      cycleId: cycleId,
      estimatedDuration: estimatedDuration,
      skipIfNoCapacity: skipIfNoCapacity,
      lastSpawnedDate: lastSpawnedDate,
      preferredBy: preferredBy,
      schedules: [
        DailySchedule(
          startDate: startDate ?? const CivilDay(year: 2024, month: 1, day: 1),
          interval: interval,
          startRelativeTime:
              startRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
          dueRelativeTime:
              dueRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
          notificationRelativeTimes: notificationRelativeTimes ?? const [],
          schedulingPolicy: schedulingPolicy,
          missedOccurrencePolicy: missedOccurrencePolicy,
        ),
      ],
    );
  }

  static TaskSchedule createWeekly({
    String id = 'task-1',
    String title = 'Test Task',
    String description = 'Test description',
    TaskPriority priority = TaskPriority.medium,
    bool isFamily = false,
    bool isMaster = false,
    String? assignedUserId,
    String? cycleId,
    CivilDay? startDate,
    int interval = 1,
    Set<int>? daysOfWeek,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
    Duration? estimatedDuration,
    bool skipIfNoCapacity = false,
    CivilDay? lastSpawnedDate,
    Map<String, bool> preferredBy = const {},
  }) {
    return TaskSchedule(
      id: id,
      title: title,
      description: description,
      priority: priority,
      isFamily: isFamily,
      isMaster: isMaster,
      assignedUserId: assignedUserId,
      cycleId: cycleId,
      estimatedDuration: estimatedDuration,
      skipIfNoCapacity: skipIfNoCapacity,
      lastSpawnedDate: lastSpawnedDate,
      preferredBy: preferredBy,
      schedules: [
        WeeklySchedule(
          startDate: startDate ?? const CivilDay(year: 2024, month: 1, day: 1),
          interval: interval,
          daysOfWeek: daysOfWeek ?? {DateTime.monday},
          startRelativeTime:
              startRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
          dueRelativeTime:
              dueRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
          notificationRelativeTimes: notificationRelativeTimes ?? const [],
          schedulingPolicy: schedulingPolicy,
          missedOccurrencePolicy: missedOccurrencePolicy,
        ),
      ],
    );
  }

  static TaskSchedule createOneOff({
    String id = 'task-1',
    String title = 'Test Task',
    String description = 'Test description',
    TaskPriority priority = TaskPriority.medium,
    bool isFamily = false,
    bool isMaster = false,
    String? assignedUserId,
    String? cycleId,
    CivilDay? date,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    SchedulingPolicy? schedulingPolicy,
    MissedOccurrencePolicy? missedOccurrencePolicy,
    Duration? estimatedDuration,
    bool skipIfNoCapacity = false,
    CivilDay? lastSpawnedDate,
    Map<String, bool> preferredBy = const {},
  }) {
    return TaskSchedule(
      id: id,
      title: title,
      description: description,
      priority: priority,
      isFamily: isFamily,
      isMaster: isMaster,
      assignedUserId: assignedUserId,
      cycleId: cycleId,
      estimatedDuration: estimatedDuration,
      skipIfNoCapacity: skipIfNoCapacity,
      lastSpawnedDate: lastSpawnedDate,
      preferredBy: preferredBy,
      schedules: [
        OneOffSchedule(
          date: date ?? const CivilDay(year: 2024, month: 1, day: 1),
          startRelativeTime:
              startRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
          dueRelativeTime:
              dueRelativeTime ??
              const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
          notificationRelativeTimes: notificationRelativeTimes ?? const [],
          schedulingPolicy: schedulingPolicy,
          missedOccurrencePolicy: missedOccurrencePolicy,
        ),
      ],
    );
  }

  static TaskInstance createInstance({
    String id = 'instance-1',
    String scheduleId = 'task-1',
    String ruleId = 'rule-1',
    String title = 'Test Task',
    String description = 'Test description',
    CivilDay? scheduledDate,
    RelativeTime? startRelativeTime,
    RelativeTime? dueRelativeTime,
    List<RelativeTime>? notificationRelativeTimes,
    bool isFamily = false,
    TaskPriority priority = TaskPriority.medium,
    String? cycleId,
    String? assignedUserId,
    String? completedByUserId,
    DateTime? completedAt,
    TaskStatus status = TaskStatus.pending,
  }) {
    return TaskInstance(
      id: id,
      scheduleId: scheduleId,
      ruleId: ruleId,
      title: title,
      description: description,
      scheduledDate:
          scheduledDate ?? const CivilDay(year: 2024, month: 1, day: 1),
      startRelativeTime:
          startRelativeTime ??
          const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
      dueRelativeTime:
          dueRelativeTime ??
          const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
      notificationRelativeTimes: notificationRelativeTimes ?? const [],
      isFamily: isFamily,
      priority: priority,
      cycleId: cycleId,
      assignedUserId: assignedUserId,
      completedByUserId: completedByUserId,
      completedAt: completedAt,
      status: status,
    );
  }

  static RelativeTime createRelativeTime({
    int dayOffset = 0,
    int hour = 9,
    int minute = 0,
  }) {
    return RelativeTime(
      dayOffset: dayOffset,
      time: TimeOfDay(hour: hour, minute: minute),
    );
  }
}
