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
