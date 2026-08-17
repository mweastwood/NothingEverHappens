import 'package:flutter/material.dart';

/// The responsive breakpoint width in logical pixels.
/// Screens with width >= 600.0 are considered wide screens.
const double kWideScreenBreakpoint = 600.0;

/// Returns true if the screen width is greater than or equal to [kWideScreenBreakpoint].
bool isWideScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint;
}
