import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'task_schedule.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'notification_helper.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = PlatformNotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Abstract contract for scheduling exact and zoned local push notifications.
abstract class NotificationService {
  Future<void> scheduleNotifications(TaskSchedule task);
  Future<void> cancelNotifications(String taskId);
  Future<void> cancelAllNotifications();
  Future<void> dispose();
}

/// Production implementation that delegates to `flutter_local_notifications` plugin
/// to schedule exact zoned alarms on Android and local notifications on iOS.
class PlatformNotificationService implements NotificationService {
  static final int _currentRunId = DateTime.now().millisecondsSinceEpoch;
  final int _runId = _currentRunId;
  bool _isDisposed = false;

  final FlutterLocalNotificationsPlugin _plugin;
  final Map<String, List<Timer>> _webTimers = {};
  final Map<String, TaskSchedule> _scheduledTasks = {};
  final TaskSchedule? Function(String taskId)? _taskLookup;
  final bool _isWeb;
  final void Function(String title, String body)? _onWebNotification;

  PlatformNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    TaskSchedule? Function(String taskId)? taskLookup,
    bool isWeb = kIsWeb,
    void Function(String title, String body)? onWebNotification,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _taskLookup = taskLookup,
       _isWeb = isWeb,
       _onWebNotification = onWebNotification {
    _initialize();
  }

  /// Exposes a read-only view of currently scheduled tasks.
  Map<String, TaskSchedule> get scheduledTasks =>
      Map.unmodifiable(_scheduledTasks);

  @visibleForTesting
  Map<String, List<Timer>> get webTimers => Map.unmodifiable(_webTimers);

  Future<void> _initialize() async {
    if (_isWeb) {
      if (_isDisposed || _runId != _currentRunId) return;
      requestWebNotificationPermission();
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (e) {
        debugPrint(
          'PlatformNotificationService: Failed to set local location, defaulting to UTC: $e',
        );
        tz.setLocalLocation(tz.UTC);
      }

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
  Future<void> scheduleNotifications(TaskSchedule task) async {
    if (_isDisposed || _runId != _currentRunId) return;

    // First, cancel any existing notifications for this task to avoid duplicates
    await cancelNotifications(task.id);

    if (_isDisposed || _runId != _currentRunId) return;

    _scheduledTasks[task.id] = task;

    debugPrint(
      'PlatformNotificationService: Scheduling notifications for task: ${task.title} (ID: ${task.id})',
    );

    final taskId = task.id;

    for (var i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      if (s.notificationRelativeTimes.isEmpty) continue;

      for (var j = 0; j < s.notificationRelativeTimes.length; j++) {
        final notifRel = s.notificationRelativeTimes[j];
        if (_isWeb) {
          final scheduledDate = _calculateNextNotificationDateTimeForNotif(
            task,
            s,
            notifRel,
          );
          final delay = scheduledDate.difference(DateTime.now());
          if (delay.isNegative) continue;

          debugPrint(
            '  - [Web] Scheduling timer in ${delay.inMinutes} minutes at $scheduledDate',
          );
          final timer = Timer(delay, () {
            if (_isDisposed || _runId != _currentRunId) return;

            final currentTask =
                _taskLookup?.call(taskId) ?? _scheduledTasks[taskId];
            if (currentTask == null) return;

            final title = currentTask.title;
            final body = currentTask.description.isNotEmpty
                ? currentTask.description
                : 'Reminder for your task';

            showWebNotification(title, body);
            _onWebNotification?.call(title, body);

            // Reschedule for the next occurrence once it fires
            if (_isDisposed || _runId != _currentRunId) return;
            scheduleNotifications(currentTask);
          });

          _webTimers.putIfAbsent(taskId, () => []).add(timer);
        } else {
          final scheduledDate = _calculateNextNotificationDateTimeForNotif(
            task,
            s,
            notifRel,
          );
          final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
          final notifId = (task.id.hashCode + i * 100 + j) & 0x7FFFFFFF;

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
                  'TaskSchedule Reminders',
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
                    'TaskSchedule Reminders',
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
  }

  @override
  Future<void> cancelNotifications(String taskId) async {
    if (_isDisposed || _runId != _currentRunId) return;

    debugPrint(
      'PlatformNotificationService: Cancelling notifications for task ID: $taskId',
    );

    _scheduledTasks.remove(taskId);

    if (_isWeb) {
      final timers = _webTimers.remove(taskId);
      if (timers != null) {
        for (final timer in timers) {
          timer.cancel();
        }
      }
    } else {
      // Cancel slots on Android. We can cancel by ID
      // To cancel safely, we cancel all notification IDs associated with the task
      // ID calculation is (taskId.hashCode + i * 100 + j) & 0x7FFFFFFF.
      for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 5; j++) {
          final notifId = (taskId.hashCode + i * 100 + j) & 0x7FFFFFFF;
          try {
            await _plugin.cancel(id: notifId);
          } catch (e) {
            // Ignore
          }
        }
      }
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    if (_isDisposed || _runId != _currentRunId) return;

    debugPrint('PlatformNotificationService: Cancelling all notifications');

    _scheduledTasks.clear();

    if (_isWeb) {
      for (final timers in _webTimers.values) {
        for (final timer in timers) {
          timer.cancel();
        }
      }
      _webTimers.clear();
    } else {
      try {
        await _plugin.cancelAll();
      } catch (e) {
        debugPrint('Failed to cancel all platform notifications: $e');
      }
    }
  }

  DateTime _calculateNextNotificationDateTimeForNotif(
    TaskSchedule task,
    TaskScheduleRule s,
    RelativeTime notifRel,
  ) {
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < 365; i++) {
      final civilDay = CivilDay(
        year: checkDate.year,
        month: checkDate.month,
        day: checkDate.day,
      );

      if (s.occursOn(civilDay)) {
        final occurrenceDateTime = notifRel.referenceTo(civilDay);

        if (occurrenceDateTime.isAfter(now)) {
          return occurrenceDateTime;
        }
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }

    return now.add(const Duration(days: 1));
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    debugPrint(
      'PlatformNotificationService: Disposing and cancelling active web timers',
    );
    _scheduledTasks.clear();
    for (final timers in _webTimers.values) {
      for (final timer in timers) {
        timer.cancel();
      }
    }
    _webTimers.clear();
  }
}

/// Simulated Notification Service that prints log statements to debug console
/// and tracks all scheduled tasks in-memory for testing and local verification.
class LoggingNotificationService implements NotificationService {
  final Map<String, TaskSchedule> _scheduledTasks = {};

  /// Exposes a read-only view of currently scheduled tasks.
  Map<String, TaskSchedule> get scheduledTasks =>
      Map.unmodifiable(_scheduledTasks);

  @override
  Future<void> scheduleNotifications(TaskSchedule task) async {
    _scheduledTasks[task.id] = task;
    debugPrint(
      'Scheduling notifications for task: ${task.title} (ID: ${task.id})',
    );
    for (var i = 0; i < task.schedules.length; i++) {
      final s = task.schedules[i];
      if (s.notificationRelativeTimes.isNotEmpty) {
        for (var j = 0; j < s.notificationRelativeTimes.length; j++) {
          final notif = s.notificationRelativeTimes[j];
          debugPrint(
            '  - Scheduled occurrence reminder #$i at offset ${notif.dayOffset} time ${notif.time.hour.toString().padLeft(2, '0')}:${notif.time.minute.toString().padLeft(2, '0')}',
          );
        }
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

  @override
  Future<void> cancelAllNotifications() async {
    clear();
    debugPrint('Cancelling all logging notifications');
  }

  /// Clears all scheduled tasks in memory.
  void clear() {
    _scheduledTasks.clear();
  }

  @override
  Future<void> dispose() async {
    clear();
  }
}
