import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/widgets/task_hero_stripe.dart';

void main() {
  group('buildBoundaryBlendedGradient tests', () {
    test('returns empty gradient for empty color list', () {
      final gradient = buildBoundaryBlendedGradient([]);
      expect(gradient.colors, equals([Colors.transparent, Colors.transparent]));
    });

    test('returns matching gradient for single color', () {
      const color = Colors.red;
      final gradient = buildBoundaryBlendedGradient([color]);
      expect(gradient.colors, equals([color, color]));
      expect(gradient.begin, equals(Alignment.topCenter));
      expect(gradient.end, equals(Alignment.bottomCenter));
    });

    test('builds 2-color gradient with boundary blend and solid regions', () {
      const c1 = Colors.blue;
      const c2 = Colors.green;
      final gradient = buildBoundaryBlendedGradient([c1, c2], blendRatio: 0.15);

      expect(gradient.colors, equals([c1, c1, c2, c2]));
      expect(gradient.stops, isNotNull);
      final stops = gradient.stops!;
      expect(stops.length, equals(4));

      // Segment size = 0.5, delta = 0.5 * 0.15 = 0.075
      expect(stops[0], equals(0.0));
      expect(stops[1], closeTo(0.425, 0.001));
      expect(stops[2], closeTo(0.575, 0.001));
      expect(stops[3], equals(1.0));

      // Stops are strictly non-decreasing
      for (int i = 0; i < stops.length - 1; i++) {
        expect(stops[i] <= stops[i + 1], isTrue);
      }
    });

    test('builds 3-color gradient with 2 boundary blends and solid cores', () {
      const c1 = Colors.red;
      const c2 = Colors.yellow;
      const c3 = Colors.blue;
      final gradient = buildBoundaryBlendedGradient([
        c1,
        c2,
        c3,
      ], blendRatio: 0.15);

      expect(gradient.colors, equals([c1, c1, c2, c2, c3, c3]));
      final stops = gradient.stops!;
      expect(stops.length, equals(6));

      // Segment size = 1/3, delta = (1/3) * 0.15 = 0.05
      expect(stops[0], equals(0.0));
      expect(stops[1], closeTo(1 / 3 - 0.05, 0.001));
      expect(stops[2], closeTo(1 / 3 + 0.05, 0.001));
      expect(stops[3], closeTo(2 / 3 - 0.05, 0.001));
      expect(stops[4], closeTo(2 / 3 + 0.05, 0.001));
      expect(stops[5], equals(1.0));

      // Stops strictly ordered
      for (int i = 0; i < stops.length - 1; i++) {
        expect(stops[i] <= stops[i + 1], isTrue);
      }
    });

    test('clamps blendRatio to valid bounds', () {
      const c1 = Colors.red;
      const c2 = Colors.blue;

      // Extreme blend ratios
      final low = buildBoundaryBlendedGradient([c1, c2], blendRatio: -1.0);
      final high = buildBoundaryBlendedGradient([c1, c2], blendRatio: 2.0);

      expect(low.stops![1], closeTo(0.5 - 0.5 * 0.01, 0.001));
      expect(high.stops![1], closeTo(0.5 - 0.5 * 0.4, 0.001));
    });
  });

  group('TaskHeroStripe widget tests', () {
    testWidgets('renders empty shrink when colors is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TaskHeroStripe(colors: [])),
        ),
      );

      final boxFinder = find.byType(DecoratedBox);
      expect(boxFinder, findsNothing);
    });

    testWidgets('renders solid decoration for single color', (tester) async {
      const color = Colors.orange;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TaskHeroStripe(colors: [color], width: 6.0)),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, equals(color));
      expect(decoration.gradient, isNull);

      final sizeBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizeBox.width, equals(6.0));
    });

    testWidgets('renders gradient decoration for multiple colors', (
      tester,
    ) async {
      const colors = [Colors.red, Colors.green, Colors.blue];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TaskHeroStripe(colors: colors, width: 4.0)),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient, isA<LinearGradient>());

      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors.length, equals(6));
    });
  });
}
