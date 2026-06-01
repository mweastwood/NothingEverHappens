import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'task.dart';
import 'civil_day.dart';
import 'notification_helper.dart';

/// Abstract service to handle scheduling and cancelling of task notifications.
abstract class NotificationService {
  /// Schedules notification reminders for the given [task] according to its occurrences.
  Future<void> scheduleNotifications(Task task);

  /// Cancels all scheduled notifications for the task with [taskId].
  Future<void> cancelNotifications(String taskId);
}

/// Production implementation of NotificationService for Android and Web (Chrome).
class PlatformNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final Map<String, List<Timer>> _webTimers = {};

  PlatformNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin() {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      requestWebNotificationPermission();
      return;
    }

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _plugin.initialize(settings: initializationSettings);

      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('Failed to initialize platform notifications: $e');
    }
  }

  @override
  Future<void> scheduleNotifications(Task task) async {
    // First, cancel any existing notifications for this task to avoid duplicates
    await cancelNotifications(task.id);

    debugPrint(
      'PlatformNotificationService: Scheduling notifications for task: ${task.title} (ID: ${task.id})',
    );

    for (var i = 0; i < task.dailyTimes.length; i++) {
      final slot = task.dailyTimes[i];
      if (slot.notificationTime == null) continue;

      if (kIsWeb) {
        final scheduledDate = _calculateNextNotificationDateTime(task, slot);
        final delay = scheduledDate.difference(DateTime.now());
        if (delay.isNegative) continue;

        debugPrint(
          '  - [Web] Scheduling timer in ${delay.inMinutes} minutes at $scheduledDate',
        );
        final timer = Timer(delay, () {
          showWebNotification(
            task.title,
            task.description.isNotEmpty
                ? task.description
                : 'Reminder for your task',
          );
          // Reschedule for the next occurrence once it fires
          scheduleNotifications(task);
        });

        _webTimers.putIfAbsent(task.id, () => []).add(timer);
      } else {
        final scheduledDate = _calculateNextNotificationDateTime(task, slot);
        final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
        final notifId = (task.id.hashCode + i) & 0x7FFFFFFF;

        debugPrint(
          '  - [Android] Scheduling exact notification at $tzDate (ID: $notifId)',
        );
        try {
          await _plugin.zonedSchedule(
            id: notifId,
            title: task.title,
            body: task.description.isNotEmpty
                ? task.description
                : 'Reminder for your task',
            scheduledDate: tzDate,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'task_reminders_channel',
                'Task Reminders',
                channelDescription:
                    'Notifications for task occurrences and schedules',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (e) {
          try {
            await _plugin.zonedSchedule(
              id: notifId,
              title: task.title,
              body: task.description.isNotEmpty
                  ? task.description
                  : 'Reminder for your task',
              scheduledDate: tzDate,
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'task_reminders_channel',
                  'Task Reminders',
                  channelDescription:
                      'Notifications for task occurrences and schedules',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.inexact,
            );
          } catch (ex) {
            debugPrint('Failed to schedule Android notification: $ex');
          }
        }
      }
    }
  }

  @override
  Future<void> cancelNotifications(String taskId) async {
    debugPrint(
      'PlatformNotificationService: Cancelling notifications for task ID: $taskId',
    );

    if (kIsWeb) {
      final timers = _webTimers.remove(taskId);
      if (timers != null) {
        for (final timer in timers) {
          timer.cancel();
        }
      }
    } else {
      // Cancel slots on Android. We can cancel by ID
      // To cancel safely, we cancel all notification IDs associated with the task
      // ID calculation is (task.id.hashCode + i) & 0x7FFFFFFF.
      for (var i = 0; i < 10; i++) {
        final notifId = (taskId.hashCode + i) & 0x7FFFFFFF;
        try {
          await _plugin.cancel(id: notifId);
        } catch (e) {
          // Ignore
        }
      }
    }
  }

  DateTime _calculateNextNotificationDateTime(
    Task task,
    DailyOccurrenceTime slot,
  ) {
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < 365; i++) {
      final civilDay = CivilDay(
        year: checkDate.year,
        month: checkDate.month,
        day: checkDate.day,
      );

      if (task.schedule.occursOn(civilDay)) {
        final occurrenceDateTime = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          slot.notificationTime!.hour,
          slot.notificationTime!.minute,
        );

        if (occurrenceDateTime.isAfter(now)) {
          return occurrenceDateTime;
        }
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }

    return now.add(const Duration(days: 1));
  }
}

/// Simulated Notification Service that prints log statements to debug console
/// and tracks all scheduled tasks in-memory for testing and local verification.
class LoggingNotificationService implements NotificationService {
  final Map<String, Task> _scheduledTasks = {};

  /// Exposes a read-only view of currently scheduled tasks.
  Map<String, Task> get scheduledTasks => Map.unmodifiable(_scheduledTasks);

  @override
  Future<void> scheduleNotifications(Task task) async {
    _scheduledTasks[task.id] = task;
    debugPrint(
      'Scheduling notifications for task: ${task.title} (ID: ${task.id})',
    );
    for (var i = 0; i < task.dailyTimes.length; i++) {
      final slot = task.dailyTimes[i];
      if (slot.notificationTime != null) {
        debugPrint(
          '  - Scheduled occurrence reminder #$i at ${slot.notificationTime!.hour.toString().padLeft(2, '0')}:${slot.notificationTime!.minute.toString().padLeft(2, '0')}',
        );
      } else {
        debugPrint('  - Occurrence #$i: No custom notification configured');
      }
    }
  }

  @override
  Future<void> cancelNotifications(String taskId) async {
    _scheduledTasks.remove(taskId);
    debugPrint('Cancelling all notifications for task ID: $taskId');
  }

  /// Clears all scheduled tasks in memory.
  void clear() {
    _scheduledTasks.clear();
  }
}
