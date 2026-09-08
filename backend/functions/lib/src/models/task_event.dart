import 'package:meta/meta.dart';

/// Incoming external task event payload from satellite applications.
@immutable
class ExternalTaskEvent {
  final String userId;
  final String providerId;
  final String entityType;
  final String externalId;
  final String date; // YYYY-MM-DD
  final String action; // 'completed' | 'uncompleted' | 'dismissed'
  final String? timestamp;
  final Map<String, dynamic>? metadata;

  const ExternalTaskEvent({
    required this.userId,
    required this.providerId,
    required this.entityType,
    required this.externalId,
    required this.date,
    required this.action,
    this.timestamp,
    this.metadata,
  });

  factory ExternalTaskEvent.fromJson(Map<String, dynamic> json) {
    return ExternalTaskEvent(
      userId: json['userId'] as String,
      providerId: json['providerId'] as String,
      entityType: json['entityType'] as String,
      externalId: json['externalId'] as String,
      date: json['date'] as String,
      action: json['action'] as String,
      timestamp: json['timestamp'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'userId': userId,
      'providerId': providerId,
      'entityType': entityType,
      'externalId': externalId,
      'date': date,
      'action': action,
    };
    if (timestamp != null) map['timestamp'] = timestamp;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExternalTaskEvent &&
        other.userId == userId &&
        other.providerId == providerId &&
        other.entityType == entityType &&
        other.externalId == externalId &&
        other.date == date &&
        other.action == action &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        providerId,
        entityType,
        externalId,
        date,
        action,
        timestamp,
      );
}

/// Result returned after processing an [ExternalTaskEvent].
@immutable
class TaskEventResult {
  final bool success;
  final String? instanceId;
  final String actionApplied;
  final bool? createdNewInstance;
  final String? message;

  const TaskEventResult({
    required this.success,
    this.instanceId,
    required this.actionApplied,
    this.createdNewInstance,
    this.message,
  });

  factory TaskEventResult.fromJson(Map<String, dynamic> json) {
    return TaskEventResult(
      success: json['success'] as bool? ?? false,
      instanceId: json['instanceId'] as String?,
      actionApplied: (json['actionApplied'] as String?) ?? '',
      createdNewInstance: json['createdNewInstance'] as bool?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'success': success,
      'actionApplied': actionApplied,
    };
    if (instanceId != null) map['instanceId'] = instanceId;
    if (createdNewInstance != null) {
      map['createdNewInstance'] = createdNewInstance;
    }
    if (message != null) map['message'] = message;
    return map;
  }
}

/// Validation result for incoming task event payloads.
@immutable
class TaskEventValidation {
  final bool valid;
  final String? error;
  final ExternalTaskEvent? event;

  const TaskEventValidation({
    required this.valid,
    this.error,
    this.event,
  });
}

/// Authentication result for task event requests.
@immutable
class TaskAuthValidationResult {
  final bool authenticated;
  final int? status;
  final String? error;

  const TaskAuthValidationResult({
    required this.authenticated,
    this.status,
    this.error,
  });
}
