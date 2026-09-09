import 'package:clock/clock.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// A globally accessible, reactive mockable clock service.
///
/// In standard operation, it returns the real system time using [clock.now()].
/// In development/testing mode, it can be overridden to return a custom time.
class AppClock {
  static bool _coreClockSet = false;
  static void _ensureCoreClock() {
    if (!_coreClockSet) {
      CoreClock.setNow(() => AppClock.now);
      _coreClockSet = true;
    }
  }

  /// Reactive notifier for the active mock date/time.
  /// A value of `null` indicates that the real system time is being used.
  static final timeNotifier = ValueNotifier<DateTime?>(null);

  /// Gets the current simulated or real time.
  static DateTime get now {
    _ensureCoreClock();
    return timeNotifier.value ?? clock.now();
  }

  /// Sets a specific simulated date/time. Passing `null` reverts to system time.
  static void setMockTime(DateTime? mockTime) {
    _ensureCoreClock();
    timeNotifier.value = mockTime;
  }

  /// Advances the simulated date/time by the given [duration].
  static void advanceTime(Duration duration) {
    _ensureCoreClock();
    timeNotifier.value = now.add(duration);
  }

  /// Resets the clock to use the real system time.
  static void reset() {
    _ensureCoreClock();
    timeNotifier.value = null;
  }

  /// Whether a custom mock clock is currently active.
  static bool get isMockActive => timeNotifier.value != null;
}
