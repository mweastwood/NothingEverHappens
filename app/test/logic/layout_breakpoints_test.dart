import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/utils/layout_breakpoints.dart';

void main() {
  group('layout_breakpoints', () {
    test('kWideScreenBreakpoint is 600.0', () {
      expect(kWideScreenBreakpoint, 600.0);
    });

    testWidgets('isWideScreen returns false for narrow viewports (<600)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = isWideScreen(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result, isFalse);
    });

    testWidgets('isWideScreen returns true for 600px width', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = isWideScreen(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result, isTrue);
    });

    testWidgets('isWideScreen returns true for wide viewports (>600)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = isWideScreen(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result, isTrue);
    });
  });
}
