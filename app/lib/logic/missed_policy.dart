enum MissedPolicy {
  preferNewer,
  preferOlder,
  stack,
  autoDismiss,

  // Legacy members kept for compiling existing database serialization and test code
  @Deprecated('Use preferOlder or stack instead')
  rollover,
  @Deprecated('Use preferNewer instead')
  skip,
  @Deprecated('Use preferOlder instead')
  shift,
}
