enum TaskStatus {
  pending,
  completed,
  skipped,
  failed;

  String toJson() => name;

  static TaskStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return TaskStatus.completed;
      case 'skipped':
      case 'dismissed':
        return TaskStatus.skipped;
      case 'failed':
        return TaskStatus.failed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
}

/// Typed status reason describing why a [TaskInstance] entered its current status.
enum InstanceStatusReason {
  userCompleted('user_completed'),
  userDismissed('user_dismissed'),
  userModified('user_modified'),
  schedulerAutoDismiss('scheduler_auto_dismiss'),
  schedulerPreferNewer('scheduler_prefer_newer'),
  schedulerPreferOlder('scheduler_prefer_older'),
  schedulerCapacityLimit('scheduler_capacity_limit'),
  schedulerGenerated('scheduler_generated');

  const InstanceStatusReason(this.value);

  final String value;

  bool get isUserAction =>
      this == userCompleted || this == userDismissed || this == userModified;

  bool get isSchedulerAction => !isUserAction;

  bool get isRevivableByCapacity => this == schedulerCapacityLimit;

  static InstanceStatusReason? tryParse(String? raw) {
    if (raw == null) return null;
    for (final reason in InstanceStatusReason.values) {
      if (reason.value == raw) return reason;
    }
    return null;
  }
}
