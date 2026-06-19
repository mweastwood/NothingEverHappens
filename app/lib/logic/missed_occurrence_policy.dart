import 'missed_policy.dart';

enum MissedOccurrenceType { keepAround, autoDismiss }

class MissedOccurrencePolicy {
  final MissedOccurrenceType type;
  final Duration? gracePeriod;
  final MissedPolicy legacyPolicy;

  const MissedOccurrencePolicy.keepAround({
    this.legacyPolicy = MissedPolicy.rollover,
  }) : type = MissedOccurrenceType.keepAround,
       gracePeriod = null;

  const MissedOccurrencePolicy.autoDismiss({required Duration this.gracePeriod})
    : type = MissedOccurrenceType.autoDismiss,
      legacyPolicy = MissedPolicy.skip;

  factory MissedOccurrencePolicy.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = MissedOccurrenceType.values.firstWhere(
      (e) => e.name == typeStr,
    );
    if (type == MissedOccurrenceType.autoDismiss) {
      final graceMinutes = json['graceMinutes'] as int;
      return MissedOccurrencePolicy.autoDismiss(
        gracePeriod: Duration(minutes: graceMinutes),
      );
    }
    final legacyPolicyStr = json['legacyPolicy'] as String?;
    final legacyPolicy = legacyPolicyStr != null
        ? MissedPolicy.values.firstWhere((e) => e.name == legacyPolicyStr)
        : MissedPolicy.rollover;
    return MissedOccurrencePolicy.keepAround(legacyPolicy: legacyPolicy);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'legacyPolicy': legacyPolicy.name,
      if (type == MissedOccurrenceType.autoDismiss)
        'graceMinutes': gracePeriod!.inMinutes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissedOccurrencePolicy &&
        other.type == type &&
        other.gracePeriod == gracePeriod &&
        other.legacyPolicy == legacyPolicy;
  }

  @override
  int get hashCode => Object.hash(type, gracePeriod, legacyPolicy);

  @override
  String toString() {
    return 'MissedOccurrencePolicy(type: $type, gracePeriod: $gracePeriod, legacyPolicy: $legacyPolicy)';
  }
}
