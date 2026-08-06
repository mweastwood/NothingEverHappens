import re

with open('app/lib/widgets/schedule_rule_config_widget.dart', 'r') as f:
    content = f.read()

# Add the Map at the top of the file, just below imports
imports_end = content.rfind("import")
imports_end = content.find("\n", imports_end) + 1

builders_code = """
typedef ScheduleWidgetBuilder = Widget Function(
  BuildContext context,
  _ScheduleRuleConfigWidgetState state,
  TaskScheduleRule s,
);

final Map<Type, ScheduleWidgetBuilder> _configBuilders = {
  DailySchedule: (context, state, s) {
    final rule = s as DailySchedule;
    return DailySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) {
        state.widget.onChanged(rule.copyWithStartDate(date));
      },
      interval: rule.interval,
      onIntervalChanged: (val) {
        var policy = rule.schedulingPolicy;
        if (policy is CompletionRelativePolicy) {
          policy = CompletionRelativePolicy(
            interval: Duration(days: val),
            targetTime: policy.targetTime,
          );
        }
        state.widget.onChanged(
          DailySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: val,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: policy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) {
        state.widget.onChanged(rule.copyWithTiming(schedulingPolicy: policy));
      },
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) {
        state.widget.onChanged(rule.copyWithTiming(startRelativeTime: start));
      },
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) {
        state.widget.onChanged(rule.copyWithTiming(dueRelativeTime: due));
      },
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) {
        state.widget.onChanged(
          rule.copyWithTiming(missedOccurrencePolicy: policy),
        );
      },
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
    );
  },
  WeeklySchedule: (context, state, s) {
    final rule = s as WeeklySchedule;
    return WeeklySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) {
        state.widget.onChanged(rule.copyWithStartDate(date));
      },
      interval: rule.interval,
      onIntervalChanged: (val) {
        var policy = rule.schedulingPolicy;
        if (policy is CompletionRelativePolicy) {
          policy = CompletionRelativePolicy(
            interval: Duration(days: val * 7),
            targetTime: policy.targetTime,
          );
        }
        state.widget.onChanged(
          WeeklySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: val,
            daysOfWeek: rule.daysOfWeek,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: policy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) {
        state.widget.onChanged(rule.copyWithTiming(schedulingPolicy: policy));
      },
      selectedWeekdays: rule.daysOfWeek,
      onWeekdaysChanged: (days) {
        state.widget.onChanged(
          WeeklySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            daysOfWeek: days,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) {
        state.widget.onChanged(rule.copyWithTiming(startRelativeTime: start));
      },
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) {
        state.widget.onChanged(rule.copyWithTiming(dueRelativeTime: due));
      },
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) {
        state.widget.onChanged(
          rule.copyWithTiming(missedOccurrencePolicy: policy),
        );
      },
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
    );
  },
  MonthlySchedule: (context, state, s) {
    final rule = s as MonthlySchedule;
    return MonthlySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) {
        state.widget.onChanged(rule.copyWithStartDate(date));
      },
      interval: rule.interval,
      onIntervalChanged: (val) {
        var policy = rule.schedulingPolicy;
        if (policy is CompletionRelativePolicy) {
          policy = CompletionRelativePolicy(
            interval: Duration(days: val * 30),
            targetTime: policy.targetTime,
          );
        }
        state.widget.onChanged(
          MonthlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: val,
            dayOfMonth: rule.dayOfMonth,
            dayOfWeek: rule.dayOfWeek,
            occurrence: rule.occurrence,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: policy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) {
        state.widget.onChanged(rule.copyWithTiming(schedulingPolicy: policy));
      },
      ruleType: rule.dayOfMonth != null ? 'dayOfMonth' : 'nthDayOfWeek',
      onRuleTypeChanged: (type) {
        if (type == 'dayOfMonth') {
          state.widget.onChanged(
            MonthlySchedule(
              id: rule.id,
              scheduleId: rule.scheduleId,
              startDate: rule.startDate,
              interval: rule.interval,
              dayOfMonth: rule.startDate.day <= 28 ? rule.startDate.day : 28,
              startRelativeTime: rule.startRelativeTime,
              dueRelativeTime: rule.dueRelativeTime,
              notificationRelativeTimes: rule.notificationRelativeTimes,
              schedulingPolicy: rule.schedulingPolicy,
              missedOccurrencePolicy: rule.missedOccurrencePolicy,
            ),
          );
        } else {
          state.widget.onChanged(
            MonthlySchedule(
              id: rule.id,
              scheduleId: rule.scheduleId,
              startDate: rule.startDate,
              interval: rule.interval,
              dayOfWeek: rule.startDate.toUtcDateTime().weekday,
              occurrence: 1,
              startRelativeTime: rule.startRelativeTime,
              dueRelativeTime: rule.dueRelativeTime,
              notificationRelativeTimes: rule.notificationRelativeTimes,
              schedulingPolicy: rule.schedulingPolicy,
              missedOccurrencePolicy: rule.missedOccurrencePolicy,
            ),
          );
        }
      },
      dayOfMonth: rule.dayOfMonth,
      onDayOfMonthChanged: (val) {
        state.widget.onChanged(
          MonthlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            dayOfMonth: val,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      occurrence: rule.occurrence,
      onOccurrenceChanged: (val) {
        state.widget.onChanged(
          MonthlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            dayOfWeek: rule.dayOfWeek,
            occurrence: val,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      dayOfWeek: rule.dayOfWeek,
      onDayOfWeekChanged: (val) {
        state.widget.onChanged(
          MonthlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            dayOfWeek: val,
            occurrence: rule.occurrence,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) {
        state.widget.onChanged(rule.copyWithTiming(startRelativeTime: start));
      },
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) {
        state.widget.onChanged(rule.copyWithTiming(dueRelativeTime: due));
      },
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) {
        state.widget.onChanged(
          rule.copyWithTiming(missedOccurrencePolicy: policy),
        );
      },
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
      dayOfMonthController: state._monthlyDayOfMonthController,
    );
  },
  YearlySchedule: (context, state, s) {
    final rule = s as YearlySchedule;
    return YearlySchedulingWidget(
      startDate: rule.startDate,
      onStartDateChanged: (date) {
        state.widget.onChanged(rule.copyWithStartDate(date));
      },
      interval: rule.interval,
      onIntervalChanged: (val) {
        var policy = rule.schedulingPolicy;
        if (policy is CompletionRelativePolicy) {
          policy = CompletionRelativePolicy(
            interval: Duration(days: val * 365),
            targetTime: policy.targetTime,
          );
        }
        state.widget.onChanged(
          YearlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: val,
            month: rule.month,
            day: rule.day,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: policy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      schedulingPolicy: rule.schedulingPolicy,
      onSchedulingPolicyChanged: (policy) {
        state.widget.onChanged(rule.copyWithTiming(schedulingPolicy: policy));
      },
      month: rule.month,
      onMonthChanged: (val) {
        state.widget.onChanged(
          YearlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            month: val,
            day: rule.day,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      day: rule.day,
      onDayChanged: (val) {
        state.widget.onChanged(
          YearlySchedule(
            id: rule.id,
            scheduleId: rule.scheduleId,
            startDate: rule.startDate,
            interval: rule.interval,
            month: rule.month,
            day: val,
            startRelativeTime: rule.startRelativeTime,
            dueRelativeTime: rule.dueRelativeTime,
            notificationRelativeTimes: rule.notificationRelativeTimes,
            schedulingPolicy: rule.schedulingPolicy,
            missedOccurrencePolicy: rule.missedOccurrencePolicy,
          ),
        );
      },
      startRelativeTime: rule.startRelativeTime,
      onStartRelativeTimeChanged: (start) {
        state.widget.onChanged(rule.copyWithTiming(startRelativeTime: start));
      },
      dueRelativeTime: rule.dueRelativeTime,
      onDueRelativeTimeChanged: (due) {
        state.widget.onChanged(rule.copyWithTiming(dueRelativeTime: due));
      },
      notificationRelativeTime: null,
      onNotificationRelativeTimeChanged: (_) {},
      missedOccurrencePolicy: rule.missedOccurrencePolicy,
      onMissedOccurrencePolicyChanged: (policy) {
        state.widget.onChanged(
          rule.copyWithTiming(missedOccurrencePolicy: policy),
        );
      },
      showNotification: false,
      showMissedPolicy: false,
      readOnly: state.widget.readOnly,
      intervalController: state._intervalController,
      dayController: state._yearlyDayController,
    );
  },
  OneOffSchedule: (context, state, s) {
    return OneOffSchedulingWidget(
      dueDateTime: state._oneOffDueController,
      notificationTimeController: state._oneOffNotificationController,
      showNotification: false,
    );
  },
};
"""

content = content[:imports_end] + builders_code + content[imports_end:]

# Replace the giant if-else ladder in build()
# It starts at:
#         if (s is DailySchedule) ...[
# and ends at:
#         ],
#         if (widget.showNotification) ...[

start_pattern = "if (s is DailySchedule) ...["
end_pattern = "if (widget.showNotification) ...["

start_idx = content.find(start_pattern)
end_idx = content.find(end_pattern, start_idx)

replacement = """final builder = _configBuilders[s.runtimeType];
        if (builder != null) builder(context, this, s),
        """

# But wait, there is a list of children. So we shouldn't insert `if (builder != null) builder(...)` because we need it to be inside the children array.
# The original structure:
#       children: [
#         HierarchicalRecurrenceSelector(...),
#         const SizedBox(height: 16),
#         if (s is DailySchedule) ...[
#           DailySchedulingWidget(...),
#         ] else if ...
#         ],
#         if (widget.showNotification) ...[
# 
# We should replace from `if (s is DailySchedule)` up to the closing `],` just before `if (widget.showNotification)`.
# Actually wait, `if (s is DailySchedule) ...[` doesn't have a closing `],` for the main array, it's just `],` which belongs to the `else if (s is OneOffSchedule) ...[` array.
# Let's verify the source.
# ```dart
#        ] else if (s is OneOffSchedule) ...[
#          OneOffSchedulingWidget(
#            ...
#          ),
#        ],
#        if (widget.showNotification) ...[
# ```
# Yes, so the pattern is from `if (s is DailySchedule) ...[` to `        ],\n        if (widget.showNotification) ...[`

replace_str = "        if (s is DailySchedule) ...["
end_str = "        if (widget.showNotification) ...["
start_idx = content.find(replace_str)
end_idx = content.find(end_str, start_idx)

# Backtrack to the previous closing bracket.
back_idx = content.rfind("],", start_idx, end_idx) + 2 # include `],`
# Wait, it's:
#        ] else if (s is OneOffSchedule) ...[
#          OneOffSchedulingWidget(...)
#        ],
# So we can just replace start_idx to end_idx-1.

part1 = content[:start_idx]
part2 = content[end_idx:]

builder_usage = """if (_configBuilders.containsKey(s.runtimeType))
          _configBuilders[s.runtimeType]!(context, this, s),
"""

content = part1 + builder_usage + part2

with open('app/lib/widgets/schedule_rule_config_widget.dart', 'w') as f:
    f.write(content)

print("Widget file updated.")
