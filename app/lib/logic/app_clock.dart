import 'package:flutter/material.dart';

/// A globally accessible, reactive mockable clock service.
///
/// In standard operation, it returns the real system time using [DateTime.now()].
/// In development/testing mode, it can be overridden to return a custom time.
class AppClock {
  /// Reactive notifier for the active mock date/time.
  /// A value of `null` indicates that the real system time is being used.
  static final timeNotifier = ValueNotifier<DateTime?>(null);

  /// Gets the current simulated or real time.
  static DateTime get now => timeNotifier.value ?? DateTime.now();

  /// Sets a specific simulated date/time. Passing `null` reverts to system time.
  static void setMockTime(DateTime? mockTime) {
    timeNotifier.value = mockTime;
  }

  /// Advances the simulated date/time by the given [duration].
  static void advanceTime(Duration duration) {
    timeNotifier.value = now.add(duration);
  }

  /// Resets the clock to use the real system time.
  static void reset() {
    timeNotifier.value = null;
  }

  /// Whether a custom mock clock is currently active.
  static bool get isMockActive => timeNotifier.value != null;
}
