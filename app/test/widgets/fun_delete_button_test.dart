import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart' hide materialAppWrapper;
import 'package:nothing_ever_happens/widgets/fun_delete_button.dart';
import '../test_helper.dart';

void main() {
  testWidgets('FunDeleteButton renders and displays close icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: Center(child: FunDeleteButton(onTap: () {})),
        ),
      ),
    );

    expect(find.byType(FunDeleteButton), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('FunDeleteButton calls onTap when tapped after delays', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      buildTestableWidget(
        child: Scaffold(
          body: Center(child: FunDeleteButton(onTap: () => tapped = true)),
        ),
      ),
    );

    await tester.tap(find.byType(FunDeleteButton));
    await tester.pump(); // Register tap

    // Tap triggers Future.delayed with 350ms
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(); // Executes onTap callback

    expect(tapped, isTrue);
  });

  testGoldens('FunDeleteButton renders correctly', (tester) async {
    final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1)
      ..addScenario(
        'Default state',
        Center(child: FunDeleteButton(onTap: () {})),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: l10nMaterialAppWrapper(),
    );
    await screenMatchesGolden(tester, 'fun_delete_button');
  });

  group('PoofPainter Unit Tests', () {
    test('PoofPainter generates exactly 12 particles with random values', () {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      final painter = PoofPainter(animation: controller);
      expect(painter.particles.length, equals(12));
      for (final particle in painter.particles) {
        expect(particle.angle, greaterThanOrEqualTo(0.0));
        expect(particle.angle, lessThanOrEqualTo(2 * pi));
        expect(particle.speed, greaterThanOrEqualTo(6.0));
        expect(particle.speed, lessThanOrEqualTo(18.0));
        expect(particle.size, greaterThanOrEqualTo(3.0));
        expect(particle.size, lessThanOrEqualTo(7.0));
      }
      controller.dispose();
    });
  });
}
