import '../civil_day.dart';
import '../relative_time.dart';
import '../scheduling_policy.dart';
import '../app_clock.dart';
import 'task_schedule_rule.dart';
import 'one_off_schedule.dart';
import 'daily_schedule.dart';
import 'weekly_schedule.dart';
import 'monthly_schedule.dart';
import 'yearly_schedule.dart';

enum HierarchicalRecurrenceKind {
  oneOff,
  dailyFixed,
  dailyCompletionRelative,
  weeklyFixed,
  weeklyCompletionRelative,
  monthlyFixedDay,
  monthlyNthWeekday,
  monthlyCompletionRelative,
  yearlyFixed,
  yearlyCompletionRelative,
}

extension TaskScheduleRuleHierarchicalExtension on TaskScheduleRule {
  HierarchicalRecurrenceKind get hierarchicalKind {
    final self = this;
    if (self is OneOffSchedule) {
      return HierarchicalRecurrenceKind.oneOff;
    } else if (self is DailySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.dailyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.dailyFixed;
    } else if (self is WeeklySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.weeklyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.weeklyFixed;
    } else if (self is MonthlySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.monthlyCompletionRelative;
      } else if (self.dayOfMonth != null) {
        return HierarchicalRecurrenceKind.monthlyFixedDay;
      }
      return HierarchicalRecurrenceKind.monthlyNthWeekday;
    } else if (self is YearlySchedule) {
      if (self.schedulingPolicy is CompletionRelativePolicy) {
        return HierarchicalRecurrenceKind.yearlyCompletionRelative;
      }
      return HierarchicalRecurrenceKind.yearlyFixed;
    }
    throw StateError('Unknown schedule rule type');
  }
}

TaskScheduleRule convertRuleToKind(
  TaskScheduleRule existingRule,
  HierarchicalRecurrenceKind kind,
) {
  final id = existingRule.id;
  final scheduleId = existingRule.scheduleId;
  var scheduledDate = existingRule.scheduledDate;
  var startRelativeTime = existingRule.startRelativeTime;
  final dueRelativeTime = existingRule.dueRelativeTime;
  final notificationRelativeTimes = existingRule.notificationRelativeTimes;
  final missedOccurrencePolicy = existingRule.missedOccurrencePolicy;

  if (kind != HierarchicalRecurrenceKind.oneOff) {
    final now = AppClock.now;
    final tomorrow = CivilDay.fromDateTime(now.add(const Duration(days: 1)));
    if (existingRule is OneOffSchedule &&
        scheduledDate == tomorrow &&
        startRelativeTime.dayOffset == -1) {
      scheduledDate = CivilDay.fromDateTime(now);
      startRelativeTime = RelativeTime(
        dayOffset: 0,
        time: startRelativeTime.time,
      );
    }
  }

  // Read existing interval if possible, default to 1
  int interval = 1;
  final self = existingRule;
  if (self is DailySchedule) {
    interval = self.interval;
  } else if (self is WeeklySchedule) {
    interval = self.interval;
  } else if (self is MonthlySchedule) {
    interval = self.interval;
  } else if (self is YearlySchedule) {
    interval = self.interval;
  }

  switch (kind) {
    case HierarchicalRecurrenceKind.oneOff:
      return OneOffSchedule(
        id: id,
        scheduleId: scheduleId,
        date: scheduledDate,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.dailyFixed:
      return DailySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.dailyCompletionRelative:
      return DailySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.weeklyFixed:
      return WeeklySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        daysOfWeek: {scheduledDate.toUtcDateTime().weekday},
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.weeklyCompletionRelative:
      return WeeklySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        daysOfWeek: {scheduledDate.toUtcDateTime().weekday},
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 7),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyFixedDay:
      return MonthlySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        dayOfMonth: scheduledDate.day <= 28 ? scheduledDate.day : 28,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyNthWeekday:
      final weekday = scheduledDate.toUtcDateTime().weekday;
      final occurrence = (scheduledDate.day - 1) ~/ 7 + 1;
      return MonthlySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        dayOfWeek: weekday,
        occurrence: occurrence,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.monthlyCompletionRelative:
      return MonthlySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        dayOfMonth: scheduledDate.day <= 28 ? scheduledDate.day : 28,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 30),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.yearlyFixed:
      return YearlySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        month: scheduledDate.month,
        day: scheduledDate.day,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: const FixedCalendarPolicy(),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );

    case HierarchicalRecurrenceKind.yearlyCompletionRelative:
      return YearlySchedule(
        id: id,
        scheduleId: scheduleId,
        startDate: scheduledDate,
        interval: interval,
        month: scheduledDate.month,
        day: scheduledDate.day,
        startRelativeTime: startRelativeTime,
        dueRelativeTime: dueRelativeTime,
        notificationRelativeTimes: notificationRelativeTimes,
        schedulingPolicy: CompletionRelativePolicy(
          interval: Duration(days: interval * 365),
          targetTime: startRelativeTime.time,
        ),
        missedOccurrencePolicy: missedOccurrencePolicy,
      );
  }
}
