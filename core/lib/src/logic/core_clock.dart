/// A pure Dart pluggable clock service that defaults to [DateTime.now()].
class CoreClock {
  static DateTime Function() _now = () => DateTime.now();

  /// Gets the current date/time.
  static DateTime get now => _now();

  /// Sets a custom provider for [now].
  static void setNow(DateTime Function() fn) {
    _now = fn;
  }

  /// Resets the clock to the system default [DateTime.now()].
  static void reset() {
    _now = () => DateTime.now();
  }
}
