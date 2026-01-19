import 'package:flutter/material.dart';

/// Constraints for the relative time widget.
enum RelativeTimeConstraint {
  /// The time must be on or after the reference day (offset >= 0).
  forward,

  /// The time must be on or before the reference day (offset <= 0).
  backward,
}

class RelativeTimeWidget extends StatefulWidget {
  final Duration value;
  final ValueChanged<Duration> onChanged;
  final RelativeTimeConstraint constraint;

  const RelativeTimeWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.constraint = RelativeTimeConstraint.forward,
  });

  @override
  State<RelativeTimeWidget> createState() => _RelativeTimeWidgetState();
}

class _RelativeTimeWidgetState extends State<RelativeTimeWidget> {
  late TimeOfDay _timeOfDay;
  late int _dayOffset;
  final _daysController = TextEditingController();
  static const int _customOption = -999;

  @override
  void initState() {
    super.initState();
    _parseValue();
  }

  @override
  void didUpdateWidget(covariant RelativeTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _parseValue();
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _parseValue() {
    // A negative duration means we are BEFORE the reference event, so offset is negative.
    // However, when simply extracting time from duration, we need to be careful with negative values.
    // simpler approach: Total minutes.

    final totalMinutes = widget.value.inMinutes;

    // Days part
    // If totalMinutes is negative, floor() moves further away from 0.
    // e.g. -100 mins -> -1 day (remainder -100 - (-1440) = 1340 mins? wait.)

    // Let's standardise:
    // midnight + Duration = Target Time
    // Day offset = floor(Duration / 24h).
    // Time = Duration - (Day offset * 24h).

    _dayOffset = (totalMinutes / 1440).floor();
    final remainingMinutes = totalMinutes - (_dayOffset * 1440);

    // If remainingMinutes can be negative?
    // If -25 hours = -1500 mins.
    // -1500 / 1440 = -1.04 -> floor is -2.
    // -1500 - (-2 * 1440) = -1500 + 2880 = 1380. (23:00)
    // This implies "2 days before, at 23:00".
    // This handles the math correctly for "offset from midnight of ref day".

    _timeOfDay = TimeOfDay(
      hour: remainingMinutes ~/ 60,
      minute: remainingMinutes % 60,
    );

    // Update text controller if custom is potentially active
    if (_segmentValue == _customOption) {
      final absDays = _dayOffset.abs();
      if (_daysController.text != absDays.toString()) {
        _daysController.text = absDays.toString();
      }
    }
  }

  int get _segmentValue {
    if (_dayOffset == 0) {
      return 0;
    }
    // "1 day after/before" check
    if (widget.constraint == RelativeTimeConstraint.forward) {
      if (_dayOffset == 1) return 1;
    } else {
      if (_dayOffset == -1)
        return 1; // "1 day before" uses the '1' slot in UI logic effectively
    }
    return _customOption;
  }

  void _updateValue({TimeOfDay? time, int? days}) {
    final t = time ?? _timeOfDay;
    final d = days ?? _dayOffset;

    final newDuration = Duration(days: d, hours: t.hour, minutes: t.minute);
    widget.onChanged(newDuration);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay,
    );
    if (picked != null) {
      _updateValue(time: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForward = widget.constraint == RelativeTimeConstraint.forward;
    final oneDayLabel = isForward ? '1 day after' : '1 day before';
    final isCustom = _segmentValue == _customOption;

    // Use a fixed height to avoid layout jumps when switching modes.
    const double commonHeight = 40.0;
    // Estimated width to accommodate segments comfortably.
    const double commonWidth = 320.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time Button
        FilledButton.tonalIcon(
          onPressed: _pickTime,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            // Ensure height matches commonHeight implicitly or via fixed size
            fixedSize: const Size.fromHeight(commonHeight),
          ),
          icon: const Icon(Icons.access_time, size: 18),
          label: Text(
            _timeOfDay.format(context),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        // Right side: Offset Selector
        SizedBox(
          height: commonHeight,
          width: commonWidth,
          child: isCustom
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: TextField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
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
                                _updateValue(days: signedDays);
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
                      // Match height and provide touch target
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _updateValue(days: 0);
                      },
                      tooltip: 'Reset to Day of',
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SegmentedButton<int>(
                      segments: [
                        const ButtonSegment(value: 0, label: Text('Day of')),
                        ButtonSegment(value: 1, label: Text(oneDayLabel)),
                        const ButtonSegment(
                          value: _customOption,
                          label: Text('Custom'),
                        ),
                      ],
                      selected: {_segmentValue},
                      onSelectionChanged: (Set<int> newSelection) {
                        final val = newSelection.first;
                        if (val == 0) {
                          _updateValue(days: 0);
                        } else if (val == 1) {
                          _updateValue(days: isForward ? 1 : -1);
                        } else {
                          int defaultCustom = isForward ? 2 : -2;
                          if (_segmentValue != _customOption) {
                            _updateValue(days: defaultCustom);
                            _daysController.text = defaultCustom
                                .abs()
                                .toString();
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
                ),
        ),
      ],
    );
  }
}
