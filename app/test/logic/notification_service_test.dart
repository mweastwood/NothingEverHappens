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
          notificationRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 8, minute: 30),
          ),
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
      'cancelNotifications cancels scheduled notifications via plugin',
      () async {
        await notificationService.cancelNotifications(testTask.id);

        // Should attempt to cancel all associated slot IDs (0 through 9)
        expect(mockPlugin.cancelled.length, 10);
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
}
