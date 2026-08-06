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
        return TaskStatus.skipped;
      case 'failed':
        return TaskStatus.failed;
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }
}
