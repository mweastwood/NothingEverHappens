import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/logic/scheduling_policy.dart';
import 'package:nothing_ever_happens/widgets/completion_relative_config_widget.dart';
import '../test_helper.dart';

void main() {
  group('CompletionRelativeConfigWidget Golden Tests', () {
    testGoldens('CompletionRelativeConfigWidget renders correctly', (
      tester,
    ) async {
      const policy = CompletionRelativePolicy(
        interval: Duration(days: 3),
        targetTime: TimeOfDay(hour: 10, minute: 30),
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Standard Config',
          Material(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CompletionRelativeConfigWidget(
                policy: policy,
                onChanged: (_) {},
              ),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: l10nMaterialAppWrapper(),
        surfaceSize: const Size(600, 300),
      );
      await screenMatchesGolden(tester, 'completion_relative_config_widget');
    });
  });
}
