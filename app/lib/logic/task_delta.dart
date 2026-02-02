class TaskDelta {
  final String id;
  final String taskId;
  final DateTime timestamp;
  final DateTime expiresAt;
  final String operation;
  final Map<String, dynamic> changedFields;
  final String userId;

  TaskDelta({
    required this.id,
    required this.taskId,
    required this.timestamp,
    required this.expiresAt,
    required this.operation,
    required this.changedFields,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'operation': operation,
      'changedFields': changedFields,
      'userId': userId,
    };
  }

  factory TaskDelta.fromJson(Map<String, dynamic> json) {
    return TaskDelta(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      operation: json['operation'] as String,
      changedFields: (json['changedFields'] as Map<String, dynamic>?) ?? {},
      userId: json['userId'] as String,
    );
  }
}
