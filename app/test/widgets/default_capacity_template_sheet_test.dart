import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/widgets/default_capacity_template_sheet.dart';
import 'package:nothing_ever_happens/widgets/edit_capacity_sheet.dart';

import '../screens/home_screen_test.mocks.dart';
import '../test_helper.dart';

void main() {
  late MockUserSettingsRepository mockUserSettingsRepository;

  setUp(() {
    AppClock.setMockTime(DateTime(2026, 7, 1, 9, 0));
    mockUserSettingsRepository = MockUserSettingsRepository();
    when(
      mockUserSettingsRepository.updateSettings(any),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    AppClock.reset();
  });

  Widget createTestWidget({required UserSettings settings}) {
    return ProviderScope(
      overrides: [
        userSettingsRepositoryProvider.overrideWithValue(
          mockUserSettingsRepository,
        ),
        userSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      ],
      child: buildTestableWidget(
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DefaultCapacityTemplateSheet.show(
                context,
                settings: settings,
              ),
              child: const Text('Open Template Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    required UserSettings settings,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(createTestWidget(settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Template Sheet'));
    await tester.pumpAndSettle();
  }

  group('DefaultCapacityTemplateSheet', () {
    testWidgets(
      'renders 7 weekday tiles with accurate durations from UserSettings',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          defaultDailyCapacity: {
            '1': 2.0, // Monday: 2h
            '2': 3.5, // Tuesday: 3h 30m
            '3': 0.0, // Wednesday: 0m
            '4': 1.25, // Thursday: 1h 15m
            '5': 4.0, // Friday: 4h
            '6': 6.0, // Saturday: 6h
            '7': 8.0, // Sunday: 8h
          },
        );

        await openSheet(tester, settings: settings);

        expect(find.text('Default Capacity Template'), findsOneWidget);
        expect(
          find.text('Set standard availability baseline per day'),
          findsOneWidget,
        );

        // Check Monday (1)
        expect(
          find.byKey(const Key('default_capacity_tile_1')),
          findsOneWidget,
        );
        expect(find.text('Monday'), findsOneWidget);
        expect(find.text('2h'), findsOneWidget);

        // Check Tuesday (2)
        expect(
          find.byKey(const Key('default_capacity_tile_2')),
          findsOneWidget,
        );
        expect(find.text('Tuesday'), findsOneWidget);
        expect(find.text('3h 30m'), findsOneWidget);

        // Check Wednesday (3)
        expect(
          find.byKey(const Key('default_capacity_tile_3')),
          findsOneWidget,
        );
        expect(find.text('Wednesday'), findsOneWidget);
        expect(find.text('0m'), findsOneWidget);

        // Check Thursday (4)
        expect(
          find.byKey(const Key('default_capacity_tile_4')),
          findsOneWidget,
        );
        expect(find.text('Thursday'), findsOneWidget);
        expect(find.text('1h 15m'), findsOneWidget);

        // Check Friday (5)
        expect(
          find.byKey(const Key('default_capacity_tile_5')),
          findsOneWidget,
        );
        expect(find.text('Friday'), findsOneWidget);
        expect(find.text('4h'), findsOneWidget);

        // Check Saturday (6)
        expect(
          find.byKey(const Key('default_capacity_tile_6')),
          findsOneWidget,
        );
        expect(find.text('Saturday'), findsOneWidget);
        expect(find.text('6h'), findsOneWidget);

        // Check Sunday (7)
        expect(
          find.byKey(const Key('default_capacity_tile_7')),
          findsOneWidget,
        );
        expect(find.text('Sunday'), findsOneWidget);
        expect(find.text('8h'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a weekday opens EditCapacitySheet with isOverride: false',
      (WidgetTester tester) async {
        const settings = UserSettings(
          hoursAvailable: 8.0,
          defaultDailyCapacity: {'1': 2.0},
        );

        await openSheet(tester, settings: settings);

        // Tap Monday tile
        final mondayTile = find.byKey(const Key('default_capacity_tile_1'));
        expect(mondayTile, findsOneWidget);
        await tester.tap(mondayTile);
        await tester.pumpAndSettle();

        // Verify EditCapacitySheet is displayed
        expect(find.byType(EditCapacitySheet), findsOneWidget);
        // Header should say "Edit Default Capacity" (meaning isOverride is false)
        expect(find.text('Edit Default Capacity'), findsOneWidget);
        expect(
          find.text('Set default availability baseline for weekday'),
          findsOneWidget,
        );
        // Initial duration for Monday is 2.0h -> 2h 0m
        expect(find.text('2h 0m'), findsOneWidget);
      },
    );

    testWidgets('close button dismisses template sheet', (
      WidgetTester tester,
    ) async {
      const settings = UserSettings(hoursAvailable: 8.0);

      await openSheet(tester, settings: settings);

      expect(find.byType(DefaultCapacityTemplateSheet), findsOneWidget);

      final closeBtn = find.byIcon(Icons.close);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCapacityTemplateSheet), findsNothing);
    });
  });
}
