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
  String everyNDays(int count) {
    return 'Every $count days';
  }

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
  String get rolloverLabel => 'Rollover (Push to Next Day)';

  @override
  String get rolloverDescription =>
      'Overdue task rolls forward to today and remains overdue until completed.';

  @override
  String get skipLabel => 'Skip (Drop Occurrence)';

  @override
  String get skipDescription =>
      'Overdue task is automatically skipped, logged in history, and rescheduled.';

  @override
  String get shiftLabel => 'Shift Schedule (Push Out Future Dates)';

  @override
  String get shiftDescription =>
      'Next occurrence is calculated relative to when the task was completed late.';

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
  String get dayOfMonthFieldLabel => 'Day of Month (1-28, or -1 to -28)';

  @override
  String get dayOfMonthValidationError =>
      'Please enter a valid day number: 1 to 28, or -1 to -28';

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
  String get everyYear => 'Every year';

  @override
  String everyNYears(int count) {
    return 'Every $count years';
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
  String get rolloverSimTip =>
      '### Rollover Policy\n\n**Behavior:** The task remains active and rolls forward to today, staying overdue. If completed late, it reschedules to the next occurrence day *based on the original schedule date* (not today).\n\n**Try this:**\n1. Tap **Advance 1 Day** once or twice to let the task go overdue.\n2. Tap the checkbox to complete it.\n3. Notice that it reschedules to the next consecutive day (which may still be overdue if you are multiple days behind!).';

  @override
  String get skipSimTip =>
      '### Skip Policy\n\n**Behavior:** Overdue tasks are automatically dropped/skipped. You don\'t need to complete or dismiss them manually. The system records a \'skipped\' entry in history and moves the schedule to the next upcoming occurrence.\n\n**Try this:**\n1. Tap **Advance 1 Day**.\n2. Look at the history logs below — the task was automatically skipped, and the schedule advanced. You never see overdue tasks piling up!';

  @override
  String get shiftSimTip =>
      '### Shift Policy\n\n**Behavior:** Next occurrence is calculated relative to when you *actually completed* the task late, pushing out future dates. Unlike Rollover, it does not make you \'catch up\' on missed days.\n\n**Try this:**\n1. Tap **Advance 1 Day** twice so the task is overdue.\n2. Tap the checkbox to complete the active task.\n3. Notice the next scheduled occurrence shifts forward relative to today, rather than sticking to the original sequence.';

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
}
