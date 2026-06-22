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
        const SizedBox(height: 8),
        DropdownButtonFormField<MissedPolicy>(
          initialValue: selectedPolicy,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(
              value: MissedPolicy.preferNewer,
              child: Text('Prefer Newer'),
            ),
            DropdownMenuItem(
              value: MissedPolicy.preferOlder,
              child: Text('Prefer Older'),
            ),
            DropdownMenuItem(value: MissedPolicy.stack, child: Text('Stack')),
            DropdownMenuItem(
              value: MissedPolicy.autoDismiss,
              child: Text('Auto-Dismiss'),
            ),
          ],
          onChanged: widget.readOnly
              ? null
              : (val) {
                  if (val != null) {
                    _triggerChange(policy: val);
                  }
                },
        ),
        if (selectedPolicy == MissedPolicy.autoDismiss) ...[
          const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        _buildTimelinePreview(theme, selectedPolicy),
        const SizedBox(height: 12),
        _buildExplanatoryText(theme, selectedPolicy),
      ],
    );
  }

  Widget _buildTimelinePreview(ThemeData theme, MissedPolicy policy) {
    // 5-day layout: Monday, Tuesday, Wednesday (Today), Thursday, Friday
    // Let's assume user missed Mon and Tue. Today is Wed.
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final List<_TimelineDayState> states;

    switch (policy) {
      case MissedPolicy.preferNewer:
        states = [
          _TimelineDayState.skipped,
          _TimelineDayState.skipped,
          _TimelineDayState.active,
          _TimelineDayState.future,
          _TimelineDayState.future,
        ];
        break;
      case MissedPolicy.preferOlder:
        states = [
          _TimelineDayState.active, // Monday remains active
          _TimelineDayState.skipped,
          _TimelineDayState.skipped,
          _TimelineDayState.future,
          _TimelineDayState.future,
        ];
        break;
      case MissedPolicy.stack:
        states = [
          _TimelineDayState.active, // Monday active/overdue
          _TimelineDayState.active, // Tuesday active/overdue
          _TimelineDayState.active, // Wednesday active/today
          _TimelineDayState.future,
          _TimelineDayState.future,
        ];
        break;
      case MissedPolicy.autoDismiss:
        states = [
          _TimelineDayState.skipped, // Monday expired (> 24h)
          _TimelineDayState.skipped, // Tuesday expired (> 24h)
          _TimelineDayState.active, // Wednesday active/today
          _TimelineDayState.future,
          _TimelineDayState.future,
        ];
        break;
      case MissedPolicy.rollover:
      case MissedPolicy.skip:
      case MissedPolicy.shift:
        states = [];
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Simulation (Assume Mon/Tue were missed; Today is Wed)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(days.length, (idx) {
            final day = days[idx];
            final state = states[idx];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDayBadge(theme, day, state),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDayBadge(ThemeData theme, String day, _TimelineDayState state) {
    Color cardColor;
    Color textColor;
    Border? border;

    switch (state) {
      case _TimelineDayState.active:
        cardColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        border = Border.all(color: theme.colorScheme.primary, width: 1.5);
        break;
      case _TimelineDayState.skipped:
        cardColor = theme.colorScheme.surface;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
        border = Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        );
        break;
      case _TimelineDayState.future:
        cardColor = theme.colorScheme.surface;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
        border = Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          _getStatusLabel(state, textColor),
        ],
      ),
    );
  }

  Widget _getStatusLabel(_TimelineDayState state, Color color) {
    String text;
    IconData? icon;

    switch (state) {
      case _TimelineDayState.active:
        text = 'Active';
        icon = Icons.play_arrow_rounded;
        break;
      case _TimelineDayState.skipped:
        text = 'Skipped';
        icon = Icons.block_flipped;
        break;
      case _TimelineDayState.future:
        text = 'Future';
        icon = Icons.calendar_month_outlined;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 9, color: color)),
      ],
    );
  }

  Widget _buildExplanatoryText(ThemeData theme, MissedPolicy policy) {
    String text;
    switch (policy) {
      case MissedPolicy.preferNewer:
        text =
            'Keep Newer, Skip Older:\nOnly the latest occurrence stays active. Monday and Tuesday are automatically skipped so you can start fresh on Wednesday.';
        break;
      case MissedPolicy.preferOlder:
        text =
            'Keep Older, Skip Newer:\nOnly the oldest unfinished occurrence (Monday) stays active. Tuesday and Wednesday are skipped so you don\'t have a backlog to catch up on.';
        break;
      case MissedPolicy.stack:
        text =
            'Keep Both (Stack):\nAll occurrences pile up. Monday, Tuesday, and Wednesday are all active simultaneously. You must complete or dismiss them individually.';
        break;
      case MissedPolicy.autoDismiss:
        text =
            'Auto-Dismiss:\nOccurrences stack but expire after a grace period. Monday and Tuesday have automatically been skipped; only Wednesday remains active.';
        break;
      case MissedPolicy.rollover:
      case MissedPolicy.skip:
      case MissedPolicy.shift:
        text = '';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.4,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

enum _TimelineDayState { active, skipped, future }
