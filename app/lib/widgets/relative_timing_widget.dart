import 'package:flutter/material.dart';
import '../logic/relative_time.dart';
import 'relative_time_widget.dart';

class RelativeTimingWidget extends StatefulWidget {
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime> onStartChanged;
  final ValueChanged<RelativeTime> onDueChanged;
  final ValueChanged<RelativeTime?> onNotificationChanged;
  final bool showNotification;

  const RelativeTimingWidget({
    super.key,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.notificationRelativeTime,
    required this.onStartChanged,
    required this.onDueChanged,
    required this.onNotificationChanged,
    this.showNotification = true,
  });

  @override
  State<RelativeTimingWidget> createState() => _RelativeTimingWidgetState();
}

class _RelativeTimingWidgetState extends State<RelativeTimingWidget> {
  late final ValueNotifier<RelativeTime> _startController = ValueNotifier(
    widget.startRelativeTime,
  );
  late final ValueNotifier<RelativeTime> _dueController = ValueNotifier(
    widget.dueRelativeTime,
  );
  late final ValueNotifier<RelativeTime> _notificationController =
      ValueNotifier(
        widget.notificationRelativeTime ??
            const RelativeTime(
              dayOffset: 0,
              time: TimeOfDay(hour: 9, minute: 0),
            ),
      );

  bool _ignoreEvents = false;

  @override
  void initState() {
    super.initState();
    _startController.addListener(_onStartChanged);
    _dueController.addListener(_onDueChanged);
    _notificationController.addListener(_onNotificationChanged);
  }

  void _onStartChanged() {
    if (_ignoreEvents) return;
    widget.onStartChanged(_startController.value);
  }

  void _onDueChanged() {
    if (_ignoreEvents) return;
    widget.onDueChanged(_dueController.value);
  }

  void _onNotificationChanged() {
    if (_ignoreEvents) return;
    if (widget.notificationRelativeTime != null) {
      widget.onNotificationChanged(_notificationController.value);
    }
  }

  @override
  void didUpdateWidget(RelativeTimingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ignoreEvents = true;
    try {
      if (_startController.value != widget.startRelativeTime) {
        _startController.value = widget.startRelativeTime;
      }
      if (_dueController.value != widget.dueRelativeTime) {
        _dueController.value = widget.dueRelativeTime;
      }
      if (widget.notificationRelativeTime != null &&
          _notificationController.value != widget.notificationRelativeTime) {
        _notificationController.value = widget.notificationRelativeTime!;
      }
    } finally {
      _ignoreEvents = false;
    }
  }

  @override
  void dispose() {
    _startController.removeListener(_onStartChanged);
    _dueController.removeListener(_onDueChanged);
    _notificationController.removeListener(_onNotificationChanged);
    _startController.dispose();
    _dueController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationEnabled = widget.notificationRelativeTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start window',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('start_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _startController,
        ),
        const SizedBox(height: 16),
        Text(
          'Due window',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RelativeTimeWidget(
          key: const Key('due_relative_time_picker'),
          constraint: RelativeTimeConstraint.unconstrained,
          controller: _dueController,
        ),
        if (widget.showNotification) ...[
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            title: Text(
              'Enable notification reminder',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            value: notificationEnabled,
            onChanged: (enabled) {
              if (enabled == true) {
                widget.onNotificationChanged(_notificationController.value);
              } else {
                widget.onNotificationChanged(null);
              }
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (notificationEnabled) ...[
            Text(
              'Notification window',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RelativeTimeWidget(
              key: const Key('notification_relative_time_picker'),
              constraint: RelativeTimeConstraint.unconstrained,
              controller: _notificationController,
            ),
          ],
        ],
      ],
    );
  }
}
