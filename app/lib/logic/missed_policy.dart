enum MissedPolicy {
  preferNewer,
  preferOlder,
  stack,
  autoDismiss,

  // Legacy members kept for compiling existing database serialization and test code
  @Deprecated('Use preferNewer instead')
  skip,
}
