import 'package:flutter/material.dart';
import '../logic/relative_time.dart';
import '../logic/l10n_extension.dart';

/// Constraints for the relative time widget.
enum RelativeTimeConstraint {
  /// The time must be on or after the reference day (offset >= 0).
  dayOfOrAfter,

  /// The time must be on or before the reference day (offset <= 0).
  dayOfOrBefore,

  /// No constraint on the day offset.
  unconstrained,
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

class _RelativeTimeWidgetState extends State<RelativeTimeWidget> {
  /// Stores the time of day component of the relative time.
  late final ValueNotifier<TimeOfDay> _timeNotifier = ValueNotifier(
    _currentRelativeTime.time,
  );

  /// Stores the day offset component of the relative time.
  late final ValueNotifier<int> _daysNotifier = ValueNotifier(
    _currentRelativeTime.dayOffset,
  );

  final _textController = TextEditingController();

  RelativeTime get _currentRelativeTime => widget.controller.value;

  bool _isUpdatingFromExternal = false;

  @override
  void initState() {
    super.initState();
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
        case RelativeTimeConstraint.unconstrained:
          break;
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeNotifier.value,
    );
    if (picked != null) {
      _internalUpdateTime(picked);
    }
  }

  String _getOffsetDisplayString(int days, bool isForward) {
    if (days == 0) {
      return context.l10n.dayOfLabel;
    }
    final absDays = days.abs();
    final positive = widget.constraint == RelativeTimeConstraint.unconstrained
        ? days >= 0
        : isForward;
    if (absDays == 1) {
      return positive
          ? context.l10n.oneDayAfterLabel
          : context.l10n.oneDayBeforeLabel;
    }
    return positive
        ? context.l10n.nDaysLaterLabel(absDays)
        : context.l10n.nDaysBeforeLabel(absDays);
  }

  Future<void> _showOffsetDialog(BuildContext context, bool isForward) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return _DayOffsetPickerDialog(
          initialOffset: _daysNotifier.value,
          isForward: isForward,
          constraint: widget.constraint,
        );
      },
    );

    if (result != null) {
      _internalUpdateDays(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForward = widget.constraint == RelativeTimeConstraint.unconstrained
        ? _daysNotifier.value >= 0
        : widget.constraint == RelativeTimeConstraint.dayOfOrAfter;

    return Row(
      children: [
        // Time Card
        Expanded(
          child: ValueListenableBuilder<TimeOfDay>(
            valueListenable: _timeNotifier,
            builder: (context, time, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.timeLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  time.format(context),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.access_time,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Day Card (previously Offset Card)
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _daysNotifier,
            builder: (context, days, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Builder(
                    builder: (context) {
                      return InkWell(
                        onTap: () => _showOffsetDialog(context, isForward),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      context.l10n.dayLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            height: 1.1,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getOffsetDisplayString(days, isForward),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _DayOffsetPickerDialog extends StatefulWidget {
  final int initialOffset;
  final bool isForward;
  final RelativeTimeConstraint constraint;

  const _DayOffsetPickerDialog({
    required this.initialOffset,
    required this.isForward,
    required this.constraint,
  });

  @override
  State<_DayOffsetPickerDialog> createState() => _DayOffsetPickerDialogState();
}

class _DayOffsetPickerDialogState extends State<_DayOffsetPickerDialog> {
  late int _currentOffset;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.initialOffset;
  }

  String _getOffsetLabel(int offset) {
    if (offset == 0) return context.l10n.dayOfLabel;
    final absOffset = offset.abs();
    final isPositive = offset > 0;
    if (absOffset == 1) {
      return isPositive
          ? context.l10n.oneDayAfterLabel
          : context.l10n.oneDayBeforeLabel;
    }
    return isPositive
        ? context.l10n.nDaysLaterLabel(absOffset)
        : context.l10n.nDaysBeforeLabel(absOffset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDecrementDisabled =
        (widget.constraint == RelativeTimeConstraint.dayOfOrAfter &&
        _currentOffset <= 0);
    final isIncrementDisabled =
        (widget.constraint == RelativeTimeConstraint.dayOfOrBefore &&
        _currentOffset >= 0);

    final presets = <int>[];
    switch (widget.constraint) {
      case RelativeTimeConstraint.dayOfOrAfter:
        presets.addAll([0, 1, 2, 7]);
      case RelativeTimeConstraint.dayOfOrBefore:
        presets.addAll([-7, -2, -1, 0]);
      case RelativeTimeConstraint.unconstrained:
        presets.addAll([-7, -2, -1, 0, 1, 2, 7]);
    }

    return AlertDialog(
      title: Text(context.l10n.selectDayTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.presetsLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: presets.map((offset) {
                final isSelected = _currentOffset == offset;
                return ChoiceChip(
                  key: Key('preset_chip_$offset'),
                  label: Text(_getOffsetLabel(offset)),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: const TextStyle(fontWeight: FontWeight.normal),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentOffset = offset;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              context.l10n.adjustOffsetLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const Key('stepper_decrement_button'),
                  icon: const Icon(Icons.remove),
                  onPressed: isDecrementDisabled
                      ? null
                      : () {
                          setState(() {
                            _currentOffset--;
                          });
                        },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getOffsetLabel(_currentOffset),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  key: const Key('stepper_increment_button'),
                  icon: const Icon(Icons.add),
                  onPressed: isIncrementDisabled
                      ? null
                      : () {
                          setState(() {
                            _currentOffset++;
                          });
                        },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_currentOffset),
          child: Text(context.l10n.okButton),
        ),
      ],
    );
  }
}
