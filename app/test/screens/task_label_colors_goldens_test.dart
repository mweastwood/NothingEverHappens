import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/auth_repository.dart';
import 'package:nothing_ever_happens/logic/civil_day.dart';
import 'package:nothing_ever_happens/logic/label_repository.dart';
import 'package:nothing_ever_happens/logic/relative_time.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/task_list_screen.dart';
import 'package:nothing_ever_happens/widgets/task_hero_stripe.dart';
import 'package:nothing_ever_happens/widgets/task_widget.dart';

import '../test_helper.dart';
import 'task_list_screen_test.mocks.dart';
import 'home_screen_test.mocks.dart' as home_mocks;

class _FakeUser extends Fake implements User {
  @override
  final String uid = 'test-user-id';
  @override
  final String email = 'user@example.com';
}

void main() {
  final testDate = DateTime(2026, 9, 16, 10, 0);
  final civilToday = const CivilDay(year: 2026, month: 9, day: 16);

  // Curated labels for testing across palette and icon set
  final testLabels = [
    TaskLabel(
      id: 'L-cleaning',
      name: 'Cleaning',
      colorKey: 'emerald',
      iconKey: 'cleaning',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-work',
      name: 'Work',
      colorKey: 'cobalt',
      iconKey: 'work',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-urgent',
      name: 'Urgent',
      colorKey: 'coral',
      iconKey: 'bolt',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-home',
      name: 'Home',
      colorKey: 'sunflower',
      iconKey: 'home',
      scope: TaskLabelScope.family,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-garden',
      name: 'Garden',
      colorKey: 'mint',
      iconKey: 'yard',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-special',
      name: 'Special',
      colorKey: 'lavender',
      iconKey: 'star',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-health',
      name: 'Health',
      colorKey: 'rose',
      iconKey: 'medication',
      scope: TaskLabelScope.personal,
      createdAt: testDate,
    ),
    TaskLabel(
      id: 'L-meals',
      name: 'Meals',
      colorKey: 'tangerine',
      iconKey: 'restaurant',
      scope: TaskLabelScope.family,
      createdAt: testDate,
    ),
  ];

  final labelsMap = {for (final l in testLabels) l.id: l};

  // 1. Task without labels
  final instanceNoLabels = TaskInstance(
    id: 'I-no-labels',
    scheduleId: 'S-0',
    ruleId: 'R-0',
    title: 'Check the Mailbox',
    description:
        'Check for parcels and important letters from the post office.',
    scheduledDate: civilToday,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
    priority: TaskPriority.medium,
    labelIds: const [],
  );

  // 2. Task with 1 label (Emerald / Cleaning)
  final instanceSingleLabel = TaskInstance(
    id: 'I-single-label',
    scheduleId: 'S-1',
    ruleId: 'R-1',
    title: 'Deep Clean the Kitchen',
    description:
        'Scrub countertops, wipe the stove burners, and mop the tile floor.',
    scheduledDate: civilToday,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 14, minute: 0),
    priority: TaskPriority.medium,
    labelIds: const ['L-cleaning'],
  );

  // 3. Task with 2 labels (Cobalt / Work + Coral / Urgent)
  final instanceTwoLabels = TaskInstance(
    id: 'I-two-labels',
    scheduleId: 'S-2',
    ruleId: 'R-2',
    title: 'Submit Quarterly Tax Documents',
    description:
        'Cross-reference financial statements and file the quarterly declaration before the 5pm deadline.',
    scheduledDate: civilToday,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 10, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 17, minute: 0),
    priority: TaskPriority.high,
    labelIds: const ['L-work', 'L-urgent'],
  );

  // 4. Task with 3 labels (Sunflower / Home + Mint / Garden + Lavender / Special)
  final instanceThreeLabels = TaskInstance(
    id: 'I-three-labels',
    scheduleId: 'S-3',
    ruleId: 'R-3',
    title: 'Prune Rose Bushes & Plant Bulbs',
    description:
        'Autumn garden preparation and mulch application for the front flowerbeds.',
    scheduledDate: civilToday,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 8, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 18, minute: 0),
    priority: TaskPriority.low,
    labelIds: const ['L-home', 'L-garden', 'L-special'],
  );

  // 5. Task with 4 labels (Tangerine / Meals + Sunflower / Home + Rose / Health + Coral / Urgent)
  final instanceFourLabels = TaskInstance(
    id: 'I-four-labels',
    scheduleId: 'S-4',
    ruleId: 'R-4',
    title: 'Weekly Family Health & Meal Prep',
    description:
        'Batch-cook healthy school lunches, organize vitamin packs, and restock fruits.',
    scheduledDate: civilToday,
    startRelativeTime: const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    dueRelativeTime: const RelativeTime(dayOffset: 0, hour: 16, minute: 0),
    isFamily: true,
    labelIds: const ['L-meals', 'L-home', 'L-health', 'L-urgent'],
  );

  final testInstances = [
    instanceTwoLabels,
    instanceSingleLabel,
    instanceThreeLabels,
    instanceFourLabels,
    instanceNoLabels,
  ];

  final testSchedules = [
    TaskSchedule(
      id: 'S-0',
      title: instanceNoLabels.title,
      description: instanceNoLabels.description,
      labelIds: const [],
    ),
    TaskSchedule(
      id: 'S-1',
      title: instanceSingleLabel.title,
      description: instanceSingleLabel.description,
      labelIds: const ['L-cleaning'],
    ),
    TaskSchedule(
      id: 'S-2',
      title: instanceTwoLabels.title,
      description: instanceTwoLabels.description,
      priority: TaskPriority.high,
      labelIds: const ['L-work', 'L-urgent'],
    ),
    TaskSchedule(
      id: 'S-3',
      title: instanceThreeLabels.title,
      description: instanceThreeLabels.description,
      priority: TaskPriority.low,
      labelIds: const ['L-home', 'L-garden', 'L-special'],
    ),
    TaskSchedule(
      id: 'S-4',
      title: instanceFourLabels.title,
      description: instanceFourLabels.description,
      isFamily: true,
      labelIds: const ['L-meals', 'L-home', 'L-health', 'L-urgent'],
    ),
  ];

  late MockAuthRepository mockAuthRepository;
  late MockTaskRepository mockTaskRepository;
  late home_mocks.MockUserSettingsRepository mockUserSettingsRepository;
  late BehaviorSubject<List<TaskSchedule>> tasksSubject;
  late BehaviorSubject<List<TaskInstance>> instancesSubject;

  setUp(() {
    AppClock.setMockTime(testDate);
    mockAuthRepository = MockAuthRepository();
    mockTaskRepository = MockTaskRepository();
    mockUserSettingsRepository = home_mocks.MockUserSettingsRepository();

    tasksSubject = BehaviorSubject<List<TaskSchedule>>(sync: true)
      ..add(testSchedules);
    instancesSubject = BehaviorSubject<List<TaskInstance>>(sync: true)
      ..add(testInstances);

    when(mockAuthRepository.signOut()).thenAnswer((_) async {});
    when(mockTaskRepository.getTasks()).thenAnswer((_) => tasksSubject.stream);
    when(
      mockTaskRepository.getInstances(),
    ).thenAnswer((_) => instancesSubject.stream);
    when(
      mockUserSettingsRepository.getSettings(),
    ).thenAnswer((_) => Stream.value(const UserSettings(hoursAvailable: 8.0)));
  });

  tearDown(() {
    AppClock.reset();
    tasksSubject.close();
    instancesSubject.close();
  });

  List<Override> buildOverrides() => [
    taskRepositoryProvider.overrideWithValue(mockTaskRepository),
    userSettingsRepositoryProvider.overrideWithValue(
      mockUserSettingsRepository,
    ),
    userSettingsProvider.overrideWith(
      (ref) => Stream.value(const UserSettings(hoursAvailable: 8.0)),
    ),
    taskSchedulesProvider.overrideWith((ref) => tasksSubject.stream),
    taskInstancesProvider.overrideWith((ref) => instancesSubject.stream),
    authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
    personalLabelsStreamProvider.overrideWith(
      (ref) => Stream.value(
        testLabels.where((l) => l.scope == TaskLabelScope.personal).toList(),
      ),
    ),
    familyLabelsStreamProvider.overrideWith(
      (ref) => Stream.value(
        testLabels.where((l) => l.scope == TaskLabelScope.family).toList(),
      ),
    ),
    allLabelsMapProvider.overrideWithValue(labelsMap),
  ];

  Widget wrapInScope(Widget child) {
    return ProviderScope(overrides: buildOverrides(), child: child);
  }

  group('Hero Stripe Macro Visualization Goldens', () {
    Widget buildStripeComparison({required bool isDark}) {
      return Builder(
        builder: (context) {
          final coral = LabelPalette.coral.getColor(context);
          final cobalt = LabelPalette.cobalt.getColor(context);
          final emerald = LabelPalette.emerald.getColor(context);
          final sunflower = LabelPalette.sunflower.getColor(context);
          final lavender = LabelPalette.lavender.getColor(context);

          Widget buildStripeColumn({
            required String title,
            required String subtitle,
            required List<Color> colors,
          }) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  width: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TaskHeroStripe(
                    colors: colors,
                    width: 14,
                    blendRatio: 0.15,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            );
          }

          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Boundary-Blended Hero Stripe Comparison',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solid color segments with smooth gradient blend only at boundaries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildStripeColumn(
                      title: '1 Color',
                      subtitle: '100% Solid',
                      colors: [emerald],
                    ),
                    buildStripeColumn(
                      title: '2 Colors',
                      subtitle: 'Blend @ 50%',
                      colors: [cobalt, coral],
                    ),
                    buildStripeColumn(
                      title: '3 Colors',
                      subtitle: 'Blend @ 33%, 67%',
                      colors: [sunflower, emerald, lavender],
                    ),
                    buildStripeColumn(
                      title: '4 Colors',
                      subtitle: 'Blend @ 25, 50, 75%',
                      colors: [cobalt, sunflower, emerald, coral],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    testGoldens('Hero Stripe comparison - Light Theme', (tester) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildStripeComparison(isDark: false)),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.light(useMaterial3: true),
        ),
        surfaceSize: const Size(500, 340),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'golden_task_hero_stripes_comparison_light',
      );
    });

    testGoldens('Hero Stripe comparison - Dark Theme', (tester) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildStripeComparison(isDark: true)),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.dark(useMaterial3: true),
        ),
        surfaceSize: const Size(500, 340),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'golden_task_hero_stripes_comparison_dark',
      );
    });
  });

  group('Task Card Label Variations Goldens', () {
    Widget buildCardMatrix() {
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            TaskWidget(instance: instanceNoLabels, schedule: testSchedules[0]),
            const SizedBox(height: 12),
            TaskWidget(
              instance: instanceSingleLabel,
              schedule: testSchedules[1],
            ),
            const SizedBox(height: 12),
            TaskWidget(instance: instanceTwoLabels, schedule: testSchedules[2]),
            const SizedBox(height: 12),
            TaskWidget(
              instance: instanceThreeLabels,
              schedule: testSchedules[3],
            ),
            const SizedBox(height: 12),
            TaskWidget(
              instance: instanceFourLabels,
              schedule: testSchedules[4],
            ),
          ],
        ),
      );
    }

    testGoldens('Task Card Label Variations (0 to 4 labels) - Light Theme', (
      tester,
    ) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildCardMatrix()),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.light(useMaterial3: true),
        ),
        surfaceSize: const Size(420, 1050),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'golden_task_card_labels_matrix_light');
    });

    testGoldens('Task Card Label Variations (0 to 4 labels) - Dark Theme', (
      tester,
    ) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildCardMatrix()),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.dark(useMaterial3: true),
        ),
        surfaceSize: const Size(420, 1050),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'golden_task_card_labels_matrix_dark');
    });
  });

  group('Task List Screen with Multi-Label Tasks Goldens', () {
    Widget buildTaskListScreenTest() {
      return Scaffold(
        appBar: AppBar(title: const Text('Tasks')),
        body: const TaskListScreen(),
      );
    }

    testGoldens('Task List Screen with Multi-Label Tasks - Light Theme', (
      tester,
    ) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildTaskListScreenTest()),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.light(useMaterial3: true),
        ),
        surfaceSize: const Size(400, 1260),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'golden_task_list_screen_with_label_colors_light',
      );
    });

    testGoldens('Task List Screen with Multi-Label Tasks - Dark Theme', (
      tester,
    ) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildTaskListScreenTest()),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.dark(useMaterial3: true),
        ),
        surfaceSize: const Size(400, 1260),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'golden_task_list_screen_with_label_colors_dark',
      );
    });

    testGoldens('Task List Screen Wide Masonry Layout with Multi-Label Tasks', (
      tester,
    ) async {
      await tester.pumpWidgetBuilder(
        wrapInScope(buildTaskListScreenTest()),
        wrapper: l10nMaterialAppWrapper(
          theme: ThemeData.light(useMaterial3: true),
        ),
        surfaceSize: const Size(900, 780),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(
        tester,
        'golden_task_list_screen_wide_layout_labels',
      );
    });
  });
}
