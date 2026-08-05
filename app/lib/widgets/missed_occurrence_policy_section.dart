import 'package:flutter/material.dart';
import '../logic/missed_occurrence_policy.dart';
import 'missed_occurrence_policy_selector.dart';

class MissedOccurrencePolicySection extends StatelessWidget {
  final bool showMissedPolicy;
  final MissedOccurrencePolicy? missedOccurrencePolicy;
  final ValueChanged<MissedOccurrencePolicy>? onMissedOccurrencePolicyChanged;
  final String keyPrefix;

  const MissedOccurrencePolicySection({
    super.key,
    required this.showMissedPolicy,
    required this.missedOccurrencePolicy,
    required this.onMissedOccurrencePolicyChanged,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    if (showMissedPolicy &&
        missedOccurrencePolicy != null &&
        onMissedOccurrencePolicyChanged != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          MissedOccurrencePolicySelector(
            key: Key('${keyPrefix}_missed_policy'),
            policy: missedOccurrencePolicy!,
            onChanged: onMissedOccurrencePolicyChanged!,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
