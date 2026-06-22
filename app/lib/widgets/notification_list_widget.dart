import 'package:flutter/material.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import 'relative_time_widget.dart';
import 'absolute_time_widget.dart';

/// A widget that displays and manages a list of multiple task notifications.
///
/// It supports two modes:
/// 1. Relative mode (when [referenceDate] is null): Configures notifications
///    using relative offsets (e.g. "Day of at 9:00 AM", "1 day before").
/// 2. Absolute mode (when [referenceDate] is non-null): Configures notifications
///    using absolute dates/times (e.g. specific calendar days and times),
///    but automatically converts them under-the-hood to relative times relative
///    to the [referenceDate].
class NotificationListWidget extends StatefulWidget {
  final List<RelativeTime> notifications;
  final ValueChanged<List<RelativeTime>> onChanged;
  final CivilDay? referenceDate;
  final bool readOnly;

  const NotificationListWidget({
    super.key,
    required this.notifications,
    required this.onChanged,
    this.referenceDate,
    this.readOnly = false,
  });

  @override
  State<NotificationListWidget> createState() => _NotificationListWidgetState();
}

class _NotificationListWidgetState extends State<NotificationListWidget> {
  static const int _maxNotifications = 5;

  void _addNotification() {
    if (widget.notifications.length >= _maxNotifications) return;
    final updated = List<RelativeTime>.from(widget.notifications);
    // Default to 'Day of' (offset 0) at 9:00 AM
    updated.add(
      const RelativeTime(dayOffset: 0, time: TimeOfDay(hour: 9, minute: 0)),
    );
    widget.onChanged(updated);
  }

  void _updateNotification(int index, RelativeTime time) {
    final updated = List<RelativeTime>.from(widget.notifications);
    updated[index] = time;
    widget.onChanged(updated);
  }

  void _removeNotification(int index) {
    final updated = List<RelativeTime>.from(widget.notifications);
    updated.removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = widget.notifications.length < _maxNotifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notification Reminders',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!widget.readOnly)
              Text(
                '${widget.notifications.length} / $_maxNotifications',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.notifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No notifications set',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                for (int i = 0; i < widget.notifications.length; i++)
                  _NotificationItemWidget(
                    key: ValueKey(
                      'notif_item_${i}_${widget.notifications[i].hashCode}',
                    ),
                    relativeTime: widget.notifications[i],
                    referenceDate: widget.referenceDate,
                    readOnly: widget.readOnly,
                    onChanged: (newVal) => _updateNotification(i, newVal),
                    onDelete: () => _removeNotification(i),
                  ),
              ],
            ),
          ),
        if (!widget.readOnly && canAdd) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('add_notification_button'),
            icon: const Icon(Icons.add_alarm, size: 18),
            label: const Text('Add notification'),
            onPressed: _addNotification,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationItemWidget extends StatefulWidget {
  final RelativeTime relativeTime;
  final CivilDay? referenceDate;
  final ValueChanged<RelativeTime> onChanged;
  final VoidCallback onDelete;
  final bool readOnly;

  const _NotificationItemWidget({
    super.key,
    required this.relativeTime,
    required this.referenceDate,
    required this.onChanged,
    required this.onDelete,
    this.readOnly = false,
  });

  @override
  State<_NotificationItemWidget> createState() =>
      _NotificationItemWidgetState();
}

class _NotificationItemWidgetState extends State<_NotificationItemWidget> {
  late ValueNotifier<DateTime> _absoluteController;
  late ValueNotifier<RelativeTime> _relativeController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    if (widget.referenceDate != null) {
      final absTime = widget.relativeTime.referenceTo(widget.referenceDate!);
      _absoluteController = ValueNotifier(absTime);
      _absoluteController.addListener(_onAbsoluteChanged);
    } else {
      _relativeController = ValueNotifier(widget.relativeTime);
      _relativeController.addListener(_onRelativeChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _NotificationItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativeTime != widget.relativeTime ||
        oldWidget.referenceDate != widget.referenceDate) {
      _isUpdating = true;
      if (widget.referenceDate != null) {
        final absTime = widget.relativeTime.referenceTo(widget.referenceDate!);
        _absoluteController.value = absTime;
      } else {
        _relativeController.value = widget.relativeTime;
      }
      _isUpdating = false;
    }
  }

  void _onAbsoluteChanged() {
    if (_isUpdating) return;
    final dt = _absoluteController.value;
    final refDate = widget.referenceDate!;
    final refUtc = DateTime.utc(refDate.year, refDate.month, refDate.day);
    final targetUtc = DateTime.utc(dt.year, dt.month, dt.day);
    final dayOffset = targetUtc.difference(refUtc).inDays;
    final relative = RelativeTime(
      dayOffset: dayOffset,
      time: TimeOfDay(hour: dt.hour, minute: dt.minute),
    );
    widget.onChanged(relative);
  }

  void _onRelativeChanged() {
    if (_isUpdating) return;
    widget.onChanged(_relativeController.value);
  }

  @override
  void dispose() {
    if (widget.referenceDate != null) {
      _absoluteController.removeListener(_onAbsoluteChanged);
      _absoluteController.dispose();
    } else {
      _relativeController.removeListener(_onRelativeChanged);
      _relativeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: widget.referenceDate != null
                ? AbsoluteTimeWidget(controller: _absoluteController)
                : RelativeTimeWidget(
                    constraint: RelativeTimeConstraint.unconstrained,
                    controller: _relativeController,
                  ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: widget.onDelete,
              tooltip: 'Remove Notification',
            ),
          ],
        ],
      ),
    );
  }
}
