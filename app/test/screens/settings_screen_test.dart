import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_state_exporter.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/screens/settings_screen.dart';
import 'package:rxdart/rxdart.dart';

import '../test_helper.dart';

@GenerateNiceMocks([MockSpec<UserSettingsRepository>()])
import 'settings_screen_test.mocks.dart';

class MockAppStateExporter extends Mock implements AppStateExporter {
  @override
  Future<void> shareDebugState(BuildContext? context) =>
      (super.noSuchMethod(
            Invocation.method(#shareDebugState, [context]),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>);
}

class MockTaskRepository extends Mock implements TaskRepository {
  @override
  Future<void> resetLocalDataAndResync() =>
      (super.noSuchMethod(
            Invocation.method(#resetLocalDataAndResync, []),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>);
}

void main() {
  late MockUserSettingsRepository mockRepository;
  late MockAppStateExporter mockExporter;
  late MockTaskRepository mockTaskRepository;
  late ErrorHandler errorHandler;
  late BehaviorSubject<UserSettings> settingsSubject;

  setUp(() {
    mockRepository = MockUserSettingsRepository();
    mockExporter = MockAppStateExporter();
    mockTaskRepository = MockTaskRepository();
    errorHandler = ErrorHandler();
    settingsSubject = BehaviorSubject<UserSettings>.seeded(
      const UserSettings(hoursAvailable: 8.0),
    );

    when(
      mockRepository.getSettings(),
    ).thenAnswer((_) => settingsSubject.stream);
  });

  tearDown(() {
    settingsSubject.close();
  });

  Widget buildTestWidget({bool hasSuspectedStaleData = false}) {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(mockRepository),
        errorHandlerProvider.overrideWithValue(errorHandler),
        appStateExporterProvider.overrideWithValue(mockExporter),
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        hasSuspectedStaleDataProvider.overrideWith(
          (_) => Stream.value(hasSuspectedStaleData),
        ),
      ],
      child: buildTestableWidget(child: const SettingsScreen()),
    );
  }

  testWidgets('SettingsScreen displays initial value correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byKey(const Key('hours_available_field'));
    expect(textFieldFinder, findsOneWidget);

    final TextFormField textField = tester.widget(textFieldFinder);
    expect(textField.controller?.text, '8.0');
  });

  testWidgets('SettingsScreen validation fails for invalid values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byKey(const Key('hours_available_field'));

    await tester.enterText(textFieldFinder, '25');
    await tester.pumpAndSettle();

    final saveButtonFinder = find.byKey(const Key('save_settings_button'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a number between 0 and 24'), findsOneWidget);
    verifyNever(mockRepository.updateSettings(any));
  });

  testWidgets('SettingsScreen validation passes and saves successfully', (
    WidgetTester tester,
  ) async {
    when(mockRepository.updateSettings(any)).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final textFieldFinder = find.byKey(const Key('hours_available_field'));
    await tester.enterText(textFieldFinder, '12.5');
    await tester.pumpAndSettle();

    final saveButtonFinder = find.byKey(const Key('save_settings_button'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    verify(
      mockRepository.updateSettings(const UserSettings(hoursAvailable: 12.5)),
    ).called(1);
    expect(find.text('Settings saved successfully'), findsOneWidget);
  });

  testGoldens('SettingsScreen initial state golden', (tester) async {
    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 1000),
    );
    await screenMatchesGolden(tester, 'settings_screen_initial');
  });

  testGoldens('SettingsScreen validation error state golden', (tester) async {
    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 1000),
    );

    final textFieldFinder = find.byKey(const Key('hours_available_field'));
    await tester.enterText(textFieldFinder, '-1');
    await tester.pumpAndSettle();

    final saveButtonFinder = find.byKey(const Key('save_settings_button'));
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'settings_screen_validation_error');
  });

  testGoldens('SettingsScreen with all options enabled golden', (tester) async {
    settingsSubject.add(
      const UserSettings(hoursAvailable: 8.0, showLastSpawnedDate: true),
    );

    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 1000),
    );
    await screenMatchesGolden(tester, 'settings_screen_all_enabled');
  });

  testWidgets(
    'SettingsScreen updates and saves showLastSpawnedDate switch correctly',
    (WidgetTester tester) async {
      when(mockRepository.updateSettings(any)).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(
        const Key('show_last_spawned_date_switch'),
      );
      expect(switchFinder, findsOneWidget);

      final SwitchListTile switchListTile = tester.widget(switchFinder);
      expect(switchListTile.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final SwitchListTile updatedSwitch = tester.widget(switchFinder);
      expect(updatedSwitch.value, isTrue);

      final saveButtonFinder = find.byKey(const Key('save_settings_button'));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      verify(
        mockRepository.updateSettings(
          const UserSettings(hoursAvailable: 8.0, showLastSpawnedDate: true),
        ),
      ).called(1);
    },
  );

  testWidgets('SettingsScreen renders export debug state button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final exportButtonFinder = find.byKey(
      const Key('export_debug_state_button'),
    );
    expect(exportButtonFinder, findsOneWidget);
    expect(find.text('Debug & Diagnostics'), findsOneWidget);
    expect(find.text('Export Debug State (LLM JSON)'), findsOneWidget);
  });

  testWidgets(
    'SettingsScreen triggers export debug state when export button is tapped',
    (WidgetTester tester) async {
      when(mockExporter.shareDebugState(any)).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final exportButtonFinder = find.byKey(
        const Key('export_debug_state_button'),
      );
      expect(exportButtonFinder, findsOneWidget);

      await tester.tap(exportButtonFinder);
      await tester.pumpAndSettle();

      verify(mockExporter.shareDebugState(any)).called(1);
    },
  );

  testWidgets(
    'SettingsScreen renders Data Synchronization card and disables reset button when data is healthy',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(hasSuspectedStaleData: false));
      await tester.pumpAndSettle();

      expect(find.text('Data Synchronization'), findsOneWidget);
      expect(
        find.text('Local data is in sync with cloud storage.'),
        findsOneWidget,
      );

      final resetButtonFinder = find.byKey(
        const Key('reset_local_data_button'),
      );
      expect(resetButtonFinder, findsOneWidget);

      final FilledButton button = tester.widget(resetButtonFinder);
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'SettingsScreen enables reset button and shows warning when stale data is suspected',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(hasSuspectedStaleData: true));
      await tester.pumpAndSettle();

      expect(find.text('Data Synchronization'), findsOneWidget);
      expect(
        find.text(
          'Stale or unmigrated local data detected. Reset to re-sync from cloud.',
        ),
        findsOneWidget,
      );

      final resetButtonFinder = find.byKey(
        const Key('reset_local_data_button'),
      );
      expect(resetButtonFinder, findsOneWidget);

      final FilledButton button = tester.widget(resetButtonFinder);
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'SettingsScreen shows confirmation dialog and resets data when confirmed',
    (WidgetTester tester) async {
      when(
        mockTaskRepository.resetLocalDataAndResync(),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(hasSuspectedStaleData: true));
      await tester.pumpAndSettle();

      final resetButtonFinder = find.byKey(
        const Key('reset_local_data_button'),
      );
      await tester.tap(resetButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Reset Local Data?'), findsOneWidget);
      expect(
        find.text(
          'This will clear local storage and re-download all your tasks from cloud storage.',
        ),
        findsOneWidget,
      );

      final confirmButtonFinder = find.byKey(
        const Key('confirm_reset_local_data_button'),
      );
      await tester.tap(confirmButtonFinder);
      await tester.pumpAndSettle();

      verify(mockTaskRepository.resetLocalDataAndResync()).called(1);
      expect(
        find.text('Local data reset and synchronized from cloud successfully.'),
        findsOneWidget,
      );
    },
  );
}
