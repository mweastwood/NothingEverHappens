import 'package:flutter/material.dart';
import '../logic/l10n_extension.dart';
import '../logic/relative_time.dart';
import 'interval_stepper.dart';
import 'notification_config_section.dart';
import 'schedule_timing_section.dart';

class CompletionRelativeSchedulingWidget extends StatefulWidget {
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final String unitSingular;
  final String unitPlural;
  final String helpText;
  final String keyPrefix;
  final RelativeTime startRelativeTime;
  final ValueChanged<RelativeTime> onStartRelativeTimeChanged;
  final RelativeTime dueRelativeTime;
  final ValueChanged<RelativeTime> onDueRelativeTimeChanged;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;
  final bool showNotification;
  final bool readOnly;
  final TextEditingController? intervalController;

  const CompletionRelativeSchedulingWidget({
    super.key,
    required this.interval,
    required this.onIntervalChanged,
    required this.unitSingular,
    required this.unitPlural,
    required this.helpText,
    required this.keyPrefix,
    required this.startRelativeTime,
    required this.onStartRelativeTimeChanged,
    required this.dueRelativeTime,
    required this.onDueRelativeTimeChanged,
    required this.notificationRelativeTime,
    required this.onNotificationRelativeTimeChanged,
    this.showNotification = true,
    this.readOnly = false,
    this.intervalController,
  });

  @override
  State<CompletionRelativeSchedulingWidget> createState() =>
      _CompletionRelativeSchedulingWidgetState();
}

class _CompletionRelativeSchedulingWidgetState
    extends State<CompletionRelativeSchedulingWidget> {
  late final ValueNotifier<RelativeTime> _startController;
  late final ValueNotifier<RelativeTime> _dueController;
  late final ValueNotifier<RelativeTime> _notificationController;

  bool _ignoreEvents = false;

  @override
  void initState() {
    super.initState();
    _startController = ValueNotifier(widget.startRelativeTime);
    _dueController = ValueNotifier(widget.dueRelativeTime);
    _notificationController = ValueNotifier(
      widget.notificationRelativeTime ??
          const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    );

    _startController.addListener(_onStartChanged);
    _dueController.addListener(_onDueChanged);
    _notificationController.addListener(_onNotificationChanged);
  }

  void _onStartChanged() {
    if (_ignoreEvents) return;
    widget.onStartRelativeTimeChanged(_startController.value);
  }

  void _onDueChanged() {
    if (_ignoreEvents) return;
    widget.onDueRelativeTimeChanged(_dueController.value);
  }

  void _onNotificationChanged() {
    if (_ignoreEvents) return;
    if (widget.notificationRelativeTime != null) {
      widget.onNotificationRelativeTimeChanged(_notificationController.value);
    }
  }

  @override
  void didUpdateWidget(CompletionRelativeSchedulingWidget oldWidget) {
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
    final l10n = context.l10n;
    final notificationEnabled = widget.notificationRelativeTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntervalStepper(
          key: Key('${widget.keyPrefix}_interval_stepper'),
          interval: widget.interval,
          onIntervalChanged: widget.onIntervalChanged,
          label: l10n.intervalLabel,
          unitSingular: widget.unitSingular,
          unitPlural: widget.unitPlural,
          readOnly: widget.readOnly,
          intervalController: widget.intervalController,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.helpText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ScheduleTimingSection(
          startController: _startController,
          dueController: _dueController,
          keyPrefix: widget.keyPrefix,
        ),
        NotificationConfigSection(
          showNotification: widget.showNotification,
          notificationEnabled: notificationEnabled,
          readOnly: widget.readOnly,
          notificationController: _notificationController,
          onNotificationRelativeTimeChanged:
              widget.onNotificationRelativeTimeChanged,
          keyPrefix: widget.keyPrefix,
        ),
      ],
    );
  }
}
