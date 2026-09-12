import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:nothing_ever_happens/main.dart';

void main() {
  test(
    'MyApp.bridgeColorScheme converts dynamic material_ui.ColorScheme to Flutter ColorScheme accurately including fixed color roles',
    () {
      const modern = material_ui.ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF112233),
        onPrimary: Color(0xFF223344),
        primaryContainer: Color(0xFF334455),
        onPrimaryContainer: Color(0xFF445566),
        primaryFixed: Color(0xFF102030),
        primaryFixedDim: Color(0xFF152535),
        onPrimaryFixed: Color(0xFF1A2A3A),
        onPrimaryFixedVariant: Color(0xFF1F2F3F),
        secondary: Color(0xFF556677),
        onSecondary: Color(0xFF667788),
        secondaryContainer: Color(0xFF778899),
        onSecondaryContainer: Color(0xFF8899AA),
        secondaryFixed: Color(0xFF506070),
        secondaryFixedDim: Color(0xFF556575),
        onSecondaryFixed: Color(0xFF5A6A7A),
        onSecondaryFixedVariant: Color(0xFF5F6F7F),
        tertiary: Color(0xFF99AABB),
        onTertiary: Color(0xFFAABBCC),
        tertiaryContainer: Color(0xFFBBCCDD),
        onTertiaryContainer: Color(0xFFCCDDEE),
        tertiaryFixed: Color(0xFF90A0B0),
        tertiaryFixedDim: Color(0xFF95A5B5),
        onTertiaryFixed: Color(0xFF9AAABA),
        onTertiaryFixedVariant: Color(0xFF9FAFAF),
        error: Color(0xFFDDEEFF),
        onError: Color(0xFFEEFF00),
        errorContainer: Color(0xFFFF0011),
        onErrorContainer: Color(0xFF001122),
        surface: Color(0xFF123456),
        onSurface: Color(0xFF234567),
        surfaceDim: Color(0xFF345678),
        surfaceBright: Color(0xFF456789),
        surfaceContainerLowest: Color(0xFF56789A),
        surfaceContainerLow: Color(0xFF6789AB),
        surfaceContainer: Color(0xFF789ABC),
        surfaceContainerHigh: Color(0xFF89ABCD),
        surfaceContainerHighest: Color(0xFF9ABCDE),
        onSurfaceVariant: Color(0xFFABCDEF),
        outline: Color(0xFFBCDEF0),
        outlineVariant: Color(0xFFCDEF01),
        shadow: Color(0xFFDEF012),
        scrim: Color(0xFFEF0123),
        inverseSurface: Color(0xFFF01234),
        onInverseSurface: Color(0xFF012345),
        inversePrimary: Color(0xFF123450),
        surfaceTint: Color(0xFF234501),
      );

      final bridged = MyApp.bridgeColorScheme(modern);

      expect(bridged.brightness, Brightness.light);
      expect(bridged.primary, const Color(0xFF112233));
      expect(bridged.onPrimary, const Color(0xFF223344));
      expect(bridged.primaryContainer, const Color(0xFF334455));
      expect(bridged.onPrimaryContainer, const Color(0xFF445566));
      expect(bridged.primaryFixed, const Color(0xFF102030));
      expect(bridged.primaryFixedDim, const Color(0xFF152535));
      expect(bridged.onPrimaryFixed, const Color(0xFF1A2A3A));
      expect(bridged.onPrimaryFixedVariant, const Color(0xFF1F2F3F));
      expect(bridged.secondary, const Color(0xFF556677));
      expect(bridged.onSecondary, const Color(0xFF667788));
      expect(bridged.secondaryContainer, const Color(0xFF778899));
      expect(bridged.onSecondaryContainer, const Color(0xFF8899AA));
      expect(bridged.secondaryFixed, const Color(0xFF506070));
      expect(bridged.secondaryFixedDim, const Color(0xFF556575));
      expect(bridged.onSecondaryFixed, const Color(0xFF5A6A7A));
      expect(bridged.onSecondaryFixedVariant, const Color(0xFF5F6F7F));
      expect(bridged.tertiary, const Color(0xFF99AABB));
      expect(bridged.onTertiary, const Color(0xFFAABBCC));
      expect(bridged.tertiaryContainer, const Color(0xFFBBCCDD));
      expect(bridged.onTertiaryContainer, const Color(0xFFCCDDEE));
      expect(bridged.tertiaryFixed, const Color(0xFF90A0B0));
      expect(bridged.tertiaryFixedDim, const Color(0xFF95A5B5));
      expect(bridged.onTertiaryFixed, const Color(0xFF9AAABA));
      expect(bridged.onTertiaryFixedVariant, const Color(0xFF9FAFAF));
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

      // Also verify extension method produces matching scheme
      final viaExtension = modern.toFlutterColorScheme();
      expect(viaExtension, bridged);
    },
  );
}
