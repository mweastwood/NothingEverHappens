import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/relative_time.dart';

/// Constraints for the relative time widget.
enum RelativeTimeConstraint {
  /// The time must be on or after the reference day (offset >= 0).
  dayOfOrAfter,

  /// The time must be on or before the reference day (offset <= 0).
  dayOfOrBefore,
}

/// A widget that allows users to select a time relative to a reference day.
///
/// It combines a time picker with a day offset selector (e.g., "Day of", "1 day
/// after", or Custom).
///
/// Example:
/// ```dart
/// final controller = ValueNotifier(
///   const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
/// );
/// // Log changes
/// controller.addListener(() {
///   print('Selected relative time: ${controller.value}');
/// });
///
/// RelativeTimeWidget(
///   controller: controller, // 09:00 AM on the day of.
///   constraint: RelativeTimeConstraint.dayOfOrAfter,
/// )
/// ```
class RelativeTimeWidget extends StatefulWidget {
  final RelativeTimeConstraint constraint;
  final ValueNotifier<RelativeTime> controller;

  const RelativeTimeWidget({
    super.key,
    required this.constraint,
    required this.controller,
  });

  @override
  State<RelativeTimeWidget> createState() => _RelativeTimeWidgetState();
}

/// Options for the relative time selector.
enum _RelativeTimeOption { dayOf, dayAfter, dayBefore, custom }

class _RelativeTimeWidgetState extends State<RelativeTimeWidget> {
  /// Stores the time of day component of the relative time.
  late final ValueNotifier<TimeOfDay> _timeNotifier;

  /// Stores the day offset component of the relative time.
  late final ValueNotifier<int> _daysNotifier;

  final _textController = TextEditingController();

  RelativeTime get _currentRelativeTime => widget.controller.value;

  bool _isUpdatingFromExternal = false;

  @override
  void initState() {
    super.initState();
    // Initialize notifiers with current controller value
    _timeNotifier = ValueNotifier(_currentRelativeTime.time);
    _daysNotifier = ValueNotifier(_currentRelativeTime.dayOffset);

    // Ensure text controller matches initial state
    _updateTextController(_currentRelativeTime.dayOffset);

    _onExternalUpdate();
    widget.controller.addListener(_onExternalUpdate);

    _timeNotifier.addListener(_onInternalUpdateToTime);
    _daysNotifier.addListener(_onInternalUpdateToDays);
  }

  @override
  void didUpdateWidget(covariant RelativeTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalUpdate);
      widget.controller.addListener(_onExternalUpdate);
      _onExternalUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalUpdate);
    _daysNotifier.removeListener(_onInternalUpdateToDays);
    _timeNotifier.removeListener(_onInternalUpdateToTime);
    _daysNotifier.dispose();
    _timeNotifier.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onExternalUpdate() {
    _isUpdatingFromExternal = true;
    try {
      // Check constraints
      final offset = _currentRelativeTime.dayOffset;
      switch (widget.constraint) {
        case RelativeTimeConstraint.dayOfOrAfter:
          assert(
            offset >= 0,
            'Given value ($_currentRelativeTime) does not represent a time on or after the reference day.',
          );
        case RelativeTimeConstraint.dayOfOrBefore:
          assert(
            offset <= 0,
            'Given value ($_currentRelativeTime) does not represent a time on or before the reference day.',
          );
      }

      // Sync internal state if different
      if (_daysNotifier.value != offset) {
        _daysNotifier.value = offset;
        _updateTextController(offset);
      }
      if (_timeNotifier.value != _currentRelativeTime.time) {
        _timeNotifier.value = _currentRelativeTime.time;
      }
    } finally {
      _isUpdatingFromExternal = false;
    }
  }

  void _internalUpdateTime(TimeOfDay time) {
    _timeNotifier.value = time;
  }

  void _onInternalUpdateToTime() {
    _onInternalUpdate();
  }

  void _internalUpdateDays(int days) {
    _daysNotifier.value = days;
  }

  void _onInternalUpdateToDays() {
    _updateTextController(_daysNotifier.value);
    _onInternalUpdate();
  }

  void _updateTextController(int days) {
    final absDays = days.abs();
    if (_textController.text != absDays.toString()) {
      _textController.text = absDays.toString();
    }
  }

  void _onInternalUpdate() {
    if (_isUpdatingFromExternal) return;

    final newRelativeTime = RelativeTime(
      dayOffset: _daysNotifier.value,
      time: _timeNotifier.value,
    );
    if (widget.controller.value != newRelativeTime) {
      widget.controller.value = newRelativeTime;
    }
  }

  _RelativeTimeOption _getSegment(int days) {
    switch (days) {
      case 0:
        return _RelativeTimeOption.dayOf;
      case 1:
        return _RelativeTimeOption.dayAfter;
      case -1:
        return _RelativeTimeOption.dayBefore;
      default:
        return _RelativeTimeOption.custom;
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeNotifier.value,
    );
    if (picked != null) {
      _internalUpdateTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (oneDayLabel, isForward) = switch (widget.constraint) {
      RelativeTimeConstraint.dayOfOrAfter => ('1 day after', true),
      RelativeTimeConstraint.dayOfOrBefore => ('1 day before', false),
    };

    // Use a fixed height to avoid layout jumps when switching modes.
    const double commonHeight = 40.0;
    // Estimated width to accommodate segments comfortably.
    const double commonWidth = 320.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time Button
        ValueListenableBuilder<TimeOfDay>(
          valueListenable: _timeNotifier,
          builder: (context, time, child) {
            return FilledButton.tonalIcon(
              onPressed: _pickTime,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                fixedSize: const Size.fromHeight(commonHeight),
              ),
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(
                time.format(context),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        // Right side: Offset Selector
        SizedBox(
          height: commonHeight,
          width: commonWidth,
          child: ValueListenableBuilder<int>(
            valueListenable: _daysNotifier,
            builder: (context, days, child) {
              final segment = _getSegment(days);
              final isCustom = segment == _RelativeTimeOption.custom;

              if (isCustom) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: TextField(
                            controller: _textController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            textAlign: TextAlign.center,
                            onChanged: (text) {
                              final daysAbs = int.tryParse(text);
                              if (daysAbs != null) {
                                final signedDays = isForward
                                    ? daysAbs
                                    : -daysAbs;
                                _internalUpdateDays(signedDays);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isForward ? 'days later' : 'days before',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _internalUpdateDays(0);
                      },
                      tooltip: 'Reset to Day of',
                    ),
                  ],
                );
              } else {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SegmentedButton<_RelativeTimeOption>(
                      segments: [
                        const ButtonSegment(
                          value: _RelativeTimeOption.dayOf,
                          label: Text('Day of'),
                        ),
                        ButtonSegment(
                          value: isForward
                              ? _RelativeTimeOption.dayAfter
                              : _RelativeTimeOption.dayBefore,
                          label: Text(oneDayLabel),
                        ),
                        const ButtonSegment(
                          value: _RelativeTimeOption.custom,
                          label: Text('Custom'),
                        ),
                      ],
                      selected: {segment},
                      onSelectionChanged:
                          (Set<_RelativeTimeOption> newSelection) {
                            final val = newSelection.first;
                            switch (val) {
                              case _RelativeTimeOption.dayOf:
                                _internalUpdateDays(0);
                              case _RelativeTimeOption.dayAfter:
                                _internalUpdateDays(1);
                              case _RelativeTimeOption.dayBefore:
                                _internalUpdateDays(-1);
                              case _RelativeTimeOption.custom:
                                int defaultCustom = isForward ? 2 : -2;
                                if (segment != _RelativeTimeOption.custom) {
                                  _internalUpdateDays(defaultCustom);
                                  // Controller sync happens via listener
                                }
                            }
                          },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        fixedSize: WidgetStateProperty.all(
                          Size.fromHeight(constraints.maxHeight),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
