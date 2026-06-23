import 'missed_policy.dart';
import 'task_instance.dart';

enum MissedOccurrenceType { keepAround, autoDismiss }

class MissedOccurrencePolicy {
  final MissedPolicy policy;
  final Duration gracePeriod;

  // Legacy compatibility getters
  MissedOccurrenceType get type => policy == MissedPolicy.autoDismiss
      ? MissedOccurrenceType.autoDismiss
      : MissedOccurrenceType.keepAround;

  const MissedOccurrencePolicy._internal({
    required this.policy,
    required this.gracePeriod,
  });

  const MissedOccurrencePolicy({
    MissedPolicy policy = MissedPolicy.stack,
    Duration? gracePeriod,
  }) : this._internal(
         policy: policy,
         gracePeriod: gracePeriod ?? const Duration(days: 1),
       );

  const MissedOccurrencePolicy.preferNewer()
    : this._internal(
        policy: MissedPolicy.preferNewer,
        gracePeriod: const Duration(days: 1),
      );

  const MissedOccurrencePolicy.preferOlder()
    : this._internal(
        policy: MissedPolicy.preferOlder,
        gracePeriod: const Duration(days: 1),
      );

  const MissedOccurrencePolicy.stack()
    : this._internal(
        policy: MissedPolicy.stack,
        gracePeriod: const Duration(days: 1),
      );

  const MissedOccurrencePolicy.autoDismiss({required Duration gracePeriod})
    : this._internal(
        policy: MissedPolicy.autoDismiss,
        gracePeriod: gracePeriod,
      );

  factory MissedOccurrencePolicy.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final legacyPolicyStr = json['legacyPolicy'] as String?;
    final policyStr = json['policy'] as String?;

    // Check if it's a legacy JSON format
    if (policyStr == null && (typeStr != null || legacyPolicyStr != null)) {
      // Legacy JSON: Reset to stack as requested by the user
      return const MissedOccurrencePolicy.stack();
    }

    final parsedPolicy = MissedPolicy.values.firstWhere(
      (e) => e.name == (policyStr ?? 'stack'),
      orElse: () => MissedPolicy.stack,
    );

    final isLegacySkip = policyStr == 'skip' || legacyPolicyStr == 'skip';

    final policy = isLegacySkip ? MissedPolicy.autoDismiss : parsedPolicy;

    final graceMinutes =
        json['graceMinutes'] as int? ?? (isLegacySkip ? 0 : 24 * 60);

    return MissedOccurrencePolicy._internal(
      policy: policy,
      gracePeriod: Duration(minutes: graceMinutes),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policy': policy.name,
      'type': type.name,
      if (policy == MissedPolicy.autoDismiss)
        'graceMinutes': gracePeriod.inMinutes,
    };
  }

  /// Calculates when the occurrence expires based on its [dueDateTime].
  /// Returns null if the policy is not autoDismiss.
  DateTime? calculateExpiration(DateTime dueDateTime) {
    if (policy == MissedPolicy.autoDismiss) {
      return dueDateTime.add(gracePeriod);
    }
    return null;
  }

  /// Checks if the occurrence is expired at [now] given its [dueDateTime].
  bool isExpired(DateTime dueDateTime, DateTime now) {
    final expiration = calculateExpiration(dueDateTime);
    if (expiration == null) return false;
    return now.isAfter(expiration);
  }

  /// Checks if the task instance is expired at [now] under this policy.
  bool isInstanceExpired(TaskInstance instance, DateTime now) {
    final dueDateTime = instance.dueRelativeTime.referenceTo(
      instance.scheduledDate,
    );
    return isExpired(dueDateTime, now);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissedOccurrencePolicy &&
        other.policy == policy &&
        other.gracePeriod == gracePeriod;
  }

  @override
  int get hashCode => Object.hash(policy, gracePeriod);

  @override
  String toString() {
    return 'MissedOccurrencePolicy(policy: $policy, gracePeriod: $gracePeriod)';
  }
}
