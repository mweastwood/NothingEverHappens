// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nothing Ever Happens';

  @override
  String get errorOccurred => 'Error Occurred';

  @override
  String get somethingWentWrong =>
      'Something went wrong. Please share this error code with the developer:';

  @override
  String get details => 'Details:';

  @override
  String get close => 'Close';

  @override
  String get pleaseSignInToContinue => 'Please sign in to continue';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get tasksTab => 'Tasks';

  @override
  String get scheduleTab => 'Schedule';

  @override
  String get dashboardTab => 'Dashboard';

  @override
  String get capacityPromptTitle => 'Adjust your weekly capacity';

  @override
  String get capacityPromptSubtitle =>
      'Set your available hours for the upcoming days.';

  @override
  String get historyTab => 'History';

  @override
  String get addTaskTooltip => 'Add Task';

  @override
  String get menu => 'Menu';

  @override
  String get logout => 'Logout';

  @override
  String get editTaskTitle => 'Edit Task';

  @override
  String get newTaskTitle => 'New Task';

  @override
  String get titleFieldLabel => 'Title';

  @override
  String get titleRequiredError => 'Please enter a title';

  @override
  String get descriptionFieldLabel => 'Description';

  @override
  String get estimatedEffortFieldLabel => 'Estimated Effort (Minutes)';

  @override
  String get estimatedEffortHelper =>
      'Optional. Enter the estimated time in minutes.';

  @override
  String get estimatedEffortValidationError =>
      'Please enter a positive number of minutes';

  @override
  String estimatedEffortLabel(String duration) {
    return 'Estimated Effort: $duration';
  }

  @override
  String get scheduleHeader => 'Schedule';

  @override
  String get oneOffLabel => 'One-off';

  @override
  String get dailyLabel => 'Daily';

  @override
  String get weeklyLabel => 'Weekly';

  @override
  String get discardButton => 'Discard';

  @override
  String get saveButton => 'Save';

  @override
  String get selectAtLeastOneDayError =>
      'Please select at least one day of the week';

  @override
  String get dueLabel => 'Due: ';

  @override
  String get startLabel => 'Start';

  @override
  String get dueWithoutColon => 'Due';

  @override
  String get dueDescription =>
      'When does this task need to be completed before it should be considered overdue?';

  @override
  String get advancedHeader => 'Advanced';

  @override
  String get snoozeUntilLabel => 'Snooze Until: ';

  @override
  String get snoozeUntilDescription =>
      'The task will be hidden from your primary list of tasks until this time.';

  @override
  String get startDateLabel => 'Start Date';

  @override
  String get intervalLabel => 'Interval';

  @override
  String everyNDays(int count) {
    return 'Every $count days';
  }

  @override
  String everyNDaysSinceLastScheduled(int count) {
    return 'Every $count day(s) (since last scheduled)';
  }

  @override
  String everyNDaysSinceLastCompletion(int count) {
    return 'Every $count day(s) (since last completion)';
  }

  @override
  String everyNWeeksSinceLastScheduled(int count) {
    return 'Every $count week(s) (since last scheduled)';
  }

  @override
  String everyNWeeksSinceLastCompletion(int count) {
    return 'Every $count week(s) (since last completion)';
  }

  @override
  String get daysIntervalLabel => 'Days Interval';

  @override
  String get daysIntervalHelper =>
      'E.g., 1 for every day, 2 for every other day';

  @override
  String get weeksIntervalLabel => 'Weeks Interval';

  @override
  String get weeksIntervalHelper => 'E.g., 1 for every week';

  @override
  String get repeatsOnLabel => 'Repeats on';

  @override
  String get dailyOccurrencesHeader => 'Daily Occurrences';

  @override
  String get startTimeLabel => 'Start Time';

  @override
  String get dueTimeLabel => 'Due Time';

  @override
  String get notificationTimeLabel => 'Notification Time';

  @override
  String get noneLabel => 'None';

  @override
  String get clearNotificationTimeTooltip => 'Clear notification time';

  @override
  String get removeTimeSlotTooltip => 'Remove time slot';

  @override
  String get addTimeSlotButton => 'Add Time Slot';

  @override
  String get noTasksYet => 'No tasks yet. Add one!';

  @override
  String get noHistoryYet => 'No history yet';

  @override
  String get noRecurringTasksScheduled => 'No recurring tasks scheduled';

  @override
  String get copiedToClipboard => 'Copied task to clipboard';

  @override
  String get deleteTaskConfirmTitle => 'Delete Task?';

  @override
  String deleteTaskConfirmBody(String title) {
    return 'Are you sure you want to delete \"$title\"? This action will permanently remove the task.';
  }

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteButton => 'Delete';

  @override
  String get editScheduleTooltip => 'Edit Schedule';

  @override
  String get deleteTaskTooltip => 'Delete Task';

  @override
  String get dailyRecurrence => 'Daily';

  @override
  String get weeklyRecurrence => 'Weekly';

  @override
  String get everyDay => 'Every day';

  @override
  String get everyWeek => 'Every week';

  @override
  String everyNWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String startingDate(String date) {
    return 'Starting: $date';
  }

  @override
  String onDaysOfWeek(String days) {
    return 'On: $days';
  }

  @override
  String get missedPolicyHeader => 'Missed Occurrence Policy';

  @override
  String get missedPolicyHelper =>
      'Define what happens if a recurring task is not completed by its due time.';

  @override
  String get stackLabel => 'Stack/Overlap (Allow Concurrency)';

  @override
  String get stackDescription =>
      'Missed occurrences remain active, letting multiple instances stack up.';

  @override
  String get monthlyLabel => 'Monthly';

  @override
  String get yearlyLabel => 'Yearly';

  @override
  String get repeatingLabel => 'Repeating';

  @override
  String get sinceLastScheduledLabel => 'Since last scheduled';

  @override
  String get sinceLastCompletionLabel => 'Since last completion';

  @override
  String get intervalTypeLabel => 'Interval Type';

  @override
  String get startRecurrenceDateLabel => 'Start Recurrence Date';

  @override
  String get addNotificationLabel => 'Add notification';

  @override
  String get dayOfMonthLabel => 'Day of Month';

  @override
  String get nthDayOfWeekLabel => 'Nth Day of Week';

  @override
  String get monthlyRecurrenceTypeLabel => 'Recurrence Rule';

  @override
  String get monthsIntervalLabel => 'Months Interval';

  @override
  String get yearsIntervalLabel => 'Years Interval';

  @override
  String get dayOfMonthFieldLabel => 'Day of Month';

  @override
  String get dayOfMonthValidationError =>
      'Please enter a valid day number: 1 to 28';

  @override
  String get monthlyFromStart => 'From start of month';

  @override
  String get monthlyFromEnd => 'From end of month';

  @override
  String get dayOfMonthStepperLabel => 'Day';

  @override
  String get nthOccurrenceLabel => 'Occurrence';

  @override
  String get firstOccurrence => '1st';

  @override
  String get secondOccurrence => '2nd';

  @override
  String get thirdOccurrence => '3rd';

  @override
  String get fourthOccurrence => '4th';

  @override
  String get lastOccurrence => 'Last';

  @override
  String get dayOfWeekLabel => 'Day of Week';

  @override
  String get monthLabel => 'Month';

  @override
  String get dayLabel => 'Day';

  @override
  String get everyMonth => 'Every month';

  @override
  String everyNMonths(int count) {
    return 'Every $count months';
  }

  @override
  String everyNMonthsSinceLastScheduled(int count) {
    return 'Every $count month(s) (since last scheduled)';
  }

  @override
  String everyNMonthsSinceLastCompletion(int count) {
    return 'Every $count month(s) (since last completion)';
  }

  @override
  String get everyYear => 'Every year';

  @override
  String everyNYears(int count) {
    return 'Every $count years';
  }

  @override
  String everyNYearsSinceLastScheduled(int count) {
    return 'Every $count year(s) (since last scheduled)';
  }

  @override
  String everyNYearsSinceLastCompletion(int count) {
    return 'Every $count year(s) (since last completion)';
  }

  @override
  String dayOfMonthOnDay(Object day) {
    return 'On day $day';
  }

  @override
  String dayOfMonthFromEnd(Object day) {
    return 'On the $day day from the end';
  }

  @override
  String repeatsOnDayOfMonthHelp(Object day) {
    return 'Repeats on the $day day of the month.';
  }

  @override
  String repeatsOnDayFromEndHelp(Object day) {
    return 'Repeats on the $day day from the end of the month.';
  }

  @override
  String repeatsOnNthWeekdayHelp(Object dayOfWeek, Object occurrence) {
    return 'Repeats on the $occurrence $dayOfWeek of the month.';
  }

  @override
  String nthDayOfWeekOccurrence(Object dayOfWeek, Object occurrence) {
    return 'On the $occurrence $dayOfWeek';
  }

  @override
  String yearlyOn(Object day, Object month) {
    return 'On: $month $day';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get hoursAvailableLabel => 'Available Hours per Day';

  @override
  String get hoursAvailableHelper =>
      'Number of hours available for agile-based scheduling.';

  @override
  String get hoursAvailableValidationError =>
      'Please enter a number between 0 and 24';

  @override
  String get settingsSavedSuccessfully => 'Settings saved successfully';

  @override
  String get showPendingTasksLabel => 'Show Pending Tasks';

  @override
  String get showPendingTasksHelper =>
      'Show tasks on the main list whose start time is in the future.';

  @override
  String get showLastSpawnedDateLabel => 'Show Last Spawned Date';

  @override
  String get showLastSpawnedDateHelper =>
      'Display the last spawned date on each task schedule card for debugging.';

  @override
  String get pendingBadge => 'Pending';

  @override
  String get familyTab => 'Family';

  @override
  String get familyScreenTitle => 'Family';

  @override
  String get createFamilyTitle => 'Create Family';

  @override
  String get createFamilyButton => 'Create Family';

  @override
  String get familyUnitNameLabel => 'Family Name';

  @override
  String get inviteMemberButton => 'Invite Member';

  @override
  String get inviteMemberTitle => 'Invite Family Member';

  @override
  String get inviteMemberEmailLabel => 'Email Address';

  @override
  String get inviteMemberRoleLabel => 'Role';

  @override
  String get parentRole => 'Parent';

  @override
  String get nonParentRole => 'Non-Parent';

  @override
  String get pendingInvitesHeader => 'Pending Invites';

  @override
  String get acceptInviteButton => 'Accept';

  @override
  String get declineInviteButton => 'Decline';

  @override
  String get leaveFamilyButton => 'Leave Family';

  @override
  String get membersHeader => 'Family Members';

  @override
  String familyMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get notInFamilyBody =>
      'You are not currently in a family unit. You can create a new family or accept a pending invitation below.';

  @override
  String get noPendingInvites => 'No pending invitations';

  @override
  String get inviteSentSuccess => 'Invitation sent successfully';

  @override
  String get outstandingInvitesHeader => 'Outstanding Invitations';

  @override
  String get revokeInviteButton => 'Revoke';

  @override
  String get inviteRevokedSuccess => 'Invitation revoked successfully';

  @override
  String get noOutstandingInvites => 'No outstanding invitations';

  @override
  String get revokeInviteConfirmTitle => 'Revoke Invitation?';

  @override
  String revokeInviteConfirmBody(String email) {
    return 'Are you sure you want to revoke the invitation for $email?';
  }

  @override
  String invitedBy(String name, String email) {
    return 'Invited by $name ($email)';
  }

  @override
  String get leaveFamilyConfirmTitle => 'Leave Family?';

  @override
  String get leaveFamilyConfirmBody =>
      'Are you sure you want to leave the family?';

  @override
  String get taskPriorityLabel => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get familyTaskLabel => 'Family Task';

  @override
  String get familyTaskHelper => 'Share this task with all family members.';

  @override
  String get viewTaskTitle => 'View Task';

  @override
  String get onlyParentsCanEditFamilyTasks =>
      'Only parents can edit family tasks';

  @override
  String get sprintDashboardTitle => 'Sprint Dashboard';

  @override
  String get autoAllocateButton => 'Auto-Allocate Chores';

  @override
  String get choresAllocatedSuccess => 'Chores auto-allocated successfully!';

  @override
  String get removeFromCycleTooltip => 'Remove from cycle';

  @override
  String get addToCycleTooltip => 'Add to cycle';

  @override
  String get backlogTab => 'Backlog';

  @override
  String get activeCycleTab => 'Active Cycle';

  @override
  String get weeklyCapacityLabel => 'Weekly Capacity';

  @override
  String personalTasksLabel(int effort) {
    return 'Personal Tasks: $effort min';
  }

  @override
  String familyChoresLabel(int effort) {
    return 'Family Chores: $effort min';
  }

  @override
  String remainingCapacityLabel(int effort) {
    return 'Remaining Capacity: $effort min';
  }

  @override
  String get noActiveTasks =>
      'No active tasks in this cycle. Move some from the backlog!';

  @override
  String get noBacklogTasks => 'No tasks in the backlog.';

  @override
  String get unassigned => 'Unassigned';

  @override
  String assignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String get starTooltip => 'Toggle preference';

  @override
  String get familyCapacityPool => 'Family Capacity Pool';

  @override
  String memberRemainingTotal(int remaining, int total) {
    return '$remaining min remaining / $total min total';
  }

  @override
  String memberPersonalChores(int personal, int family) {
    return 'Personal: $personal min | Family Chores: $family min';
  }

  @override
  String get helpTitle => 'Help';

  @override
  String get helpTooltip => 'Help';

  @override
  String get helpTabInteractions => 'Basic Task Completion';

  @override
  String get practiceHelpContent =>
      '# Practice Basic Task Completion\n\nThere are two ways to complete a task:\n\n1. Tapping the checkbox on the left marks a task as complete.\n2. Tapping the x button on the right dismisses a task, indicating that you will not complete it (for any reason).\n\nUse the space below to practice marking tasks as completed or dismissed.';

  @override
  String get helpTabScheduling => 'Task Scheduling';

  @override
  String get schedulingPlaygroundHelpContent =>
      '# Practice Task Scheduling\n\nUse the controls below to configure different task schedules in real-time.\n\n- The **calendar grid** highlights the days on which the task will occur over a 3-month period (Current, Next, and Month After).\n- The **occurrences list** displays the next 10 calculated dates.\n\n*Try changing the interval, selecting different days of the week, or choosing different monthly/yearly options to see how occurrences update.*';

  @override
  String occurrenceAppears(String dateTime) {
    return 'Appears: $dateTime';
  }

  @override
  String occurrenceDue(String dateTime) {
    return 'Due: $dateTime';
  }

  @override
  String get invalidIntervalError =>
      'Please enter a valid interval greater than 0';

  @override
  String get occurrencesHeader => 'Next 10 Occurrences';

  @override
  String get noOccurrencesPlaceholder =>
      'No future occurrences scheduled. Ensure all inputs are valid.';

  @override
  String get pastOccurrencesHeader => 'Last 10 Occurrences';

  @override
  String get noPastOccurrencesPlaceholder => 'No past occurrences.';

  @override
  String occurrenceCompleted(String dateTime) {
    return 'Completed: $dateTime';
  }

  @override
  String get occurrenceSkipped => 'Skipped';

  @override
  String occurrenceMissed(String dateTime) {
    return 'Overdue (Due: $dateTime)';
  }

  @override
  String occurrenceActive(String dateTime) {
    return 'Active (Due: $dateTime)';
  }

  @override
  String get visualCalendarGridHeader => 'Visual Calendar Grid';

  @override
  String get dayIsRequiredError => 'Day is required';

  @override
  String dayMustBeBetweenError(int max) {
    return 'Day must be between 1 and $max';
  }

  @override
  String calculationError(String error) {
    return 'Calculation error: $error';
  }

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get weekdayHeaderMonday => 'M';

  @override
  String get weekdayHeaderTuesday => 'T';

  @override
  String get weekdayHeaderWednesday => 'W';

  @override
  String get weekdayHeaderThursday => 'T';

  @override
  String get weekdayHeaderFriday => 'F';

  @override
  String get weekdayHeaderSaturday => 'S';

  @override
  String get weekdayHeaderSunday => 'S';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get helpTabMissedPolicies => 'Missed Policies';

  @override
  String get missedPoliciesIntro =>
      '### Missed Occurrence Policies\n\nWhen a recurring task is not completed by its due time, the app applies a **Missed Occurrence Policy** to handle the overdue instance.\n\nUse the simulator below to see how each policy handles overdue tasks over time.';

  @override
  String get stackSimTip =>
      '### Stack Policy\n\n**Behavior:** Missed occurrences remain active and spawn a separate task instance for each day, letting multiple instances stack up. They all appear on your task list concurrently until completed or dismissed.\n\n**Try this:**\n1. Tap **Advance 1 Day** 3 times.\n2. Notice that 3 separate tasks appear on your list (one for each missed day).\n3. Complete or dismiss them individually to clear the backlog.';

  @override
  String get advanceDayButton => 'Advance 1 Day';

  @override
  String get resetSimButton => 'Reset Simulation';

  @override
  String simulatedTodayLabel(String date) {
    return 'Simulated Today: $date';
  }

  @override
  String activeTasksHeader(int count) {
    return 'Simulated Tasks ($count)';
  }

  @override
  String get historyLogHeader => 'Simulation History Log';

  @override
  String get undoButton => 'Undo';

  @override
  String get actionUndone => 'Action undone';

  @override
  String taskCompleted(String title) {
    return 'Completed \"$title\"';
  }

  @override
  String taskDismissed(String title) {
    return 'Dismissed \"$title\"';
  }

  @override
  String scheduleDeleted(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String taskEditsSaved(String title) {
    return 'Saved \"$title\"';
  }

  @override
  String taskRestored(String title) {
    return '\"$title\" restored';
  }

  @override
  String editsReverted(String title) {
    return 'Changes to \"$title\" reverted';
  }

  @override
  String dueTodayAt(String time) {
    return 'Due Today at $time';
  }

  @override
  String overdueTodayAt(String time) {
    return 'Overdue: Today at $time';
  }

  @override
  String overdueYesterdayAt(String time) {
    return 'Overdue: Yesterday at $time';
  }

  @override
  String dueTomorrowAt(String time) {
    return 'Due Tomorrow at $time';
  }

  @override
  String dueAt(String date, String time) {
    return 'Due $date at $time';
  }

  @override
  String overdueAt(String date, String time) {
    return 'Overdue: $date at $time';
  }

  @override
  String get loadingBadge => 'Loading...';

  @override
  String get assignedBadge => 'Assigned';

  @override
  String get recurringLabel => 'Recurring';

  @override
  String get searchTasksPlaceholder => 'Search tasks...';

  @override
  String noTasksMatching(String query) {
    return 'No matching tasks found for \"$query\"';
  }

  @override
  String get clearSearchButton => 'Clear Search';

  @override
  String get presetWeekdays => 'Weekdays';

  @override
  String get presetWeekends => 'Weekends';

  @override
  String get presetAll => 'All';

  @override
  String get presetClear => 'Clear';

  @override
  String get presetMonthSingular => 'month';

  @override
  String get presetMonthPlural => 'months';

  @override
  String get presetYearSingular => 'year';

  @override
  String get presetYearPlural => 'years';

  @override
  String get scheduleSortByLabel => 'Sort by';

  @override
  String get scheduleGridTypeHeader => 'Type';

  @override
  String get scheduleSortNextStartLabel => 'Next Start';

  @override
  String get scheduleSortNextDueLabel => 'Next Due';

  @override
  String get scheduleGridTimeWindowHeader => 'Time Window';

  @override
  String get scheduleGridActionsHeader => 'Actions';

  @override
  String get searchSchedulesPlaceholder => 'Search schedules...';

  @override
  String noSchedulesMatching(String query) {
    return 'No matching schedules found for \"$query\"';
  }

  @override
  String get scheduleRequiredError => 'At least one schedule is required.';

  @override
  String get capacityDependentEffortRequiredError =>
      'Estimated effort is required for Capacity Dependent tasks.';

  @override
  String get familyTaskToggleLabel => 'Family Task';

  @override
  String get personalTaskToggleLabel => 'Personal Task';

  @override
  String get effortAndPriorityLabel => 'Effort and Priority';

  @override
  String get addScheduleButton => 'Add Schedule';

  @override
  String get saveTimeoutError =>
      'Save operation timed out. Please check your connection.';

  @override
  String get hoursSuffix => 'hours';

  @override
  String get futureOccurrencesLabel => 'Future Occurrences';

  @override
  String get preCreatedFutureTasksHelper => 'Pre-created future tasks (1-10)';

  @override
  String get resetPracticeButton => 'Reset Practice';

  @override
  String practiceTasksRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Practice Tasks ($count remaining)',
      one: 'Practice Tasks (1 remaining)',
    );
    return '$_temp0';
  }

  @override
  String get practiceTasksCompleted => 'All tasks completed or dismissed!';

  @override
  String get practiceTasksResetPrompt => 'Tap \"Reset Practice\" to try again.';

  @override
  String get unitLabel => 'Unit';

  @override
  String get unitHours => 'Hour(s)';

  @override
  String get unitDays => 'Day(s)';

  @override
  String get unitWeeks => 'Week(s)';

  @override
  String get unitMinutes => 'Minute(s)';

  @override
  String get targetStartTimeLabel => 'Target Start Time';

  @override
  String get selectMissedPolicyTitle => 'Select Missed Occurrence Policy';

  @override
  String get immediatelyPolicy => 'Immediately';

  @override
  String get oneHourPolicy => '1 Hour';

  @override
  String get sixHoursPolicy => '6 Hours';

  @override
  String get twelveHoursPolicy => '12 Hours';

  @override
  String get twentyFourHoursPolicy => '24 Hours (1 Day)';

  @override
  String get customDurationPolicy => 'Custom Duration...';

  @override
  String get addNotificationButton => 'Add notification';

  @override
  String get selectDayTitle => 'Select Day';

  @override
  String get okButton => 'OK';

  @override
  String get fixedCalendarLabel => 'Fixed Calendar';

  @override
  String get completionRelativeLabel => 'Completion-Relative';

  @override
  String get capacityDependentLabel => 'Capacity Dependent';

  @override
  String get capacityDependentTitle => 'Based on remaining capacity';

  @override
  String get capacityDependentSubtitle =>
      'Scheduled only if capacity permits, otherwise pushed forward day-by-day';

  @override
  String get taskTypeLabel => 'Task Type';

  @override
  String get simulationPresetDaily => 'Daily Preset (Feed Pets)';

  @override
  String get simulationPresetWeekly => 'Weekly Preset (Mow Lawn)';

  @override
  String simulatedTimeLabel(String time) {
    return 'Simulated Time: $time';
  }

  @override
  String get simulationOneHour => '1 Hour';

  @override
  String get simulationSixHours => '6 Hours';

  @override
  String get simulationTwentyFourHours => '24 Hours';

  @override
  String get noActivePlaygroundTasks => 'No active tasks.';

  @override
  String autoDismissPolicyHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get missedPolicyDialogIntro =>
      'In the examples shown below, assume we have a daily task that we didn\'t complete, check-off, or dismiss the task in any way on Monday or Tuesday. It is now Wednesday, so what should be done with the older tasks?';

  @override
  String get dismissAfterLabel => 'Dismiss After';

  @override
  String get durationLabel => 'Duration';

  @override
  String get presetsLabel => 'Presets';

  @override
  String get presetDaySingular => 'day';

  @override
  String get presetDayPlural => 'days';

  @override
  String get presetWeekSingular => 'week';

  @override
  String get presetWeekPlural => 'weeks';

  @override
  String get taskAppearanceHelpText =>
      'When does the task appear in your list of tasks?';

  @override
  String get enableNotificationReminderLabel => 'Enable notification reminder';

  @override
  String get notificationWindowLabel => 'Notification window';

  @override
  String get repeatIntervalLabel => 'Repeat Interval';

  @override
  String completionRelativeSummary(String val, String unit, String time) {
    return 'Completion-relative: every $val $unit @ $time';
  }

  @override
  String oneOffSummary(String date) {
    return 'One-off on $date';
  }

  @override
  String dailySummary(String count) {
    return 'Daily, every $count day(s)';
  }

  @override
  String weeklySummary(String count, String days) {
    return 'Weekly, every $count week(s) on $days';
  }

  @override
  String monthlySummaryDay(String count, String day) {
    return 'Monthly, every $count month(s) on day $day';
  }

  @override
  String monthlySummaryNth(String count, String occurrence, String weekday) {
    return 'Monthly, every $count month(s) on $occurrence $weekday';
  }

  @override
  String yearlySummary(String count, String month, String day) {
    return 'Yearly, every $count year(s) on $month $day';
  }

  @override
  String get customScheduleSummary => 'Custom schedule';

  @override
  String get deleteScheduleTooltip => 'Delete Schedule';

  @override
  String get weekdayShortMonday => 'Mon';

  @override
  String get weekdayShortTuesday => 'Tue';

  @override
  String get weekdayShortWednesday => 'Wed';

  @override
  String get weekdayShortThursday => 'Thu';

  @override
  String get weekdayShortFriday => 'Fri';

  @override
  String get weekdayShortSaturday => 'Sat';

  @override
  String get weekdayShortSunday => 'Sun';

  @override
  String get monthShortJanuary => 'Jan';

  @override
  String get monthShortFebruary => 'Feb';

  @override
  String get monthShortMarch => 'Mar';

  @override
  String get monthShortApril => 'Apr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJune => 'Jun';

  @override
  String get monthShortJuly => 'Jul';

  @override
  String get monthShortAugust => 'Aug';

  @override
  String get monthShortSeptember => 'Sep';

  @override
  String get monthShortOctober => 'Oct';

  @override
  String get monthShortNovember => 'Nov';

  @override
  String get monthShortDecember => 'Dec';

  @override
  String completionRelativeHelpDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days after the task was last completed.',
      one: '1 day after the task was last completed.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks after the task was last completed.',
      one: '1 week after the task was last completed.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months after the task was last completed.',
      one: '1 month after the task was last completed.',
    );
    return '$_temp0';
  }

  @override
  String completionRelativeHelpYearly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years after the task was last completed.',
      one: '1 year after the task was last completed.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryDayHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeats every $count days starting $date.',
      one: 'Repeats every day starting $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryWeekHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeats every $count weeks starting $date.',
      one: 'Repeats every week starting $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryMonthHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeats every $count months starting $date.',
      one: 'Repeats every month starting $date.',
    );
    return '$_temp0';
  }

  @override
  String repeatsEveryYearHelp(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeats every $count years starting $date.',
      one: 'Repeats every year starting $date.',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceTypeHeader => 'RECURRENCE TYPE';

  @override
  String get dailyFixedTitle => 'On a fixed schedule';

  @override
  String get dailyFixedSubtitle =>
      'Repeats every N days since last scheduled (e.g. every 3 days)';

  @override
  String get dailyCompletionRelativeTitle => 'Based on when last completed';

  @override
  String get dailyCompletionRelativeSubtitle =>
      'Repeats N days after you finish it (e.g. 3 days after completed)';

  @override
  String get weeklyFixedTitle => 'On fixed days of the week';

  @override
  String get weeklyFixedSubtitle =>
      'Repeats on specific weekdays (e.g. every Monday & Friday)';

  @override
  String get weeklyCompletionRelativeTitle => 'Based on when last completed';

  @override
  String get weeklyCompletionRelativeSubtitle =>
      'Repeats N weeks after you finish it (e.g. 2 weeks after completed)';

  @override
  String get monthlyFixedDayTitle => 'On a fixed day of the month';

  @override
  String get monthlyFixedDaySubtitle =>
      'Repeats on a specific calendar day (e.g. on the 15th of the month)';

  @override
  String get monthlyNthWeekdayTitle => 'On a specific weekday of the month';

  @override
  String get monthlyNthWeekdaySubtitle =>
      'Repeats on a relative weekday (e.g. on the second Tuesday)';

  @override
  String get monthlyCompletionRelativeTitle => 'Based on when last completed';

  @override
  String get monthlyCompletionRelativeSubtitle =>
      'Repeats N months after you finish it (e.g. 1 month after completed)';

  @override
  String get yearlyFixedTitle => 'On a fixed date of the year';

  @override
  String get yearlyFixedSubtitle =>
      'Repeats on a specific calendar date (e.g. every October 12th)';

  @override
  String get yearlyCompletionRelativeTitle => 'Based on when last completed';

  @override
  String get yearlyCompletionRelativeSubtitle =>
      'Repeats N years after you finish it (e.g. 1 year after completed)';

  @override
  String get dayOfLabel => 'Day of';

  @override
  String get timeLabel => 'Time';

  @override
  String get adjustOffsetLabel => 'Adjust Offset';

  @override
  String get oneDayAfterLabel => '1 day after';

  @override
  String get oneDayBeforeLabel => '1 day before';

  @override
  String nDaysLaterLabel(int count) {
    return '$count days later';
  }

  @override
  String nDaysBeforeLabel(int count) {
    return '$count days before';
  }

  @override
  String get familyNameRequiredError => 'Please enter a family name';

  @override
  String get emailRequiredError => 'Please enter an email address';

  @override
  String get emailInvalidError => 'Please enter a valid email address';

  @override
  String get practiceTaskTitle0 => 'Water the Houseplants';

  @override
  String get practiceTaskDesc0 => 'Give them just enough water.';

  @override
  String get practiceTaskTitle1 => 'Take out the Trash';

  @override
  String get practiceTaskDesc1 => 'Don\'t forget the recycling.';

  @override
  String get practiceTaskTitle2 => 'Wash the Dishes';

  @override
  String get practiceTaskDesc2 => 'Clean the pots and pans first.';

  @override
  String get practiceTaskTitle3 => 'Mow the Lawn';

  @override
  String get practiceTaskDesc3 => 'Trim the edges too.';

  @override
  String get practiceTaskTitle4 => 'Feed the Dog';

  @override
  String get practiceTaskDesc4 => 'Make sure he has fresh water.';

  @override
  String get practiceTaskTitle5 => 'Vacuum the Living Room';

  @override
  String get practiceTaskDesc5 => 'Get under the couch.';

  @override
  String get practiceTaskTitle6 => 'Clean the Attic';

  @override
  String get practiceTaskDesc6 => 'Sort the old boxes.';

  @override
  String get practiceTaskTitle7 => 'Fold the Laundry';

  @override
  String get practiceTaskDesc7 => 'Fold them neatly and put them away.';

  @override
  String get practiceTaskTitle8 => 'Dust the Shelves';

  @override
  String get practiceTaskDesc8 => 'Use a microfiber cloth.';

  @override
  String get practiceTaskTitle9 => 'Buy Groceries';

  @override
  String get practiceTaskDesc9 => 'Milk, eggs, and bread.';

  @override
  String get preferNewerTitle => 'Prefer Newer';

  @override
  String get preferNewerDesc =>
      'Only the latest occurrence remains active. Older missed occurrences are automatically skipped so you can start fresh.';

  @override
  String get preferOlderTitle => 'Prefer Older';

  @override
  String get preferOlderDesc =>
      'Only the oldest unresolved occurrence remains active. Subsequent occurrences are skipped until it is completed.';

  @override
  String get stackPolicyTitle => 'Stack';

  @override
  String get stackPolicyDesc =>
      'Keep all occurrences active. Missed occurrences accumulate in a backlog and must be completed individually.';

  @override
  String get autoDismissPolicyTitle => 'Auto-Dismiss';

  @override
  String get autoDismissPolicyDesc =>
      'Occurrences accumulate but are automatically dismissed/skipped after a configurable grace period.';

  @override
  String get monShort => 'Mon';

  @override
  String get tueShort => 'Tue';

  @override
  String get wedTodayShort => 'Wed (Today)';

  @override
  String get activeLabel => 'Active';

  @override
  String get expiredLabel => 'Expired';

  @override
  String get skippedLabel => 'Skipped';

  @override
  String get pastTabLabel => 'Past';

  @override
  String get currentTabLabel => 'Current';

  @override
  String get futureTabLabel => 'Future';

  @override
  String get noCurrentOccurrencesPlaceholder => 'No active occurrences.';
}
