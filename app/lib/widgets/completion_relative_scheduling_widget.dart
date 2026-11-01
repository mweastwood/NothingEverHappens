import 'package:flutter/material.dart';

import '../logic/relative_time.dart';
import 'recurring_schedule_scaffold.dart';

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
    extends State<CompletionRelativeSchedulingWidget>
    with ScheduleTimingControllersMixin {
  @override
  void initState() {
    super.initState();
    initTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
    );
  }

  @override
  void didUpdateWidget(CompletionRelativeSchedulingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimingControllers(
      startRelativeTime: widget.startRelativeTime,
      onStartRelativeTimeChanged: widget.onStartRelativeTimeChanged,
      dueRelativeTime: widget.dueRelativeTime,
      onDueRelativeTimeChanged: widget.onDueRelativeTimeChanged,
      notificationRelativeTime: widget.notificationRelativeTime,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
    );
  }

  @override
  void dispose() {
    disposeTimingControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RecurringScheduleScaffold(
      keyPrefix: widget.keyPrefix,
      interval: widget.interval,
      onIntervalChanged: widget.onIntervalChanged,
      unitSingular: widget.unitSingular,
      unitPlural: widget.unitPlural,
      helpText: widget.helpText,
      startController: startController,
      dueController: dueController,
      notificationController: notificationController,
      showNotification: widget.showNotification,
      notificationEnabled: widget.notificationRelativeTime != null,
      onNotificationRelativeTimeChanged:
          widget.onNotificationRelativeTimeChanged,
      readOnly: widget.readOnly,
      intervalController: widget.intervalController,
    );
  }
}
