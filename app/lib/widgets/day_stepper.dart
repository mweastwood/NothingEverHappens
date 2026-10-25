import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared numeric day stepper widget used by monthly and yearly fixed scheduling widgets.
class DayStepper extends StatefulWidget {
  final int day;
  final int maxDays;
  final ValueChanged<int> onDayChanged;
  final String label;
  final bool readOnly;
  final TextEditingController? controller;
  final Key textFieldKey;
  final String rangeErrorText;
  final String Function(int day)? suffixBuilder;

  const DayStepper({
    super.key,
    required this.day,
    required this.maxDays,
    required this.onDayChanged,
    required this.label,
    required this.textFieldKey,
    required this.rangeErrorText,
    this.readOnly = false,
    this.controller,
    this.suffixBuilder,
  });

  @override
  State<DayStepper> createState() => _DayStepperState();
}

class _DayStepperState extends State<DayStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  double _getFieldWidth() {
    final textLength = _controller.text.isEmpty ? 1 : _controller.text.length;
    return textLength * 11.0;
  }

  @override
  void initState() {
    super.initState();
    final initialText = widget.day.toString();
    _controller = widget.controller ?? TextEditingController(text: initialText);
    if (widget.controller == null) {
      _controller.text = initialText;
    } else {
      final cleanText = _controller.text.replaceAll(RegExp(r'\D'), '');
      if (_controller.text != cleanText) {
        _controller.text = cleanText;
      }
    }

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final parsed = int.tryParse(_controller.text) ?? widget.day;
      if (parsed < 1) {
        _controller.text = '1';
        widget.onDayChanged(1);
      } else if (parsed > widget.maxDays) {
        _controller.text = widget.maxDays.toString();
        widget.onDayChanged(widget.maxDays);
      } else {
        _controller.text = parsed.toString();
        if (parsed != widget.day) {
          widget.onDayChanged(parsed);
        }
      }
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(DayStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day || oldWidget.maxDays != widget.maxDays) {
      final expectedText = widget.day.toString();
      if (_controller.text != expectedText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != expectedText) {
            _controller.text = expectedText;
            setState(() {});
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = int.tryParse(_controller.text);
    final suffix = widget.suffixBuilder?.call(parsed ?? widget.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                IconButton(
                  key: const Key('day_decrement_button'),
                  icon: const Icon(Icons.remove),
                  onPressed: widget.readOnly || widget.day <= 1
                      ? null
                      : () {
                          final newVal = widget.day - 1;
                          _controller.text = newVal.toString();
                          widget.onDayChanged(newVal);
                          setState(() {});
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _getFieldWidth(),
                              child: TextFormField(
                                key: widget.textFieldKey,
                                controller: _controller,
                                focusNode: _focusNode,
                                enabled: !widget.readOnly,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final parsedVal = int.tryParse(val.trim());
                                  if (parsedVal == null ||
                                      parsedVal < 1 ||
                                      parsedVal > widget.maxDays) {
                                    return widget.rangeErrorText;
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  final parsedVal = int.tryParse(val.trim());
                                  if (parsedVal != null &&
                                      parsedVal >= 1 &&
                                      parsedVal <= widget.maxDays) {
                                    widget.onDayChanged(parsedVal);
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                            if (suffix != null)
                              Text(
                                suffix,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.2,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('day_increment_button'),
                  icon: const Icon(Icons.add),
                  onPressed: widget.readOnly || widget.day >= widget.maxDays
                      ? null
                      : () {
                          final newVal = widget.day + 1;
                          _controller.text = newVal.toString();
                          widget.onDayChanged(newVal);
                          setState(() {});
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns the English ordinal suffix ('st', 'nd', 'rd', 'th') for [val].
String getOrdinalDaySuffix(int val) {
  final absVal = val.abs();
  if (absVal >= 11 && absVal <= 13) {
    return 'th';
  }
  switch (absVal % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}
