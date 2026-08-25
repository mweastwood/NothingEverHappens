import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/widgets/unsynced_banner.dart';
import 'package:nothing_ever_happens/widgets/unsynced_details_sheet.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';
import 'package:nothing_ever_happens/widgets/schedule_card.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/task_sync_service.dart';
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import '../test_helper.dart';

class MockSubscriptionService extends StateNotifier<SubscriptionState>
    implements SubscriptionService {
  MockSubscriptionService(super.state);

  @override
  void listenToUserSubscriptionInFirestore(String uid) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTaskSyncService extends Fake implements TaskSyncService {
  bool syncCalled = false;

  @override
  Stream<bool> get isSyncingStream => Stream.value(false);

  @override
  Future<void> sync() async {
    syncCalled = true;
  }
}

void main() {
  group('Unsynced and Cache tracking models unit tests', () {
    test('TaskSchedule supports hasPendingWrites and isFromCache', () {
      final task = TaskSchedule(
        id: 'S-test',
        title: 'Offline Task',
        description: 'Test description',
        hasPendingWrites: true,
        isFromCache: true,
      );

      expect(task.hasPendingWrites, isTrue);
      expect(task.isFromCache, isTrue);

      final copy = task.copyWith(title: 'Updated Task');
      expect(copy.hasPendingWrites, isTrue);
      expect(copy.isFromCache, isTrue);
    });

    test('TaskInstance supports hasPendingWrites and isFromCache', () {
      final instance = TaskInstance(
        id: 'I-test',
        scheduleId: 'S-test',
        ruleId: 'R-test',
        title: 'Offline Instance',
        description: 'Test description',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        hasPendingWrites: true,
        isFromCache: true,
      );

      expect(instance.hasPendingWrites, isTrue);
      expect(instance.isFromCache, isTrue);

      final copy = instance.copyWith(title: 'Updated Instance');
      expect(copy.hasPendingWrites, isTrue);
      expect(copy.isFromCache, isTrue);
    });
  });

  group('UnsyncedBanner Widget Tests', () {
    testWidgets('Renders nothing when unsyncedCount is 0 and not from cache', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => MockSubscriptionService(
                const SubscriptionState(tier: SubscriptionTier.standard),
              ),
            ),
            taskSchedulesProvider.overrideWith((ref) => Stream.value([])),
            taskInstancesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);
    });

    testWidgets('Does NOT render banner if user is on Free tier', (
      tester,
    ) async {
      final unsyncedTask = TaskSchedule(
        id: 'S-unsynced',
        title: 'Unsynced Task',
        description: '',
        hasPendingWrites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => MockSubscriptionService(
                const SubscriptionState(tier: SubscriptionTier.free),
              ),
            ),
            taskSchedulesProvider.overrideWith(
              (ref) => Stream.value([unsyncedTask]),
            ),
            taskInstancesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);
    });

    testWidgets('Renders singular unsynced message for 1 unsynced change', (
      tester,
    ) async {
      final unsyncedTask = TaskSchedule(
        id: 'S-unsynced',
        title: 'Unsynced Task',
        description: '',
        hasPendingWrites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => MockSubscriptionService(
                const SubscriptionState(tier: SubscriptionTier.standard),
              ),
            ),
            taskSchedulesProvider.overrideWith(
              (ref) => Stream.value([unsyncedTask]),
            ),
            taskInstancesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_warning_banner')), findsOneWidget);
      expect(
        find.text('Saved locally to device — 1 change pending Cloud sync'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
    });

    testWidgets(
      'Renders plural unsynced message for multiple unsynced changes',
      (tester) async {
        final unsyncedTask1 = TaskSchedule(
          id: 'S-unsynced-1',
          title: 'Unsynced Task 1',
          description: '',
          hasPendingWrites: true,
        );
        final unsyncedTask2 = TaskSchedule(
          id: 'S-unsynced-2',
          title: 'Unsynced Task 2',
          description: '',
          hasPendingWrites: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.family),
                ),
              ),
              taskSchedulesProvider.overrideWith(
                (ref) => Stream.value([unsyncedTask1, unsyncedTask2]),
              ),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 61));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('unsynced_warning_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Saved locally to device — 2 changes pending Cloud sync'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Transient unsynced write that syncs within grace period does not flash banner',
      (tester) async {
        final schedulesController =
            StreamController<List<TaskSchedule>>.broadcast();
        addTearDown(schedulesController.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
              taskSchedulesProvider.overrideWith(
                (ref) => schedulesController.stream,
              ),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
          ),
        );
        schedulesController.add([]);
        await tester.pump();

        expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);

        // Step 1: User swipes/completes a task (transient unsynced write)
        final unsyncedTask = TaskSchedule(
          id: 'S-transient',
          title: 'Quick Task',
          description: '',
          hasPendingWrites: true,
        );
        schedulesController.add([unsyncedTask]);
        // Advance 30s (within 60s threshold)
        await tester.pump(const Duration(seconds: 30));

        // Banner should NOT be visible during grace period
        expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);

        // Step 2: Background sync completes
        final syncedTask = TaskSchedule(
          id: 'S-transient',
          title: 'Quick Task',
          description: '',
          hasPendingWrites: false,
        );
        schedulesController.add([syncedTask]);
        await tester.pump(const Duration(milliseconds: 100));

        // Advance well past the 60s threshold
        await tester.pump(const Duration(seconds: 65));
        await tester.pumpAndSettle();

        // Banner was never shown and remains not shown
        expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);
      },
    );

    testWidgets(
      'Persistent unsynced write displays banner after grace period expires',
      (tester) async {
        final schedulesController =
            StreamController<List<TaskSchedule>>.broadcast();
        addTearDown(schedulesController.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
              taskSchedulesProvider.overrideWith(
                (ref) => schedulesController.stream,
              ),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
          ),
        );
        schedulesController.add([]);
        await tester.pump();

        // Add unsynced task
        final unsyncedTask = TaskSchedule(
          id: 'S-persistent',
          title: 'Unsynced Task',
          description: '',
          hasPendingWrites: true,
        );
        schedulesController.add([unsyncedTask]);
        await tester.pump();
        await tester.pump();

        // Before grace period expires:
        await tester.pump(const Duration(seconds: 30));
        expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);

        // Advance to cross the 60-second grace period threshold
        await tester.pump(const Duration(seconds: 35));
        await tester.pumpAndSettle();

        // Banner is now smoothly visible!
        expect(
          find.byKey(const Key('unsynced_warning_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Saved locally to device — 1 change pending Cloud sync'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Offline cache mode (isFromCache) displays banner after 60-second persistence threshold',
      (tester) async {
        final cachedTask = TaskSchedule(
          id: 'S-cached',
          title: 'Cached Task',
          description: '',
          isFromCache: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
              taskSchedulesProvider.overrideWith(
                (ref) => Stream.value([cachedTask]),
              ),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
          ),
        );
        await tester.pump();
        // Not visible within 60s
        await tester.pump(const Duration(seconds: 30));
        expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);

        // Advance past 60s
        await tester.pump(const Duration(seconds: 35));
        await tester.pumpAndSettle();

        // Visible after 60s threshold
        expect(
          find.byKey(const Key('unsynced_warning_banner')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Offline mode — All changes save to local device storage first',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Banner dismisses when unsynced changes sync to cloud', (
      tester,
    ) async {
      final schedulesController =
          StreamController<List<TaskSchedule>>.broadcast();
      addTearDown(schedulesController.close);

      final unsyncedTask = TaskSchedule(
        id: 'S-unsynced',
        title: 'Unsynced Task',
        description: '',
        hasPendingWrites: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => MockSubscriptionService(
                const SubscriptionState(tier: SubscriptionTier.standard),
              ),
            ),
            taskSchedulesProvider.overrideWith(
              (ref) => schedulesController.stream,
            ),
            taskInstancesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: Scaffold(body: UnsyncedBanner())),
        ),
      );
      schedulesController.add([unsyncedTask]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_warning_banner')), findsOneWidget);

      // Sync completes
      schedulesController.add([unsyncedTask.copyWith(hasPendingWrites: false)]);
      await tester.pump();
      await tester.pumpAndSettle();

      // Banner disappears
      expect(find.byKey(const Key('unsynced_warning_banner')), findsNothing);
    });

    testWidgets(
      'TaskWidget displays "pending Cloud sync" badge & title icon for active subscriber',
      (tester) async {
        final unsyncedInstance = TaskInstance(
          id: 'I-unsynced-1',
          scheduleId: 'S-unsynced-1',
          ruleId: 'R-unsynced-1',
          title: 'Local Instance',
          description: '',
          scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          hasPendingWrites: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: TaskWidget(instance: unsyncedInstance)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'ScheduleCard displays pending Cloud sync icon before title for active subscriber',
      (tester) async {
        final unsyncedSchedule = TaskSchedule(
          id: 'S-unsynced-sched',
          title: 'Local Schedule',
          description: 'Test desc',
          hasPendingWrites: true,
          schedules: [
            DailySchedule(
              id: 'R-daily-1',
              scheduleId: 'S-unsynced-sched',
              startDate: const CivilDay(year: 2026, month: 8, day: 1),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ScheduleCard(
                    task: unsyncedSchedule,
                    onEdit: () {},
                    onDelete: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
      },
    );

    testWidgets('Tapping UnsyncedBanner opens UnsyncedDetailsSheet', (
      tester,
    ) async {
      final unsyncedTask = TaskSchedule(
        id: 'S-unsynced-detail',
        title: 'Water the plants',
        description: 'Living room and balcony',
        hasPendingWrites: true,
      );

      final unsyncedInstance = TaskInstance(
        id: 'I-unsynced-detail',
        scheduleId: 'S-unsynced-detail',
        ruleId: 'R-detail',
        title: 'Water the plants',
        description: 'Living room and balcony',
        scheduledDate: CivilDay(year: 2026, month: 8, day: 4),
        startRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
        dueRelativeTime: const RelativeTime(
          dayOffset: 0,
          time: TimeOfDay(hour: 17, minute: 0),
        ),
        status: TaskStatus.completed,
        hasPendingWrites: true,
      );

      final fakeSyncService = FakeTaskSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionServiceProvider.overrideWith(
              (ref) => MockSubscriptionService(
                const SubscriptionState(tier: SubscriptionTier.standard),
              ),
            ),
            taskSchedulesProvider.overrideWith(
              (ref) => Stream.value([unsyncedTask]),
            ),
            taskInstancesProvider.overrideWith(
              (ref) => Stream.value([unsyncedInstance]),
            ),
            taskSyncServiceProvider.overrideWithValue(fakeSyncService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: UnsyncedBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_warning_banner')), findsOneWidget);

      // Tap the banner to open details sheet
      await tester.tap(find.byKey(const Key('unsynced_warning_banner')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsynced_details_sheet')), findsOneWidget);
      expect(find.text('Pending Cloud Sync'), findsOneWidget);
      expect(find.text('Water the plants'), findsNWidgets(2));
      expect(find.text('Completed'), findsOneWidget);

      // Tap Sync Now button
      expect(find.byKey(const Key('unsynced_sync_now_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('unsynced_sync_now_button')));
      await tester.pumpAndSettle();

      expect(fakeSyncService.syncCalled, isTrue);
    });

    testWidgets(
      'UnsyncedDetailsSheet displays empty state when no unsynced changes',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskSchedulesProvider.overrideWith((ref) => Stream.value([])),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
              taskSyncServiceProvider.overrideWithValue(FakeTaskSyncService()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: UnsyncedDetailsSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('unsynced_details_sheet')), findsOneWidget);
        expect(
          find.text('All changes are in sync with cloud storage.'),
          findsNWidgets(2),
        );
      },
    );
  });

  group('Unsynced Widgets Golden Tests', () {
    testGoldens(
      'Unsynced banner, task widget, and schedule card golden scenarios',
      (tester) async {
        AppClock.setMockTime(DateTime(2026, 8, 3, 12, 0));
        addTearDown(AppClock.reset);
        final unsyncedTask = TaskSchedule(
          id: 'S-unsynced-g',
          title: 'Unsynced Task Schedule',
          description: 'Pending Cloud sync description',
          hasPendingWrites: true,
          schedules: [
            DailySchedule(
              id: 'R-g1',
              scheduleId: 'S-unsynced-g',
              startDate: const CivilDay(year: 2026, month: 8, day: 1),
              interval: 1,
              startRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 9, minute: 0),
              ),
              dueRelativeTime: const RelativeTime(
                dayOffset: 0,
                time: TimeOfDay(hour: 17, minute: 0),
              ),
            ),
          ],
        );

        final unsyncedInstance = TaskInstance(
          id: 'I-unsynced-g',
          scheduleId: 'S-unsynced-g',
          ruleId: 'R-g1',
          title: 'Unsynced Task Instance',
          description: 'Saved locally pending Cloud sync',
          scheduledDate: const CivilDay(year: 2026, month: 8, day: 4),
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          hasPendingWrites: true,
        );

        final builder = GoldenBuilder.column()
          ..addScenario('Light Mode Unsynced Banner', const UnsyncedBanner())
          ..addScenario(
            'Dark Mode Unsynced Banner',
            Theme(data: ThemeData.dark(), child: const UnsyncedBanner()),
          )
          ..addScenario(
            'Unsynced TaskWidget (Pending Cloud Sync)',
            TaskWidget(instance: unsyncedInstance),
          )
          ..addScenario(
            'Unsynced ScheduleCard (Pending Cloud Sync)',
            ScheduleCard(task: unsyncedTask, onEdit: () {}, onDelete: () {}),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: (child) => ProviderScope(
            overrides: [
              subscriptionServiceProvider.overrideWith(
                (ref) => MockSubscriptionService(
                  const SubscriptionState(tier: SubscriptionTier.standard),
                ),
              ),
              taskSchedulesProvider.overrideWith(
                (ref) => Stream.value([unsyncedTask]),
              ),
              taskInstancesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: l10nMaterialAppWrapper()(child),
          ),
          surfaceSize: const Size(600, 800),
        );

        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 61));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'unsynced_banner_golden');
      },
    );
  });
}
