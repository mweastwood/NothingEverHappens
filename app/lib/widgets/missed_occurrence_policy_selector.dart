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
    final (val, unit) = _getCustomValueAndUnit(
      widget.policy.gracePeriod ?? const Duration(hours: 1),
    );
    _customController = TextEditingController(text: val.toString());
    _customUnit = unit;
  }

  @override
  void didUpdateWidget(MissedOccurrencePolicySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      _preset = _getGracePreset(widget.policy.gracePeriod);
      final (val, unit) = _getCustomValueAndUnit(
        widget.policy.gracePeriod ?? const Duration(hours: 1),
      );
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

  String _getGracePreset(Duration? gracePeriod) {
    if (gracePeriod == null) return '1h';
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
    MissedOccurrenceType? type,
    String? preset,
    int? customVal,
    String? customUnit,
    MissedPolicy? legacyPolicy,
  }) {
    final currentType = type ?? widget.policy.type;
    final currentPreset = preset ?? _preset;
    final currentLegacy = legacyPolicy ?? widget.policy.legacyPolicy;

    if (currentType == MissedOccurrenceType.keepAround) {
      widget.onChanged(
        MissedOccurrencePolicy.keepAround(legacyPolicy: currentLegacy),
      );
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
    final type = widget.policy.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'If task is missed...',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MissedOccurrenceType>(
          segments: const [
            ButtonSegment<MissedOccurrenceType>(
              value: MissedOccurrenceType.keepAround,
              icon: Icon(Icons.stacked_line_chart),
              label: Text('Keep Around'),
            ),
            ButtonSegment<MissedOccurrenceType>(
              value: MissedOccurrenceType.autoDismiss,
              icon: Icon(Icons.timer_outlined),
              label: Text('Auto-Dismiss'),
            ),
          ],
          selected: {type},
          onSelectionChanged: widget.readOnly
              ? null
              : (selection) {
                  if (selection.isNotEmpty) {
                    _triggerChange(type: selection.first);
                  }
                },
        ),
        const SizedBox(height: 16),
        if (type == MissedOccurrenceType.keepAround) ...[
          DropdownButtonFormField<MissedPolicy>(
            initialValue: widget.policy.legacyPolicy,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Overdue Treatment',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: MissedPolicy.rollover,
                child: Text('Rollover (single card, original due ref)'),
              ),
              DropdownMenuItem(
                value: MissedPolicy.shift,
                child: Text('Shift (single card, completion ref)'),
              ),
              DropdownMenuItem(
                value: MissedPolicy.stack,
                child: Text('Stack (allow multiple pending cards)'),
              ),
            ],
            onChanged: widget.readOnly
                ? null
                : (val) {
                    if (val != null) {
                      _triggerChange(legacyPolicy: val);
                    }
                  },
          ),
        ] else ...[
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
      ],
    );
  }
}
