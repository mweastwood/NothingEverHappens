import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../test_helper.dart';

import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/error_handler.dart';
import 'package:nothing_ever_happens/screens/settings_screen.dart';

@GenerateNiceMocks([MockSpec<UserSettingsRepository>()])
import 'settings_screen_test.mocks.dart';

void main() {
  late MockUserSettingsRepository mockRepository;
  late ErrorHandler errorHandler;
  late BehaviorSubject<UserSettings> settingsSubject;

  setUp(() {
    mockRepository = MockUserSettingsRepository();
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

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(mockRepository),
        errorHandlerProvider.overrideWithValue(errorHandler),
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
      surfaceSize: const Size(400, 800),
    );
    await screenMatchesGolden(tester, 'settings_screen_initial');
  });

  testGoldens('SettingsScreen validation error state golden', (tester) async {
    await tester.pumpWidgetBuilder(
      buildTestWidget(),
      wrapper: l10nMaterialAppWrapper(),
      surfaceSize: const Size(400, 800),
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
      surfaceSize: const Size(400, 800),
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
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      verify(
        mockRepository.updateSettings(
          const UserSettings(hoursAvailable: 8.0, showLastSpawnedDate: true),
        ),
      ).called(1);
    },
  );

  testWidgets('SettingsScreen renders export debug state button',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final exportButtonFinder =
        find.byKey(const Key('export_debug_state_button'));
    expect(exportButtonFinder, findsOneWidget);
    expect(find.text('Debug & Diagnostics'), findsOneWidget);
    expect(find.text('Export Debug State (LLM JSON)'), findsOneWidget);
  });
}

