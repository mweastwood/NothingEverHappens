import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/main.dart';

class _FakeModernColorScheme {
  final Brightness brightness = Brightness.light;
  final Color primary = const Color(0xFF112233);
  final Color onPrimary = const Color(0xFF223344);
  final Color primaryContainer = const Color(0xFF334455);
  final Color onPrimaryContainer = const Color(0xFF445566);
  final Color secondary = const Color(0xFF556677);
  final Color onSecondary = const Color(0xFF667788);
  final Color secondaryContainer = const Color(0xFF778899);
  final Color onSecondaryContainer = const Color(0xFF8899AA);
  final Color tertiary = const Color(0xFF99AABB);
  final Color onTertiary = const Color(0xFFAABBCC);
  final Color tertiaryContainer = const Color(0xFFBBCCDD);
  final Color onTertiaryContainer = const Color(0xFFCCDDEE);
  final Color error = const Color(0xFFDDEEFF);
  final Color onError = const Color(0xFFEEFF00);
  final Color errorContainer = const Color(0xFFFF0011);
  final Color onErrorContainer = const Color(0xFF001122);
  final Color surface = const Color(0xFF123456);
  final Color onSurface = const Color(0xFF234567);
  final Color surfaceDim = const Color(0xFF345678);
  final Color surfaceBright = const Color(0xFF456789);
  final Color surfaceContainerLowest = const Color(0xFF56789A);
  final Color surfaceContainerLow = const Color(0xFF6789AB);
  final Color surfaceContainer = const Color(0xFF789ABC);
  final Color surfaceContainerHigh = const Color(0xFF89ABCD);
  final Color surfaceContainerHighest = const Color(0xFF9ABCDE);
  final Color onSurfaceVariant = const Color(0xFFABCDEF);
  final Color outline = const Color(0xFFBCDEF0);
  final Color outlineVariant = const Color(0xFFCDEF01);
  final Color shadow = const Color(0xFFDEF012);
  final Color scrim = const Color(0xFFEF0123);
  final Color inverseSurface = const Color(0xFFF01234);
  final Color onInverseSurface = const Color(0xFF012345);
  final Color inversePrimary = const Color(0xFF123450);
  final Color surfaceTint = const Color(0xFF234501);
}

void main() {
  test(
    'MyApp.bridgeColorScheme converts dynamic scheme to legacy ColorScheme accurately',
    () {
      final modern = _FakeModernColorScheme();
      final bridged = MyApp.bridgeColorScheme(modern);

      expect(bridged.brightness, Brightness.light);
      expect(bridged.primary, const Color(0xFF112233));
      expect(bridged.onPrimary, const Color(0xFF223344));
      expect(bridged.primaryContainer, const Color(0xFF334455));
      expect(bridged.onPrimaryContainer, const Color(0xFF445566));
      expect(bridged.secondary, const Color(0xFF556677));
      expect(bridged.onSecondary, const Color(0xFF667788));
      expect(bridged.secondaryContainer, const Color(0xFF778899));
      expect(bridged.onSecondaryContainer, const Color(0xFF8899AA));
      expect(bridged.tertiary, const Color(0xFF99AABB));
      expect(bridged.onTertiary, const Color(0xFFAABBCC));
      expect(bridged.tertiaryContainer, const Color(0xFFBBCCDD));
      expect(bridged.onTertiaryContainer, const Color(0xFFCCDDEE));
      expect(bridged.error, const Color(0xFFDDEEFF));
      expect(bridged.onError, const Color(0xFFEEFF00));
      expect(bridged.errorContainer, const Color(0xFFFF0011));
      expect(bridged.onErrorContainer, const Color(0xFF001122));
      expect(bridged.surface, const Color(0xFF123456));
      expect(bridged.onSurface, const Color(0xFF234567));
      expect(bridged.surfaceDim, const Color(0xFF345678));
      expect(bridged.surfaceBright, const Color(0xFF456789));
      expect(bridged.surfaceContainerLowest, const Color(0xFF56789A));
      expect(bridged.surfaceContainerLow, const Color(0xFF6789AB));
      expect(bridged.surfaceContainer, const Color(0xFF789ABC));
      expect(bridged.surfaceContainerHigh, const Color(0xFF89ABCD));
      expect(bridged.surfaceContainerHighest, const Color(0xFF9ABCDE));
      expect(bridged.onSurfaceVariant, const Color(0xFFABCDEF));
      expect(bridged.outline, const Color(0xFFBCDEF0));
      expect(bridged.outlineVariant, const Color(0xFFCDEF01));
      expect(bridged.shadow, const Color(0xFFDEF012));
      expect(bridged.scrim, const Color(0xFFEF0123));
      expect(bridged.inverseSurface, const Color(0xFFF01234));
      expect(bridged.onInverseSurface, const Color(0xFF012345));
      expect(bridged.inversePrimary, const Color(0xFF123450));
      expect(bridged.surfaceTint, const Color(0xFF234501));
    },
  );
}
