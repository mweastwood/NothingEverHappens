import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/fun_check_button.dart';
import '../test_helper.dart';

void main() {
  testWidgets('FunCheckButton shows check icon when true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: FunCheckButton(value: true, onChanged: (value) {}),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets(
    'FunCheckButton does not show check icon when false and not hovering',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: FunCheckButton(value: false, onChanged: (value) {}),
          ),
        ),
      );

      // Initial state: not checked, not hovering
      expect(find.byType(Icon), findsNothing);
    },
  );

  testWidgets('FunCheckButton calls onChanged when tapped', (
    WidgetTester tester,
  ) async {
    bool? changedValue;
    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: FunCheckButton(
            value: false,
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FunCheckButton));
    // Wait for the shrink animation (forward)
    await tester.pump(const Duration(milliseconds: 100));
    // Wait for the expand animation (reverse)
    await tester.pump(const Duration(milliseconds: 100));

    expect(changedValue, isTrue);
  });
  testGoldens('FunCheckButton renders correctly', (tester) async {
    final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 1)
      ..addScenario(
        'Unchecked',
        FunCheckButton(value: false, onChanged: (_) {}),
      )
      ..addScenario('Checked', FunCheckButton(value: true, onChanged: (_) {}));

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: l10nMaterialAppWrapper(),
    );
    await screenMatchesGolden(tester, 'fun_check_button');
  });

  group('ConfettiPainter Unit Tests', () {
    test(
      'ConfettiPainter generates exactly 20 particles with random values',
      () {
        final controller = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(milliseconds: 100),
        );
        const colorScheme = ColorScheme.light();
        final painter = ConfettiPainter(
          animation: controller,
          colorScheme: colorScheme,
        );
        expect(painter.particles.length, equals(20));
        for (final particle in painter.particles) {
          expect(particle.angle, greaterThanOrEqualTo(0.0));
          expect(particle.angle, lessThanOrEqualTo(2 * pi));
          expect(particle.speed, greaterThanOrEqualTo(10.0));
          expect(particle.speed, lessThanOrEqualTo(30.0));
          expect(particle.offset, greaterThanOrEqualTo(0.0));
          expect(particle.offset, lessThanOrEqualTo(2 * pi));
        }
        controller.dispose();
      },
    );
  });
}
