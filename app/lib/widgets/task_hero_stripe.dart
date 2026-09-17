import 'package:flutter/material.dart';

/// Constructs a [LinearGradient] that preserves solid color segments for each
/// color while smoothly blending only at the boundaries between adjacent colors.
///
/// [blendRatio] controls the fraction of each segment's length allocated to the
/// blend on either side of a boundary (clamped to [0.01, 0.4]).
LinearGradient buildBoundaryBlendedGradient(
  List<Color> colors, {
  double blendRatio = 0.15,
}) {
  if (colors.isEmpty) {
    return const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    );
  }
  if (colors.length == 1) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colors.first, colors.first],
    );
  }

  final n = colors.length;
  final s = 1.0 / n;
  final delta = s * blendRatio.clamp(0.01, 0.4);

  final gradientColors = <Color>[];
  final stops = <double>[];

  for (int i = 0; i < n; i++) {
    final startBoundary = i * s;
    final endBoundary = (i + 1) * s;

    // Start stop of color segment i
    if (i == 0) {
      gradientColors.add(colors[i]);
      stops.add(0.0);
    } else {
      gradientColors.add(colors[i]);
      stops.add((startBoundary + delta).clamp(0.0, 1.0));
    }

    // End stop of color segment i
    if (i == n - 1) {
      gradientColors.add(colors[i]);
      stops.add(1.0);
    } else {
      gradientColors.add(colors[i]);
      stops.add((endBoundary - delta).clamp(0.0, 1.0));
    }
  }

  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: gradientColors,
    stops: stops,
  );
}

/// A vertical hero accent stripe for task cards that visually indicates label colors.
///
/// For a single color, renders a solid vertical bar.
/// For multiple colors, evenly splits the vertical bar across all colors and
/// applies a smooth gradient blend specifically across each color boundary,
/// preserving solid color bodies for each label.
class TaskHeroStripe extends StatelessWidget {
  final List<Color> colors;
  final double width;
  final double blendRatio;
  final BorderRadius? borderRadius;

  const TaskHeroStripe({
    super.key,
    required this.colors,
    this.width = 4.0,
    this.blendRatio = 0.15,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(12.0),
      bottomLeft: Radius.circular(12.0),
    ),
  });

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    final decoration = colors.length == 1
        ? BoxDecoration(color: colors.first, borderRadius: borderRadius)
        : BoxDecoration(
            gradient: buildBoundaryBlendedGradient(
              colors,
              blendRatio: blendRatio,
            ),
            borderRadius: borderRadius,
          );

    return SizedBox(
      width: width,
      child: DecoratedBox(decoration: decoration),
    );
  }
}
