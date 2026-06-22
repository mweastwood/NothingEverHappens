import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/missed_policy.dart';

class MissedOccurrencePolicySelector extends StatefulWidget {
  final MissedOccurrencePolicy policy;
  final ValueChanged<MissedOccurrencePolicy> onChanged;
  final bool readOnly;

  const MissedOccurrencePolicySelector({
    super.key,
    required this.policy,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<MissedOccurrencePolicySelector> createState() =>
      _MissedOccurrencePolicySelectorState();
}

class _MissedOccurrencePolicySelectorState
    extends State<MissedOccurrencePolicySelector> {
  late String _preset;
  late TextEditingController _customController;
  late String _customUnit;

  @override
  void initState() {
    super.initState();
    _preset = _getGracePreset(widget.policy.gracePeriod);
    final (val, unit) = _getCustomValueAndUnit(widget.policy.gracePeriod);
    _customController = TextEditingController(text: val.toString());
    _customUnit = unit;
  }

  @override
  void didUpdateWidget(MissedOccurrencePolicySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      _preset = _getGracePreset(widget.policy.gracePeriod);
      final (val, unit) = _getCustomValueAndUnit(widget.policy.gracePeriod);
      if (_customController.text != val.toString()) {
        _customController.text = val.toString();
      }
      _customUnit = unit;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _getGracePreset(Duration gracePeriod) {
    if (gracePeriod == Duration.zero) return 'immediate';
    if (gracePeriod == const Duration(hours: 1)) return '1h';
    if (gracePeriod == const Duration(hours: 6)) return '6h';
    if (gracePeriod == const Duration(hours: 12)) return '12h';
    if (gracePeriod == const Duration(days: 1)) return '24h';
    return 'custom';
  }

  (int, String) _getCustomValueAndUnit(Duration duration) {
    if (duration.inMinutes == 0) return (0, 'hours');
    if (duration.inMinutes % (24 * 60) == 0) {
      return (duration.inDays, 'days');
    }
    if (duration.inMinutes % 60 == 0) {
      return (duration.inHours, 'hours');
    }
    return (duration.inMinutes, 'minutes');
  }

  Duration _getDurationFromPreset(String preset) {
    switch (preset) {
      case 'immediate':
        return Duration.zero;
      case '1h':
        return const Duration(hours: 1);
      case '6h':
        return const Duration(hours: 6);
      case '12h':
        return const Duration(hours: 12);
      case '24h':
        return const Duration(days: 1);
      case 'custom':
      default:
        final val = int.tryParse(_customController.text) ?? 1;
        return _getDurationFromCustom(val, _customUnit);
    }
  }

  Duration _getDurationFromCustom(int value, String unit) {
    switch (unit) {
      case 'days':
        return Duration(days: value);
      case 'hours':
        return Duration(hours: value);
      case 'minutes':
      default:
        return Duration(minutes: value);
    }
  }

  void _triggerChange({
    MissedPolicy? policy,
    String? preset,
    int? customVal,
    String? customUnit,
  }) {
    final currentPolicy = policy ?? widget.policy.policy;
    final currentPreset = preset ?? _preset;

    if (currentPolicy != MissedPolicy.autoDismiss) {
      widget.onChanged(MissedOccurrencePolicy(policy: currentPolicy));
    } else {
      final parsedVal = customVal ?? int.tryParse(_customController.text) ?? 1;
      final parsedUnit = customUnit ?? _customUnit;
      final duration = currentPreset == 'custom'
          ? _getDurationFromCustom(parsedVal, parsedUnit)
          : _getDurationFromPreset(currentPreset);
      widget.onChanged(
        MissedOccurrencePolicy.autoDismiss(gracePeriod: duration),
      );
    }
  }

  (String, String, List<_TimelineDayState>) _getPolicyInfo(
    MissedPolicy policy,
  ) {
    switch (policy) {
      case MissedPolicy.preferNewer:
        return (
          'Prefer Newer',
          'Only the latest occurrence remains active. Older missed occurrences are automatically skipped so you can start fresh.',
          [
            _TimelineDayState.skipped,
            _TimelineDayState.skipped,
            _TimelineDayState.active,
          ],
        );
      case MissedPolicy.preferOlder:
        return (
          'Prefer Older',
          'Only the oldest unfinished occurrence stays active. Subsequent occurrences are skipped until it is completed.',
          [
            _TimelineDayState.active,
            _TimelineDayState.skipped,
            _TimelineDayState.skipped,
          ],
        );
      case MissedPolicy.stack:
        return (
          'Stack',
          'Keep all occurrences active. Missed occurrences accumulate in a backlog and must be completed individually.',
          [
            _TimelineDayState.active,
            _TimelineDayState.active,
            _TimelineDayState.active,
          ],
        );
      case MissedPolicy.autoDismiss:
      default:
        return (
          'Auto-Dismiss',
          'Occurrences accumulate but are automatically dismissed/skipped after a configurable grace period.',
          [
            _TimelineDayState.skipped,
            _TimelineDayState.skipped,
            _TimelineDayState.active,
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPolicy = widget.policy.policy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Missed Occurrence Policy',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "In the examples shown below, assume we have a daily task that we didn't complete, check-off, or dismiss the task in any way on Monday or Tuesday. It is now Wednesday, so what should be done with the older tasks?",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        _buildSelectedPolicyCard(theme, selectedPolicy),
        if (selectedPolicy == MissedPolicy.autoDismiss) ...[
          const SizedBox(height: 12),
          _buildGracePeriodSelector(theme),
        ],
      ],
    );
  }

  Widget _buildSelectedPolicyCard(ThemeData theme, MissedPolicy policy) {
    final (title, description, states) = _getPolicyInfo(policy);
    final isAutoDismiss = policy == MissedPolicy.autoDismiss;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.readOnly
              ? null
              : () => _showPolicySelectionDialog(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (!widget.readOnly)
                      Icon(
                        Icons.arrow_drop_down_circle_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMiniTimeline(theme, states, isAutoDismiss: isAutoDismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPolicySelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Missed Occurrence Policy'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "In the examples shown below, assume we have a daily task that we didn't complete, check-off, or dismiss the task in any way on Monday or Tuesday. It is now Wednesday, so what should be done with the older tasks?",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogPolicyCard(
                    dialogContext,
                    MissedPolicy.preferNewer,
                  ),
                  _buildDialogPolicyCard(
                    dialogContext,
                    MissedPolicy.preferOlder,
                  ),
                  _buildDialogPolicyCard(dialogContext, MissedPolicy.stack),
                  _buildDialogPolicyCard(
                    dialogContext,
                    MissedPolicy.autoDismiss,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogPolicyCard(
    BuildContext dialogContext,
    MissedPolicy policy,
  ) {
    final theme = Theme.of(context);
    final selectedPolicy = widget.policy.policy;
    final selected = selectedPolicy == policy;
    final (title, description, states) = _getPolicyInfo(policy);
    final isAutoDismiss = policy == MissedPolicy.autoDismiss;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2.0 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _triggerChange(policy: policy);
            });
            Navigator.of(dialogContext).pop();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 8),
                  child: _buildMiniTimeline(
                    theme,
                    states,
                    isAutoDismiss: isAutoDismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTimeline(
    ThemeData theme,
    List<_TimelineDayState> states, {
    required bool isAutoDismiss,
  }) {
    final days = ['Mon', 'Tue', 'Wed (Today)'];
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          _buildMiniDay(theme, days[i], states[i], isAutoDismiss && i < 2),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                color: _getLineColor(theme, states[i], states[i + 1]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMiniDay(
    ThemeData theme,
    String dayLabel,
    _TimelineDayState state,
    bool isExpired,
  ) {
    Color circleColor;
    Color textColor;
    Border? border;
    IconData? icon;

    switch (state) {
      case _TimelineDayState.active:
        circleColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        icon = Icons.play_arrow_rounded;
        break;
      case _TimelineDayState.skipped:
        circleColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
        icon = isExpired
            ? Icons.access_time_filled_rounded
            : Icons.block_flipped;
        break;
      case _TimelineDayState.future:
        circleColor = theme.colorScheme.surface;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
        border = Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        );
        icon = Icons.calendar_month_outlined;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: state == _TimelineDayState.active
                ? FontWeight.bold
                : FontWeight.normal,
            color: state == _TimelineDayState.active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: border,
            boxShadow: state == _TimelineDayState.active
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 14,
              color: state == _TimelineDayState.active
                  ? theme.colorScheme.onPrimary
                  : textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state == _TimelineDayState.active
              ? 'Active'
              : (isExpired ? 'Expired' : 'Skipped'),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            fontWeight: state == _TimelineDayState.active
                ? FontWeight.bold
                : FontWeight.normal,
            color: state == _TimelineDayState.active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Color _getLineColor(
    ThemeData theme,
    _TimelineDayState start,
    _TimelineDayState end,
  ) {
    if (start == _TimelineDayState.active && end == _TimelineDayState.active) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
  }

  Widget _buildGracePeriodSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _preset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Dismiss After',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'immediate', child: Text('Immediately')),
            DropdownMenuItem(value: '1h', child: Text('1 Hour')),
            DropdownMenuItem(value: '6h', child: Text('6 Hours')),
            DropdownMenuItem(value: '12h', child: Text('12 Hours')),
            DropdownMenuItem(value: '24h', child: Text('24 Hours (1 Day)')),
            DropdownMenuItem(
              value: 'custom',
              child: Text('Custom Duration...'),
            ),
          ],
          onChanged: widget.readOnly
              ? null
              : (val) {
                  if (val != null) {
                    setState(() {
                      _preset = val;
                    });
                    _triggerChange(preset: val);
                  }
                },
        ),
        if (_preset == 'custom') ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !widget.readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final intVal = int.tryParse(val) ?? 1;
                    _triggerChange(customVal: intVal);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _customUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'minutes',
                      child: Text('Minute(s)'),
                    ),
                    DropdownMenuItem(value: 'hours', child: Text('Hour(s)')),
                    DropdownMenuItem(value: 'days', child: Text('Day(s)')),
                  ],
                  onChanged: widget.readOnly
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _customUnit = val;
                            });
                            _triggerChange(customUnit: val);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _TimelineDayState { active, skipped, future }
