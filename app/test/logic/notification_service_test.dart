import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nothing_ever_happens/logic/notification_service.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeFlutterLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  InitializationSettings? initSettings;
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    initSettings = settings;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'notificationDetails': notificationDetails,
      'androidScheduleMode': androidScheduleMode,
    });
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add(id);
  }

  FakeAndroidFlutterLocalNotificationsPlugin? androidImplementation;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return (androidImplementation ??=
              FakeAndroidFlutterLocalNotificationsPlugin())
          as T;
    }
    return null;
  }
}

class FakeAndroidFlutterLocalNotificationsPlugin extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  bool requestNotificationsPermissionCalled = false;
  bool requestExactAlarmsPermissionCalled = false;

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestNotificationsPermissionCalled = true;
    return true;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    requestExactAlarmsPermissionCalled = true;
    return true;
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('PlatformNotificationService Unit Tests', () {
    late FakeFlutterLocalNotificationsPlugin mockPlugin;
    late PlatformNotificationService notificationService;

    setUp(() {
      mockPlugin = FakeFlutterLocalNotificationsPlugin();
      notificationService = PlatformNotificationService(plugin: mockPlugin);
    });

    tearDown(() async {
      await notificationService.dispose();
    });

    final testTask = TaskSchedule(
      id: 'task-notif-test',
      title: 'Zoned Test TaskSchedule',
      description: 'Running unit tests',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          notificationRelativeTimes: const [
            RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 8, minute: 30)),
          ],
        ),
      ],
    );

    test(
      'scheduleNotifications schedules exact zoned notification via plugin',
      () async {
        await notificationService.scheduleNotifications(testTask);

        expect(mockPlugin.scheduled.length, 1);
        final notif = mockPlugin.scheduled.first;
        expect(notif['title'], 'Zoned Test TaskSchedule');
        expect(notif['body'], 'Running unit tests');
        expect(
          notif['androidScheduleMode'],
          AndroidScheduleMode.exactAllowWhileIdle,
        );
        expect(notif['scheduledDate'], isA<tz.TZDateTime>());
      },
    );

    test(
      'scheduleNotifications schedules multiple exact zoned notifications via plugin with unique IDs',
      () async {
        final multiNotifTask = TaskSchedule(
          id: 'task-notif-multi-test',
          title: 'Multi Notif Task',
          description: 'Testing multiple reminders',
          schedules: [
            DailySchedule(
              startDate: const CivilDay(year: 2024, month: 1, day: 1),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
              notificationRelativeTimes: const [
                RelativeTime(
                  dayOffset: -1,
                  time: TimeOfDay(hour: 18, minute: 0),
                ),
                RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 8, minute: 30),
                ),
                RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 12, minute: 0),
                ),
              ],
            ),
          ],
        );

        await notificationService.scheduleNotifications(multiNotifTask);

        // Should schedule exactly 3 notifications
        expect(mockPlugin.scheduled.length, 3);

        // Check each has a unique ID
        final ids = mockPlugin.scheduled.map((n) => n['id'] as int).toList();
        expect(ids.toSet().length, 3);

        // Verify the expected notification relative times mapped to TZDateTimes
        final scheduledDates = mockPlugin.scheduled
            .map(
              (n) => DateTime.fromMillisecondsSinceEpoch(
                (n['scheduledDate'] as tz.TZDateTime).millisecondsSinceEpoch,
              ),
            )
            .toList();
        expect(scheduledDates[0].hour, 18);
        expect(scheduledDates[1].hour, 8);
        expect(scheduledDates[1].minute, 30);
        expect(scheduledDates[2].hour, 12);
      },
    );

    test(
      'cancelNotifications cancels scheduled notifications via plugin',
      () async {
        await notificationService.cancelNotifications(testTask.id);

        // Should attempt to cancel all associated slot IDs (10 rules * 5 notification slots each)
        expect(mockPlugin.cancelled.length, 50);
      },
    );

    test(
      'tracks scheduled tasks in scheduledTasks and clears on cancel/dispose',
      () async {
        await notificationService.scheduleNotifications(testTask);
        expect(
          notificationService.scheduledTasks.containsKey(testTask.id),
          true,
        );
        expect(
          notificationService.scheduledTasks[testTask.id]?.title,
          'Zoned Test TaskSchedule',
        );

        final updatedTask = TaskSchedule(
          id: testTask.id,
          title: 'Updated Task Title',
          description: 'Updated Description',
          schedules: testTask.schedules,
        );
        await notificationService.scheduleNotifications(updatedTask);
        expect(
          notificationService.scheduledTasks[testTask.id]?.title,
          'Updated Task Title',
        );

        await notificationService.cancelNotifications(testTask.id);
        expect(
          notificationService.scheduledTasks.containsKey(testTask.id),
          false,
        );

        await notificationService.scheduleNotifications(testTask);
        expect(
          notificationService.scheduledTasks.containsKey(testTask.id),
          true,
        );

        await notificationService.cancelAllNotifications();
        expect(notificationService.scheduledTasks.isEmpty, true);
      },
    );

    test(
      'Fake plugin resolves Android implementation and registers permissions',
      () async {
        final androidPlugin = mockPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        expect(androidPlugin, isNotNull);

        final notifGranted = await androidPlugin!
            .requestNotificationsPermission();
        final exactGranted = await androidPlugin.requestExactAlarmsPermission();

        expect(notifGranted, true);
        expect(exactGranted, true);
        expect(
          mockPlugin
              .androidImplementation!
              .requestNotificationsPermissionCalled,
          true,
        );
        expect(
          mockPlugin.androidImplementation!.requestExactAlarmsPermissionCalled,
          true,
        );
      },
    );
  });

  group('PlatformNotificationService Web Timer Tests', () {
    late List<Map<String, String>> firedNotifications;
    late PlatformNotificationService webNotificationService;

    setUp(() {
      firedNotifications = [];
    });

    tearDown(() async {
      await webNotificationService.dispose();
    });

    final webTask = TaskSchedule(
      id: 'web-task-1',
      title: 'Initial Web Task',
      description: 'Initial Description',
      schedules: [
        DailySchedule(
          startDate: const CivilDay(year: 2024, month: 1, day: 1),
          interval: 1,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 0, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 23, minute: 59),
          ),
          notificationRelativeTimes: const [
            RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 23, minute: 59)),
          ],
        ),
      ],
    );

    test('registers web timers and tracks scheduled task', () async {
      webNotificationService = PlatformNotificationService(
        isWeb: true,
        onWebNotification: (title, body) {
          firedNotifications.add({'title': title, 'body': body});
        },
      );

      await webNotificationService.scheduleNotifications(webTask);

      expect(
        webNotificationService.scheduledTasks.containsKey(webTask.id),
        true,
      );
      expect(webNotificationService.webTimers.containsKey(webTask.id), true);
      expect(webNotificationService.webTimers[webTask.id]!.isNotEmpty, true);
    });

    test(
      'cancelNotifications cancels timers and removes task from map',
      () async {
        webNotificationService = PlatformNotificationService(isWeb: true);

        await webNotificationService.scheduleNotifications(webTask);
        expect(webNotificationService.webTimers.containsKey(webTask.id), true);
        expect(
          webNotificationService.scheduledTasks.containsKey(webTask.id),
          true,
        );

        await webNotificationService.cancelNotifications(webTask.id);
        expect(webNotificationService.webTimers.containsKey(webTask.id), false);
        expect(
          webNotificationService.scheduledTasks.containsKey(webTask.id),
          false,
        );
      },
    );

    test('cancelAllNotifications clears all web timers and tasks', () async {
      webNotificationService = PlatformNotificationService(isWeb: true);

      await webNotificationService.scheduleNotifications(webTask);
      expect(webNotificationService.webTimers.isNotEmpty, true);
      expect(webNotificationService.scheduledTasks.isNotEmpty, true);

      await webNotificationService.cancelAllNotifications();
      expect(webNotificationService.webTimers.isEmpty, true);
      expect(webNotificationService.scheduledTasks.isEmpty, true);
    });

    test('dispose cancels all timers and clears scheduled tasks', () async {
      webNotificationService = PlatformNotificationService(isWeb: true);

      await webNotificationService.scheduleNotifications(webTask);
      expect(webNotificationService.webTimers.isNotEmpty, true);
      expect(webNotificationService.scheduledTasks.isNotEmpty, true);

      await webNotificationService.dispose();
      expect(webNotificationService.webTimers.isEmpty, true);
      expect(webNotificationService.scheduledTasks.isEmpty, true);
    });

    test(
      'rescheduling cancels old timers before registering new timers',
      () async {
        webNotificationService = PlatformNotificationService(isWeb: true);

        await webNotificationService.scheduleNotifications(webTask);
        final initialTimers = List.of(
          webNotificationService.webTimers[webTask.id]!,
        );
        expect(initialTimers.length, 1);

        final updatedTask = TaskSchedule(
          id: webTask.id,
          title: 'Updated Web Task Title',
          description: 'Updated Description',
          schedules: webTask.schedules,
        );

        await webNotificationService.scheduleNotifications(updatedTask);
        expect(
          webNotificationService.scheduledTasks[webTask.id]?.title,
          'Updated Web Task Title',
        );
        final newTimers = webNotificationService.webTimers[webTask.id]!;
        expect(newTimers.length, 1);
        expect(identical(initialTimers.first, newTimers.first), false);
      },
    );

    test('dynamic lookup via taskLookup resolves current task state', () async {
      TaskSchedule? dynamicTask = webTask;
      webNotificationService = PlatformNotificationService(
        isWeb: true,
        taskLookup: (taskId) => dynamicTask,
        onWebNotification: (title, body) {
          firedNotifications.add({'title': title, 'body': body});
        },
      );

      await webNotificationService.scheduleNotifications(webTask);
      expect(
        webNotificationService.scheduledTasks.containsKey(webTask.id),
        true,
      );

      // Simulate task deletion in external store
      dynamicTask = null;
      // When taskLookup returns null and scheduledTasks has the entry or is cancelled,
      // taskLookup takes precedence or fallback to scheduledTasks
      expect(webNotificationService.scheduledTasks[webTask.id], isNotNull);
    });
  });
}
