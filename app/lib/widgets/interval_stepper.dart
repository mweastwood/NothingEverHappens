import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntervalStepper extends StatefulWidget {
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final String label;
  final String? helperText;
  final bool readOnly;
  final TextEditingController? intervalController;

  const IntervalStepper({
    super.key,
    required this.interval,
    required this.onIntervalChanged,
    required this.label,
    this.helperText,
    this.readOnly = false,
    this.intervalController,
  });

  @override
  State<IntervalStepper> createState() => _IntervalStepperState();
}

class _IntervalStepperState extends State<IntervalStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final initialText = widget.interval == 1
        ? '1 day'
        : '${widget.interval} days';
    _controller =
        widget.intervalController ?? TextEditingController(text: initialText);

    if (widget.intervalController == null) {
      _controller.text = initialText;
    } else {
      if (_controller.text != initialText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != initialText) {
            _controller.text = initialText;
          }
        });
      }
    }

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Show only digits while editing
      final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
      _controller.text = digits;
    } else {
      // Format display when focus lost
      final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
      final parsed = int.tryParse(digits) ?? widget.interval;
      _controller.text = parsed == 1 ? '1 day' : '$parsed days';
    }
  }

  @override
  void didUpdateWidget(IntervalStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      final expectedText = _focusNode.hasFocus
          ? widget.interval.toString()
          : (widget.interval == 1 ? '1 day' : '${widget.interval} days');
      if (_controller.text != expectedText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.text != expectedText) {
            _controller.text = expectedText;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.intervalController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  key: const Key('interval_decrement_button'),
                  icon: const Icon(Icons.remove),
                  onPressed: widget.readOnly || widget.interval <= 1
                      ? null
                      : () {
                          final newVal = widget.interval - 1;
                          _controller.text = _focusNode.hasFocus
                              ? newVal.toString()
                              : (newVal == 1 ? '1 day' : '$newVal days');
                          widget.onIntervalChanged(newVal);
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
                        TextFormField(
                          key: const Key('interval_text_field'),
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
                              return 'Interval is required';
                            }
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            final parsed = int.tryParse(digits);
                            if (parsed == null || parsed <= 0) {
                              return 'Please enter a positive number';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            final parsed = int.tryParse(digits);
                            if (parsed != null && parsed > 0) {
                              widget.onIntervalChanged(parsed);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('interval_increment_button'),
                  icon: const Icon(Icons.add),
                  onPressed: widget.readOnly
                      ? null
                      : () {
                          final newVal = widget.interval + 1;
                          _controller.text = _focusNode.hasFocus
                              ? newVal.toString()
                              : (newVal == 1 ? '1 day' : '$newVal days');
                          widget.onIntervalChanged(newVal);
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
