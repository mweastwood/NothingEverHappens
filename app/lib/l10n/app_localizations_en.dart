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
}
