import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/app_clock.dart';
import 'package:nothing_ever_happens/widgets/dev_clock_widget.dart';
import 'package:nothing_ever_happens/main.dart';
import '../test_helper.dart';

void main() {
  group('DevClockWidget Goldens', () {
    testGoldens('DevClockWidget renders button when active/inactive', (
      tester,
    ) async {
      AppConfig.environment = AppEnvironment.dev;
      AppClock.reset();

      // Test 1: Inactive state (only shows the small floating button)
      await tester.pumpWidgetBuilder(
        const Scaffold(body: DevClockWidget()),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(400, 300),
      );

      await screenMatchesGolden(tester, 'dev_clock_widget_inactive');

      // Test 2: Active state (shows floating button shifted up + the bottom orange banner)
      AppClock.setMockTime(DateTime(2026, 3, 9, 12, 0));
      await tester.pump();

      await screenMatchesGolden(tester, 'dev_clock_widget_active');

      AppClock.reset();
    });

    testGoldens('TimeMachineDashboard Bottom Sheet renders correctly', (
      tester,
    ) async {
      AppConfig.environment = AppEnvironment.dev;
      AppClock.setMockTime(DateTime(2026, 3, 8, 1, 59));

      await tester.pumpWidgetBuilder(
        const Scaffold(body: TimeMachineDashboard()),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(450, 600),
      );

      await screenMatchesGolden(tester, 'dev_clock_dashboard');

      AppClock.reset();
    });
  });
}
