import 'package:flutter/material.dart';

import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/missed_occurrence_policy.dart';
import '../logic/relative_time.dart';
import 'date_stepper.dart';
import 'interval_stepper.dart';
import 'missed_occurrence_policy_section.dart';
import 'notification_config_section.dart';
import 'schedule_timing_section.dart';

String formatCivilDayIso(CivilDay day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

mixin ScheduleTimingControllersMixin<T extends StatefulWidget> on State<T> {
  late final ValueNotifier<RelativeTime> startController;
  late final ValueNotifier<RelativeTime> dueController;
  late final ValueNotifier<RelativeTime> notificationController;

  bool ignoreTimingEvents = false;

  late ValueChanged<RelativeTime> _onStartChangedCallback;
  late ValueChanged<RelativeTime> _onDueChangedCallback;
  late ValueChanged<RelativeTime?> _onNotificationChangedCallback;
  bool _notificationEnabled = false;

  void initTimingControllers({
    required RelativeTime startRelativeTime,
    required ValueChanged<RelativeTime> onStartRelativeTimeChanged,
    required RelativeTime dueRelativeTime,
    required ValueChanged<RelativeTime> onDueRelativeTimeChanged,
    required RelativeTime? notificationRelativeTime,
    required ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged,
  }) {
    _onStartChangedCallback = onStartRelativeTimeChanged;
    _onDueChangedCallback = onDueRelativeTimeChanged;
    _onNotificationChangedCallback = onNotificationRelativeTimeChanged;
    _notificationEnabled = notificationRelativeTime != null;

    startController = ValueNotifier(startRelativeTime);
    dueController = ValueNotifier(dueRelativeTime);
    notificationController = ValueNotifier(
      notificationRelativeTime ??
          const RelativeTime(dayOffset: 0, hour: 9, minute: 0),
    );

    startController.addListener(_onStartControllerChanged);
    dueController.addListener(_onDueControllerChanged);
    notificationController.addListener(_onNotificationControllerChanged);
  }

  void _onStartControllerChanged() {
    if (ignoreTimingEvents) return;
    _onStartChangedCallback(startController.value);
  }

  void _onDueControllerChanged() {
    if (ignoreTimingEvents) return;
    _onDueChangedCallback(dueController.value);
  }

  void _onNotificationControllerChanged() {
    if (ignoreTimingEvents) return;
    if (_notificationEnabled) {
      _onNotificationChangedCallback(notificationController.value);
    }
  }

  void syncTimingControllers({
    required RelativeTime startRelativeTime,
    required ValueChanged<RelativeTime> onStartRelativeTimeChanged,
    required RelativeTime dueRelativeTime,
    required ValueChanged<RelativeTime> onDueRelativeTimeChanged,
    required RelativeTime? notificationRelativeTime,
    required ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged,
    VoidCallback? onExtraSync,
  }) {
    _onStartChangedCallback = onStartRelativeTimeChanged;
    _onDueChangedCallback = onDueRelativeTimeChanged;
    _onNotificationChangedCallback = onNotificationRelativeTimeChanged;
    _notificationEnabled = notificationRelativeTime != null;

    ignoreTimingEvents = true;
    try {
      if (startController.value != startRelativeTime) {
        startController.value = startRelativeTime;
      }
      if (dueController.value != dueRelativeTime) {
        dueController.value = dueRelativeTime;
      }
      if (notificationRelativeTime != null &&
          notificationController.value != notificationRelativeTime) {
        notificationController.value = notificationRelativeTime;
      }
      onExtraSync?.call();
    } finally {
      ignoreTimingEvents = false;
    }
  }

  void disposeTimingControllers() {
    startController.removeListener(_onStartControllerChanged);
    dueController.removeListener(_onDueControllerChanged);
    notificationController.removeListener(_onNotificationControllerChanged);
    startController.dispose();
    dueController.dispose();
    notificationController.dispose();
  }
}

class ScheduleHelpRow extends StatelessWidget {
  final String text;

  const ScheduleHelpRow({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.help_outline, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class RecurringScheduleScaffold extends StatelessWidget {
  final String keyPrefix;
  final String? headerKeyPrefix;
  final int interval;
  final ValueChanged<int> onIntervalChanged;
  final String unitSingular;
  final String unitPlural;
  final CivilDay? startDate;
  final ValueChanged<CivilDay>? onStartDateChanged;
  final String helpText;
  final Widget? customSection;
  final ValueNotifier<RelativeTime> startController;
  final ValueNotifier<RelativeTime> dueController;
  final ValueNotifier<RelativeTime> notificationController;
  final bool showNotification;
  final bool notificationEnabled;
  final ValueChanged<RelativeTime?> onNotificationRelativeTimeChanged;
  final bool showMissedPolicy;
  final MissedOccurrencePolicy? missedOccurrencePolicy;
  final ValueChanged<MissedOccurrencePolicy>? onMissedOccurrencePolicyChanged;
  final bool readOnly;
  final TextEditingController? intervalController;

  const RecurringScheduleScaffold({
    super.key,
    required this.keyPrefix,
    this.headerKeyPrefix,
    required this.interval,
    required this.onIntervalChanged,
    required this.unitSingular,
    required this.unitPlural,
    this.startDate,
    this.onStartDateChanged,
    required this.helpText,
    this.customSection,
    required this.startController,
    required this.dueController,
    required this.notificationController,
    required this.showNotification,
    required this.notificationEnabled,
    required this.onNotificationRelativeTimeChanged,
    this.showMissedPolicy = false,
    this.missedOccurrencePolicy,
    this.onMissedOccurrencePolicyChanged,
    this.readOnly = false,
    this.intervalController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effectiveHeaderPrefix = headerKeyPrefix ?? keyPrefix;

    final intervalStepper = IntervalStepper(
      key: Key('${effectiveHeaderPrefix}_interval_stepper'),
      interval: interval,
      onIntervalChanged: onIntervalChanged,
      label: l10n.intervalLabel,
      unitSingular: unitSingular,
      unitPlural: unitPlural,
      readOnly: readOnly,
      intervalController: intervalController,
    );

    final Widget headerWidget;
    if (startDate != null && onStartDateChanged != null) {
      final dt = DateTime(startDate!.year, startDate!.month, startDate!.day);
      headerWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: intervalStepper),
          const SizedBox(width: 16),
          Expanded(
            child: DateStepper(
              key: Key('${effectiveHeaderPrefix}_date_stepper'),
              date: dt,
              onDateChanged: readOnly
                  ? null
                  : (picked) {
                      onStartDateChanged!(
                        CivilDay(
                          year: picked.year,
                          month: picked.month,
                          day: picked.day,
                        ),
                      );
                    },
              label: l10n.startDateLabel,
            ),
          ),
        ],
      );
    } else {
      headerWidget = intervalStepper;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerWidget,
        const SizedBox(height: 8),
        ScheduleHelpRow(text: helpText),
        const SizedBox(height: 20),
        if (customSection != null) ...[
          customSection!,
          const SizedBox(height: 20),
        ],
        ScheduleTimingSection(
          keyPrefix: keyPrefix,
          startController: startController,
          dueController: dueController,
        ),
        NotificationConfigSection(
          keyPrefix: keyPrefix,
          showNotification: showNotification,
          notificationEnabled: notificationEnabled,
          onNotificationRelativeTimeChanged: onNotificationRelativeTimeChanged,
          notificationController: notificationController,
          readOnly: readOnly,
        ),
        MissedOccurrencePolicySection(
          keyPrefix: keyPrefix,
          showMissedPolicy: showMissedPolicy,
          missedOccurrencePolicy: missedOccurrencePolicy,
          onMissedOccurrencePolicyChanged: onMissedOccurrencePolicyChanged,
        ),
      ],
    );
  }
}
