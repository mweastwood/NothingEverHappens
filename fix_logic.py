import re

with open('app/lib/logic/task_schedule_rule.dart', 'r') as f:
    content = f.read()

# Add import l10n_extension.dart
content = content.replace("import 'app_clock.dart';", "import 'app_clock.dart';\nimport 'l10n_extension.dart';")

# Add abstract methods
base_class_pattern = r"(Map<String, dynamic> toJson\(\);\n\n  factory TaskScheduleRule\.fromJson)"
base_class_methods = """  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context);

  String getMissedPolicyDescription(BuildContext context) {
    final policy = missedOccurrencePolicy;
    switch (policy.policy) {
      case MissedPolicy.preferNewer:
        return context.l10n.preferNewerTitle;
      case MissedPolicy.preferOlder:
        return context.l10n.preferOlderTitle;
      case MissedPolicy.stack:
        return context.l10n.stackPolicyTitle;
      case MissedPolicy.autoDismiss:
        final minutes = policy.gracePeriod.inMinutes;
        if (minutes == 0) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.immediatelyPolicy})';
        } else if (minutes == 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.oneHourPolicy})';
        } else if (minutes == 6 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.sixHoursPolicy})';
        } else if (minutes == 12 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twelveHoursPolicy})';
        } else if (minutes == 24 * 60) {
          return '${context.l10n.autoDismissPolicyTitle} (${context.l10n.twentyFourHoursPolicy})';
        } else if (minutes % (7 * 24 * 60) == 0) {
          final weeks = minutes ~/ (7 * 24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($weeks ${context.l10n.unitWeeks})';
        } else if (minutes % (24 * 60) == 0) {
          final days = minutes ~/ (24 * 60);
          return '${context.l10n.autoDismissPolicyTitle} ($days ${context.l10n.unitDays})';
        } else if (minutes % 60 == 0) {
          final hours = minutes ~/ 60;
          return '${context.l10n.autoDismissPolicyTitle} ($hours ${context.l10n.unitHours})';
        } else {
          return '${context.l10n.autoDismissPolicyTitle} ($minutes ${context.l10n.unitMinutes})';
        }
    }
  }

  """
content = re.sub(base_class_pattern, base_class_methods + r"\1", content)

# Add to OneOffSchedule
one_off_methods = """  @override
  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return (
      interval: context.l10n.oneOffLabel,
      days: '',
      start: context.l10n.startingDate(dateStr),
    );
  }

  @override
  String getMissedPolicyDescription(BuildContext context) => '';

"""
content = content.replace("  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'oneOff',", one_off_methods + "  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'oneOff',")


# Add to DailySchedule
daily_methods = """  @override
  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context) {
    final intervalStr = interval == 1
        ? context.l10n.everyDay
        : context.l10n.everyNDays(interval);
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    return (
      interval: intervalStr,
      days: '',
      start: context.l10n.startingDate(dateStr),
    );
  }

"""
content = content.replace("  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'daily',", daily_methods + "  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'daily',")


# Add to WeeklySchedule
weekly_methods = """  @override
  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context) {
    final intervalStr = interval == 1
        ? context.l10n.everyWeek
        : context.l10n.everyNWeeks(interval);
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    
    final dayNames = {
      1: context.l10n.weekdayShortMonday,
      2: context.l10n.weekdayShortTuesday,
      3: context.l10n.weekdayShortWednesday,
      4: context.l10n.weekdayShortThursday,
      5: context.l10n.weekdayShortFriday,
      6: context.l10n.weekdayShortSaturday,
      7: context.l10n.weekdayShortSunday,
    };
    final selectedDays = daysOfWeek.toList()..sort();
    final joinedDays = selectedDays.map((d) => dayNames[d] ?? '').join(', ');
    final daysStr = context.l10n.onDaysOfWeek(joinedDays);

    return (
      interval: intervalStr,
      days: daysStr,
      start: context.l10n.startingDate(dateStr),
    );
  }

"""
content = content.replace("  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'weekly',", weekly_methods + "  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'weekly',")


# Add to MonthlySchedule
monthly_methods = """  @override
  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context) {
    final intervalStr = interval == 1
        ? context.l10n.everyMonth
        : context.l10n.everyNMonths(interval);
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    
    String daysStr = '';
    if (dayOfMonth != null) {
      if (dayOfMonth! > 0) {
        daysStr = context.l10n.dayOfMonthOnDay(dayOfMonth!);
      } else {
        daysStr = context.l10n.dayOfMonthFromEnd(dayOfMonth!.abs());
      }
    } else {
      final occurrenceNames = {
        1: context.l10n.firstOccurrence,
        2: context.l10n.secondOccurrence,
        3: context.l10n.thirdOccurrence,
        4: context.l10n.fourthOccurrence,
        -1: context.l10n.lastOccurrence,
      };
      final dayOfWeekNames = {
        1: context.l10n.weekdayMonday,
        2: context.l10n.weekdayTuesday,
        3: context.l10n.weekdayWednesday,
        4: context.l10n.weekdayThursday,
        5: context.l10n.weekdayFriday,
        6: context.l10n.weekdaySaturday,
        7: context.l10n.weekdaySunday,
      };
      final occStr = occurrenceNames[occurrence] ?? '';
      final dowStr = dayOfWeekNames[dayOfWeek] ?? '';
      daysStr = context.l10n.nthDayOfWeekOccurrence(occStr, dowStr);
    }

    return (
      interval: intervalStr,
      days: daysStr,
      start: context.l10n.startingDate(dateStr),
    );
  }

"""
content = content.replace("  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'monthly',", monthly_methods + "  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'monthly',")


# Add to YearlySchedule
yearly_methods = """  @override
  ({String interval, String days, String start}) getRecurrenceDetails(BuildContext context) {
    final intervalStr = interval == 1
        ? context.l10n.everyYear
        : context.l10n.everyNYears(interval);
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    
    final monthNames = {
      1: context.l10n.monthJanuary,
      2: context.l10n.monthFebruary,
      3: context.l10n.monthMarch,
      4: context.l10n.monthApril,
      5: context.l10n.monthMay,
      6: context.l10n.monthJune,
      7: context.l10n.monthJuly,
      8: context.l10n.monthAugust,
      9: context.l10n.monthSeptember,
      10: context.l10n.monthOctober,
      11: context.l10n.monthNovember,
      12: context.l10n.monthDecember,
    };
    final mStr = monthNames[month] ?? '';
    final daysStr = context.l10n.yearlyOn(mStr, day);

    return (
      interval: intervalStr,
      days: daysStr,
      start: context.l10n.startingDate(dateStr),
    );
  }

"""
content = content.replace("  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'yearly',", yearly_methods + "  @override\n  Map<String, dynamic> toJson() {\n    return {\n      'id': id,\n      'scheduleId': scheduleId,\n      'type': 'yearly',")

with open('app/lib/logic/task_schedule_rule.dart', 'w') as f:
    f.write(content)

print("Logic file updated.")
