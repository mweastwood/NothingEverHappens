import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/scheduling_policy.dart';
import '../logic/l10n_extension.dart';

class CompletionRelativeConfigWidget extends StatefulWidget {
  final CompletionRelativePolicy policy;
  final ValueChanged<CompletionRelativePolicy> onChanged;
  final bool readOnly;

  const CompletionRelativeConfigWidget({
    super.key,
    required this.policy,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<CompletionRelativeConfigWidget> createState() =>
      _CompletionRelativeConfigWidgetState();
}

class _CompletionRelativeConfigWidgetState
    extends State<CompletionRelativeConfigWidget> {
  late TextEditingController _numberController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final (value, unit) = _getDurationValueAndUnit(widget.policy.interval);
    _numberController = TextEditingController(text: value.toString());
    _unit = unit;
  }

  @override
  void didUpdateWidget(CompletionRelativeConfigWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy.interval != widget.policy.interval) {
      final (value, unit) = _getDurationValueAndUnit(widget.policy.interval);
      if (_numberController.text != value.toString()) {
        _numberController.text = value.toString();
      }
      _unit = unit;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  (int, String) _getDurationValueAndUnit(Duration duration) {
    if (duration.inMinutes == 0) return (0, 'days');
    if (duration.inMinutes % (7 * 24 * 60) == 0) {
      return (duration.inDays ~/ 7, 'weeks');
    }
    if (duration.inMinutes % (24 * 60) == 0) {
      return (duration.inDays, 'days');
    }
    return (duration.inHours, 'hours');
  }

  Duration _getDurationFromValueAndUnit(int value, String unit) {
    switch (unit) {
      case 'hours':
        return Duration(hours: value);
      case 'weeks':
        return Duration(days: value * 7);
      case 'days':
      default:
        return Duration(days: value);
    }
  }

  void _triggerChange({int? value, String? unit, TimeOfDay? targetTime}) {
    final parsedVal = value ?? int.tryParse(_numberController.text) ?? 1;
    final currentUnit = unit ?? _unit;
    final newDuration = _getDurationFromValueAndUnit(parsedVal, currentUnit);
    final newTime = targetTime ?? widget.policy.targetTime;

    widget.onChanged(
      CompletionRelativePolicy(interval: newDuration, targetTime: newTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !widget.readOnly,
                decoration: InputDecoration(
                  labelText: context.l10n.repeatIntervalLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final intVal = int.tryParse(val) ?? 1;
                  _triggerChange(value: intVal);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.unitLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'hours',
                    child: Text(context.l10n.unitHours),
                  ),
                  DropdownMenuItem(
                    value: 'days',
                    child: Text(context.l10n.unitDays),
                  ),
                  DropdownMenuItem(
                    value: 'weeks',
                    child: Text(context.l10n.unitWeeks),
                  ),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _unit = val;
                          });
                          _triggerChange(unit: val);
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.targetStartTimeLabel),
          subtitle: Text(widget.policy.targetTime.format(context)),
          trailing: const Icon(Icons.access_time),
          onTap: widget.readOnly
              ? null
              : () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: widget.policy.targetTime,
                  );
                  if (time != null) {
                    _triggerChange(targetTime: time);
                  }
                },
        ),
      ],
    );
  }
}
