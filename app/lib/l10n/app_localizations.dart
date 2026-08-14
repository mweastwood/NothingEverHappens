import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nothing Ever Happens'**
  String get appName;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error Occurred'**
  String get errorOccurred;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please share this error code with the developer:'**
  String get somethingWentWrong;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details:'**
  String get details;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @pleaseSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get pleaseSignInToContinue;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @tasksTab.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTab;

  /// No description provided for @scheduleTab.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTab;

  /// No description provided for @dashboardTab.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTab;

  /// No description provided for @capacityPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust your weekly capacity'**
  String get capacityPromptTitle;

  /// No description provided for @capacityPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your available hours for the upcoming days.'**
  String get capacityPromptSubtitle;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @addTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTaskTooltip;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @editTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTaskTitle;

  /// No description provided for @newTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTaskTitle;

  /// No description provided for @titleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleFieldLabel;

  /// No description provided for @titleRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get titleRequiredError;

  /// No description provided for @descriptionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionFieldLabel;

  /// No description provided for @estimatedEffortFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated Effort (Minutes)'**
  String get estimatedEffortFieldLabel;

  /// No description provided for @estimatedEffortHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional. Enter the estimated time in minutes.'**
  String get estimatedEffortHelper;

  /// No description provided for @estimatedEffortValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a positive number of minutes'**
  String get estimatedEffortValidationError;

  /// Label for estimated effort display
  ///
  /// In en, this message translates to:
  /// **'Estimated Effort: {duration}'**
  String estimatedEffortLabel(String duration);

  /// No description provided for @scheduleHeader.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleHeader;

  /// No description provided for @oneOffLabel.
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get oneOffLabel;

  /// No description provided for @dailyLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyLabel;

  /// No description provided for @weeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weeklyLabel;

  /// No description provided for @discardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @selectAtLeastOneDayError.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one day of the week'**
  String get selectAtLeastOneDayError;

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due: '**
  String get dueLabel;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @dueWithoutColon.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dueWithoutColon;

  /// No description provided for @dueDescription.
  ///
  /// In en, this message translates to:
  /// **'When does this task need to be completed before it should be considered overdue?'**
  String get dueDescription;

  /// No description provided for @advancedHeader.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedHeader;

  /// No description provided for @snoozeUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Snooze Until: '**
  String get snoozeUntilLabel;

  /// No description provided for @snoozeUntilDescription.
  ///
  /// In en, this message translates to:
  /// **'The task will be hidden from your primary list of tasks until this time.'**
  String get snoozeUntilDescription;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDateLabel;

  /// No description provided for @intervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get intervalLabel;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String everyNDays(int count);

  /// No description provided for @everyNDaysSinceLastScheduled.
  ///
  /// In en, this message translates to:
  /// **'Every {count} day(s) (since last scheduled)'**
  String everyNDaysSinceLastScheduled(int count);

  /// No description provided for @everyNDaysSinceLastCompletion.
  ///
  /// In en, this message translates to:
  /// **'Every {count} day(s) (since last completion)'**
  String everyNDaysSinceLastCompletion(int count);

  /// No description provided for @everyNWeeksSinceLastScheduled.
  ///
  /// In en, this message translates to:
  /// **'Every {count} week(s) (since last scheduled)'**
  String everyNWeeksSinceLastScheduled(int count);

  /// No description provided for @everyNWeeksSinceLastCompletion.
  ///
  /// In en, this message translates to:
  /// **'Every {count} week(s) (since last completion)'**
  String everyNWeeksSinceLastCompletion(int count);

  /// No description provided for @daysIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Days Interval'**
  String get daysIntervalLabel;

  /// No description provided for @daysIntervalHelper.
  ///
  /// In en, this message translates to:
  /// **'E.g., 1 for every day, 2 for every other day'**
  String get daysIntervalHelper;

  /// No description provided for @weeksIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Weeks Interval'**
  String get weeksIntervalLabel;

  /// No description provided for @weeksIntervalHelper.
  ///
  /// In en, this message translates to:
  /// **'E.g., 1 for every week'**
  String get weeksIntervalHelper;

  /// No description provided for @repeatsOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats on'**
  String get repeatsOnLabel;

  /// No description provided for @dailyOccurrencesHeader.
  ///
  /// In en, this message translates to:
  /// **'Daily Occurrences'**
  String get dailyOccurrencesHeader;

  /// No description provided for @startTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTimeLabel;

  /// No description provided for @dueTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Due Time'**
  String get dueTimeLabel;

  /// No description provided for @notificationTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Time'**
  String get notificationTimeLabel;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @clearNotificationTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear notification time'**
  String get clearNotificationTimeTooltip;

  /// No description provided for @removeTimeSlotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove time slot'**
  String get removeTimeSlotTooltip;

  /// No description provided for @addTimeSlotButton.
  ///
  /// In en, this message translates to:
  /// **'Add Time Slot'**
  String get addTimeSlotButton;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add one!'**
  String get noTasksYet;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @noRecurringTasksScheduled.
  ///
  /// In en, this message translates to:
  /// **'No recurring tasks scheduled'**
  String get noRecurringTasksScheduled;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied task to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @deleteTaskConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Task?'**
  String get deleteTaskConfirmTitle;

  /// No description provided for @deleteTaskConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This action will permanently remove the task.'**
  String deleteTaskConfirmBody(String title);

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @editScheduleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Schedule'**
  String get editScheduleTooltip;

  /// No description provided for @deleteTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTaskTooltip;

  /// No description provided for @dailyRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get dailyRecurrence;

  /// No description provided for @weeklyRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weeklyRecurrence;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get everyWeek;

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String everyNWeeks(int count);

  /// No description provided for @startingDate.
  ///
  /// In en, this message translates to:
  /// **'Starting: {date}'**
  String startingDate(String date);

  /// No description provided for @onDaysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'On: {days}'**
  String onDaysOfWeek(String days);

  /// No description provided for @missedPolicyHeader.
  ///
  /// In en, this message translates to:
  /// **'Missed Occurrence Policy'**
  String get missedPolicyHeader;

  /// No description provided for @missedPolicyHelper.
  ///
  /// In en, this message translates to:
  /// **'Define what happens if a recurring task is not completed by its due time.'**
  String get missedPolicyHelper;

  /// No description provided for @stackLabel.
  ///
  /// In en, this message translates to:
  /// **'Stack/Overlap (Allow Concurrency)'**
  String get stackLabel;

  /// No description provided for @stackDescription.
  ///
  /// In en, this message translates to:
  /// **'Missed occurrences remain active, letting multiple instances stack up.'**
  String get stackDescription;

  /// No description provided for @monthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyLabel;

  /// No description provided for @yearlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearlyLabel;

  /// No description provided for @repeatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeating'**
  String get repeatingLabel;

  /// No description provided for @sinceLastScheduledLabel.
  ///
  /// In en, this message translates to:
  /// **'Since last scheduled'**
  String get sinceLastScheduledLabel;

  /// No description provided for @sinceLastCompletionLabel.
  ///
  /// In en, this message translates to:
  /// **'Since last completion'**
  String get sinceLastCompletionLabel;

  /// No description provided for @intervalTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Interval Type'**
  String get intervalTypeLabel;

  /// No description provided for @startRecurrenceDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Recurrence Date'**
  String get startRecurrenceDateLabel;

  /// No description provided for @addNotificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Add notification'**
  String get addNotificationLabel;

  /// No description provided for @dayOfMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of Month'**
  String get dayOfMonthLabel;

  /// No description provided for @nthDayOfWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Nth Day of Week'**
  String get nthDayOfWeekLabel;

  /// No description provided for @monthlyRecurrenceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurrence Rule'**
  String get monthlyRecurrenceTypeLabel;

  /// No description provided for @monthsIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Months Interval'**
  String get monthsIntervalLabel;

  /// No description provided for @yearsIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Years Interval'**
  String get yearsIntervalLabel;

  /// No description provided for @dayOfMonthFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of Month'**
  String get dayOfMonthFieldLabel;

  /// No description provided for @dayOfMonthValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid day number: 1 to 28'**
  String get dayOfMonthValidationError;

  /// No description provided for @monthlyFromStart.
  ///
  /// In en, this message translates to:
  /// **'From start of month'**
  String get monthlyFromStart;

  /// No description provided for @monthlyFromEnd.
  ///
  /// In en, this message translates to:
  /// **'From end of month'**
  String get monthlyFromEnd;

  /// No description provided for @dayOfMonthStepperLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayOfMonthStepperLabel;

  /// No description provided for @nthOccurrenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Occurrence'**
  String get nthOccurrenceLabel;

  /// No description provided for @firstOccurrence.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get firstOccurrence;

  /// No description provided for @secondOccurrence.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get secondOccurrence;

  /// No description provided for @thirdOccurrence.
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get thirdOccurrence;

  /// No description provided for @fourthOccurrence.
  ///
  /// In en, this message translates to:
  /// **'4th'**
  String get fourthOccurrence;

  /// No description provided for @lastOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get lastOccurrence;

  /// No description provided for @dayOfWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of Week'**
  String get dayOfWeekLabel;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthLabel;

  /// No description provided for @dayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayLabel;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @everyNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String everyNMonths(int count);

  /// No description provided for @everyNMonthsSinceLastScheduled.
  ///
  /// In en, this message translates to:
  /// **'Every {count} month(s) (since last scheduled)'**
  String everyNMonthsSinceLastScheduled(int count);

  /// No description provided for @everyNMonthsSinceLastCompletion.
  ///
  /// In en, this message translates to:
  /// **'Every {count} month(s) (since last completion)'**
  String everyNMonthsSinceLastCompletion(int count);

  /// No description provided for @everyYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get everyYear;

  /// No description provided for @everyNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {count} years'**
  String everyNYears(int count);

  /// No description provided for @everyNYearsSinceLastScheduled.
  ///
  /// In en, this message translates to:
  /// **'Every {count} year(s) (since last scheduled)'**
  String everyNYearsSinceLastScheduled(int count);

  /// No description provided for @everyNYearsSinceLastCompletion.
  ///
  /// In en, this message translates to:
  /// **'Every {count} year(s) (since last completion)'**
  String everyNYearsSinceLastCompletion(int count);

  /// No description provided for @dayOfMonthOnDay.
  ///
  /// In en, this message translates to:
  /// **'On day {day}'**
  String dayOfMonthOnDay(Object day);

  /// No description provided for @dayOfMonthFromEnd.
  ///
  /// In en, this message translates to:
  /// **'On the {day} day from the end'**
  String dayOfMonthFromEnd(Object day);

  /// No description provided for @repeatsOnDayOfMonthHelp.
  ///
  /// In en, this message translates to:
  /// **'Repeats on the {day} day of the month.'**
  String repeatsOnDayOfMonthHelp(Object day);

  /// No description provided for @repeatsOnDayFromEndHelp.
  ///
  /// In en, this message translates to:
  /// **'Repeats on the {day} day from the end of the month.'**
  String repeatsOnDayFromEndHelp(Object day);

  /// No description provided for @repeatsOnNthWeekdayHelp.
  ///
  /// In en, this message translates to:
  /// **'Repeats on the {occurrence} {dayOfWeek} of the month.'**
  String repeatsOnNthWeekdayHelp(Object dayOfWeek, Object occurrence);

  /// No description provided for @nthDayOfWeekOccurrence.
  ///
  /// In en, this message translates to:
  /// **'On the {occurrence} {dayOfWeek}'**
  String nthDayOfWeekOccurrence(Object dayOfWeek, Object occurrence);

  /// No description provided for @yearlyOn.
  ///
  /// In en, this message translates to:
  /// **'On: {month} {day}'**
  String yearlyOn(Object day, Object month);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @hoursAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available Hours per Day'**
  String get hoursAvailableLabel;

  /// No description provided for @hoursAvailableHelper.
  ///
  /// In en, this message translates to:
  /// **'Number of hours available for agile-based scheduling.'**
  String get hoursAvailableHelper;

  /// No description provided for @hoursAvailableValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number between 0 and 24'**
  String get hoursAvailableValidationError;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get settingsSavedSuccessfully;

  /// No description provided for @showPendingTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Show Pending Tasks'**
  String get showPendingTasksLabel;

  /// No description provided for @showPendingTasksHelper.
  ///
  /// In en, this message translates to:
  /// **'Show tasks on the main list whose start time is in the future.'**
  String get showPendingTasksHelper;

  /// No description provided for @showLastSpawnedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Show Last Spawned Date'**
  String get showLastSpawnedDateLabel;

  /// No description provided for @showLastSpawnedDateHelper.
  ///
  /// In en, this message translates to:
  /// **'Display the last spawned date on each task schedule card for debugging.'**
  String get showLastSpawnedDateHelper;

  /// No description provided for @debugDiagnosticsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug & Diagnostics'**
  String get debugDiagnosticsSectionTitle;

  /// No description provided for @debugDiagnosticsSectionHelper.
  ///
  /// In en, this message translates to:
  /// **'Export the complete local and remote app state as structured JSON for debugging with LLMs or support.'**
  String get debugDiagnosticsSectionHelper;

  /// No description provided for @exportDebugStateButton.
  ///
  /// In en, this message translates to:
  /// **'Export Debug State (LLM JSON)'**
  String get exportDebugStateButton;

  /// No description provided for @debugStateCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Debug state JSON copied to clipboard.'**
  String get debugStateCopiedToClipboard;

  /// No description provided for @debugStateShareSubject.
  ///
  /// In en, this message translates to:
  /// **'App State Debug Export'**
  String get debugStateShareSubject;

  /// No description provided for @debugStateShareText.
  ///
  /// In en, this message translates to:
  /// **'Debug app state JSON export for NothingEverHappens.'**
  String get debugStateShareText;

  /// No description provided for @pendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingBadge;

  /// No description provided for @familyTab.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyTab;

  /// No description provided for @familyScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyScreenTitle;

  /// No description provided for @createFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get createFamilyTitle;

  /// No description provided for @createFamilyButton.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get createFamilyButton;

  /// No description provided for @familyUnitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Name'**
  String get familyUnitNameLabel;

  /// No description provided for @inviteMemberButton.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMemberButton;

  /// No description provided for @inviteMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Family Member'**
  String get inviteMemberTitle;

  /// No description provided for @inviteMemberEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get inviteMemberEmailLabel;

  /// No description provided for @inviteMemberRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get inviteMemberRoleLabel;

  /// No description provided for @parentRole.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parentRole;

  /// No description provided for @nonParentRole.
  ///
  /// In en, this message translates to:
  /// **'Non-Parent'**
  String get nonParentRole;

  /// No description provided for @pendingInvitesHeader.
  ///
  /// In en, this message translates to:
  /// **'Pending Invites'**
  String get pendingInvitesHeader;

  /// No description provided for @acceptInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptInviteButton;

  /// No description provided for @declineInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineInviteButton;

  /// No description provided for @leaveFamilyButton.
  ///
  /// In en, this message translates to:
  /// **'Leave Family'**
  String get leaveFamilyButton;

  /// No description provided for @membersHeader.
  ///
  /// In en, this message translates to:
  /// **'Family Members'**
  String get membersHeader;

  /// No description provided for @familyMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String familyMembersCount(int count);

  /// No description provided for @notInFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'You are not currently in a family unit. You can create a new family or accept a pending invitation below.'**
  String get notInFamilyBody;

  /// No description provided for @noPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations'**
  String get noPendingInvites;

  /// No description provided for @inviteSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent successfully'**
  String get inviteSentSuccess;

  /// No description provided for @outstandingInvitesHeader.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Invitations'**
  String get outstandingInvitesHeader;

  /// No description provided for @revokeInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeInviteButton;

  /// No description provided for @inviteRevokedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invitation revoked successfully'**
  String get inviteRevokedSuccess;

  /// No description provided for @noOutstandingInvites.
  ///
  /// In en, this message translates to:
  /// **'No outstanding invitations'**
  String get noOutstandingInvites;

  /// No description provided for @revokeInviteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Invitation?'**
  String get revokeInviteConfirmTitle;

  /// No description provided for @revokeInviteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to revoke the invitation for {email}?'**
  String revokeInviteConfirmBody(String email);

  /// No description provided for @invitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name} ({email})'**
  String invitedBy(String name, String email);

  /// No description provided for @leaveFamilyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Family?'**
  String get leaveFamilyConfirmTitle;

  /// No description provided for @leaveFamilyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the family?'**
  String get leaveFamilyConfirmBody;

  /// No description provided for @taskPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriorityLabel;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @familyTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Task'**
  String get familyTaskLabel;

  /// No description provided for @familyTaskHelper.
  ///
  /// In en, this message translates to:
  /// **'Share this task with all family members.'**
  String get familyTaskHelper;

  /// No description provided for @personalTaskHelper.
  ///
  /// In en, this message translates to:
  /// **'Only visible to you.'**
  String get personalTaskHelper;

  /// No description provided for @viewTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'View Task'**
  String get viewTaskTitle;

  /// No description provided for @onlyParentsCanEditFamilyTasks.
  ///
  /// In en, this message translates to:
  /// **'Only parents can edit family tasks'**
  String get onlyParentsCanEditFamilyTasks;

  /// No description provided for @sprintDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Sprint Dashboard'**
  String get sprintDashboardTitle;

  /// No description provided for @autoAllocateButton.
  ///
  /// In en, this message translates to:
  /// **'Auto-Allocate Chores'**
  String get autoAllocateButton;

  /// No description provided for @choresAllocatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chores auto-allocated successfully!'**
  String get choresAllocatedSuccess;

  /// No description provided for @removeFromCycleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from cycle'**
  String get removeFromCycleTooltip;

  /// No description provided for @addToCycleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to cycle'**
  String get addToCycleTooltip;

  /// No description provided for @backlogTab.
  ///
  /// In en, this message translates to:
  /// **'Backlog'**
  String get backlogTab;

  /// No description provided for @activeCycleTab.
  ///
  /// In en, this message translates to:
  /// **'Active Cycle'**
  String get activeCycleTab;

  /// No description provided for @weeklyCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly Capacity'**
  String get weeklyCapacityLabel;

  /// No description provided for @personalTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal Tasks: {effort} min'**
  String personalTasksLabel(int effort);

  /// No description provided for @familyChoresLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Chores: {effort} min'**
  String familyChoresLabel(int effort);

  /// No description provided for @remainingCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining Capacity: {effort} min'**
  String remainingCapacityLabel(int effort);

  /// No description provided for @noActiveTasks.
  ///
  /// In en, this message translates to:
  /// **'No active tasks in this cycle. Move some from the backlog!'**
  String get noActiveTasks;

  /// No description provided for @noBacklogTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks in the backlog.'**
  String get noBacklogTasks;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name}'**
  String assignedTo(String name);

  /// No description provided for @starTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle preference'**
  String get starTooltip;

  /// No description provided for @familyCapacityPool.
  ///
  /// In en, this message translates to:
  /// **'Family Capacity Pool'**
  String get familyCapacityPool;

  /// No description provided for @memberRemainingTotal.
  ///
  /// In en, this message translates to:
  /// **'{remaining} min remaining / {total} min total'**
  String memberRemainingTotal(int remaining, int total);

  /// No description provided for @memberPersonalChores.
  ///
  /// In en, this message translates to:
  /// **'Personal: {personal} min | Family Chores: {family} min'**
  String memberPersonalChores(int personal, int family);

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTooltip;

  /// No description provided for @helpTabInteractions.
  ///
  /// In en, this message translates to:
  /// **'Basic Task Completion'**
  String get helpTabInteractions;

  /// No description provided for @practiceHelpContent.
  ///
  /// In en, this message translates to:
  /// **'# Practice Basic Task Completion\n\nThere are two ways to complete a task:\n\n1. Tapping the checkbox on the left marks a task as complete.\n2. Tapping the x button on the right dismisses a task, indicating that you will not complete it (for any reason).\n\nUse the space below to practice marking tasks as completed or dismissed.'**
  String get practiceHelpContent;

  /// No description provided for @helpTabScheduling.
  ///
  /// In en, this message translates to:
  /// **'Task Scheduling'**
  String get helpTabScheduling;

  /// No description provided for @schedulingPlaygroundHelpContent.
  ///
  /// In en, this message translates to:
  /// **'# Practice Task Scheduling\n\nUse the controls below to configure different task schedules in real-time.\n\n- The **calendar grid** highlights the days on which the task will occur over a 3-month period (Current, Next, and Month After).\n- The **occurrences list** displays the next 10 calculated dates.\n\n*Try changing the interval, selecting different days of the week, or choosing different monthly/yearly options to see how occurrences update.*'**
  String get schedulingPlaygroundHelpContent;

  /// No description provided for @occurrenceAppears.
  ///
  /// In en, this message translates to:
  /// **'Appears: {dateTime}'**
  String occurrenceAppears(String dateTime);

  /// No description provided for @occurrenceDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {dateTime}'**
  String occurrenceDue(String dateTime);

  /// No description provided for @invalidIntervalError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid interval greater than 0'**
  String get invalidIntervalError;

  /// No description provided for @occurrencesHeader.
  ///
  /// In en, this message translates to:
  /// **'Next 10 Occurrences'**
  String get occurrencesHeader;

  /// No description provided for @noOccurrencesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No future occurrences scheduled. Ensure all inputs are valid.'**
  String get noOccurrencesPlaceholder;

  /// No description provided for @pastOccurrencesHeader.
  ///
  /// In en, this message translates to:
  /// **'Last 10 Occurrences'**
  String get pastOccurrencesHeader;

  /// No description provided for @noPastOccurrencesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No past occurrences.'**
  String get noPastOccurrencesPlaceholder;

  /// No description provided for @occurrenceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed: {dateTime}'**
  String occurrenceCompleted(String dateTime);

  /// No description provided for @occurrenceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get occurrenceSkipped;

  /// No description provided for @occurrenceMissed.
  ///
  /// In en, this message translates to:
  /// **'Overdue (Due: {dateTime})'**
  String occurrenceMissed(String dateTime);

  /// No description provided for @occurrenceActive.
  ///
  /// In en, this message translates to:
  /// **'Active (Due: {dateTime})'**
  String occurrenceActive(String dateTime);

  /// No description provided for @visualCalendarGridHeader.
  ///
  /// In en, this message translates to:
  /// **'Visual Calendar Grid'**
  String get visualCalendarGridHeader;

  /// No description provided for @dayIsRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Day is required'**
  String get dayIsRequiredError;

  /// No description provided for @dayMustBeBetweenError.
  ///
  /// In en, this message translates to:
  /// **'Day must be between 1 and {max}'**
  String dayMustBeBetweenError(int max);

  /// No description provided for @calculationError.
  ///
  /// In en, this message translates to:
  /// **'Calculation error: {error}'**
  String calculationError(String error);

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @weekdayHeaderMonday.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayHeaderMonday;

  /// No description provided for @weekdayHeaderTuesday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayHeaderTuesday;

  /// No description provided for @weekdayHeaderWednesday.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayHeaderWednesday;

  /// No description provided for @weekdayHeaderThursday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayHeaderThursday;

  /// No description provided for @weekdayHeaderFriday.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayHeaderFriday;

  /// No description provided for @weekdayHeaderSaturday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayHeaderSaturday;

  /// No description provided for @weekdayHeaderSunday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayHeaderSunday;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @helpTabMissedPolicies.
  ///
  /// In en, this message translates to:
  /// **'Missed Policies'**
  String get helpTabMissedPolicies;

  /// No description provided for @missedPoliciesIntro.
  ///
  /// In en, this message translates to:
  /// **'### Missed Occurrence Policies\n\nWhen a recurring task is not completed by its due time, the app applies a **Missed Occurrence Policy** to handle the overdue instance.\n\nUse the simulator below to see how each policy handles overdue tasks over time.'**
  String get missedPoliciesIntro;

  /// No description provided for @stackSimTip.
  ///
  /// In en, this message translates to:
  /// **'### Stack Policy\n\n**Behavior:** Missed occurrences remain active and spawn a separate task instance for each day, letting multiple instances stack up. They all appear on your task list concurrently until completed or dismissed.\n\n**Try this:**\n1. Tap **Advance 1 Day** 3 times.\n2. Notice that 3 separate tasks appear on your list (one for each missed day).\n3. Complete or dismiss them individually to clear the backlog.'**
  String get stackSimTip;

  /// No description provided for @advanceDayButton.
  ///
  /// In en, this message translates to:
  /// **'Advance 1 Day'**
  String get advanceDayButton;

  /// No description provided for @resetSimButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Simulation'**
  String get resetSimButton;

  /// No description provided for @simulatedTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Simulated Today: {date}'**
  String simulatedTodayLabel(String date);

  /// No description provided for @activeTasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Simulated Tasks ({count})'**
  String activeTasksHeader(int count);

  /// No description provided for @historyLogHeader.
  ///
  /// In en, this message translates to:
  /// **'Simulation History Log'**
  String get historyLogHeader;

  /// No description provided for @undoButton.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoButton;

  /// No description provided for @actionUndone.
  ///
  /// In en, this message translates to:
  /// **'Action undone'**
  String get actionUndone;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed \"{title}\"'**
  String taskCompleted(String title);

  /// No description provided for @taskDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed \"{title}\"'**
  String taskDismissed(String title);

  /// No description provided for @scheduleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\"'**
  String scheduleDeleted(String title);

  /// No description provided for @taskEditsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{title}\"'**
  String taskEditsSaved(String title);

  /// No description provided for @taskRestored.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" restored'**
  String taskRestored(String title);

  /// No description provided for @editsReverted.
  ///
  /// In en, this message translates to:
  /// **'Changes to \"{title}\" reverted'**
  String editsReverted(String title);

  /// No description provided for @dueTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Due Today at {time}'**
  String dueTodayAt(String time);

  /// No description provided for @overdueTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Overdue: Today at {time}'**
  String overdueTodayAt(String time);

  /// No description provided for @overdueYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Overdue: Yesterday at {time}'**
  String overdueYesterdayAt(String time);

  /// No description provided for @dueTomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Due Tomorrow at {time}'**
  String dueTomorrowAt(String time);

  /// No description provided for @dueAt.
  ///
  /// In en, this message translates to:
  /// **'Due {date} at {time}'**
  String dueAt(String date, String time);

  /// No description provided for @overdueAt.
  ///
  /// In en, this message translates to:
  /// **'Overdue: {date} at {time}'**
  String overdueAt(String date, String time);

  /// No description provided for @loadingBadge.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingBadge;

  /// No description provided for @assignedBadge.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assignedBadge;

  /// No description provided for @recurringLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringLabel;

  /// No description provided for @searchTasksPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search tasks...'**
  String get searchTasksPlaceholder;

  /// No description provided for @noTasksMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks found for \"{query}\"'**
  String noTasksMatching(String query);

  /// No description provided for @clearSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearchButton;

  /// No description provided for @presetWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get presetWeekdays;

  /// No description provided for @presetWeekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get presetWeekends;

  /// No description provided for @presetAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get presetAll;

  /// No description provided for @presetClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get presetClear;

  /// No description provided for @presetMonthSingular.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get presetMonthSingular;

  /// No description provided for @presetMonthPlural.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get presetMonthPlural;

  /// No description provided for @presetYearSingular.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get presetYearSingular;

  /// No description provided for @presetYearPlural.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get presetYearPlural;

  /// No description provided for @scheduleSortByLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get scheduleSortByLabel;

  /// No description provided for @showSortOptions.
  ///
  /// In en, this message translates to:
  /// **'Show sorting options'**
  String get showSortOptions;

  /// No description provided for @hideSortOptions.
  ///
  /// In en, this message translates to:
  /// **'Hide sorting options'**
  String get hideSortOptions;

  /// No description provided for @scheduleGridTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get scheduleGridTypeHeader;

  /// No description provided for @scheduleSortNextStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Start'**
  String get scheduleSortNextStartLabel;

  /// No description provided for @scheduleSortNextDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Due'**
  String get scheduleSortNextDueLabel;

  /// No description provided for @scheduleGridTimeWindowHeader.
  ///
  /// In en, this message translates to:
  /// **'Time Window'**
  String get scheduleGridTimeWindowHeader;

  /// No description provided for @scheduleGridActionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get scheduleGridActionsHeader;

  /// No description provided for @searchSchedulesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search schedules...'**
  String get searchSchedulesPlaceholder;

  /// No description provided for @noSchedulesMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching schedules found for \"{query}\"'**
  String noSchedulesMatching(String query);

  /// No description provided for @scheduleRequiredError.
  ///
  /// In en, this message translates to:
  /// **'At least one schedule is required.'**
  String get scheduleRequiredError;

  /// No description provided for @capacityDependentEffortRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Estimated effort is required for Capacity Dependent tasks.'**
  String get capacityDependentEffortRequiredError;

  /// No description provided for @familyTaskToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Task'**
  String get familyTaskToggleLabel;

  /// No description provided for @personalTaskToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal Task'**
  String get personalTaskToggleLabel;

  /// No description provided for @effortAndPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Effort and Priority'**
  String get effortAndPriorityLabel;

  /// No description provided for @addScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Add Schedule'**
  String get addScheduleButton;

  /// No description provided for @saveTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Save operation timed out. Please check your connection.'**
  String get saveTimeoutError;

  /// No description provided for @hoursSuffix.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hoursSuffix;

  /// No description provided for @futureOccurrencesLabel.
  ///
  /// In en, this message translates to:
  /// **'Future Occurrences'**
  String get futureOccurrencesLabel;

  /// No description provided for @preCreatedFutureTasksHelper.
  ///
  /// In en, this message translates to:
  /// **'Pre-created future tasks (1-10)'**
  String get preCreatedFutureTasksHelper;

  /// No description provided for @resetPracticeButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Practice'**
  String get resetPracticeButton;

  /// No description provided for @practiceTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Practice Tasks (1 remaining)} other{Practice Tasks ({count} remaining)}}'**
  String practiceTasksRemaining(int count);

  /// No description provided for @practiceTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed or dismissed!'**
  String get practiceTasksCompleted;

  /// No description provided for @practiceTasksResetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Reset Practice\" to try again.'**
  String get practiceTasksResetPrompt;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'Hour(s)'**
  String get unitHours;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'Day(s)'**
  String get unitDays;

  /// No description provided for @unitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Week(s)'**
  String get unitWeeks;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minute(s)'**
  String get unitMinutes;

  /// No description provided for @targetStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Start Time'**
  String get targetStartTimeLabel;

  /// No description provided for @selectMissedPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Missed Occurrence Policy'**
  String get selectMissedPolicyTitle;

  /// No description provided for @immediatelyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get immediatelyPolicy;

  /// No description provided for @oneHourPolicy.
  ///
  /// In en, this message translates to:
  /// **'1 Hour'**
  String get oneHourPolicy;

  /// No description provided for @sixHoursPolicy.
  ///
  /// In en, this message translates to:
  /// **'6 Hours'**
  String get sixHoursPolicy;

  /// No description provided for @twelveHoursPolicy.
  ///
  /// In en, this message translates to:
  /// **'12 Hours'**
  String get twelveHoursPolicy;

  /// No description provided for @twentyFourHoursPolicy.
  ///
  /// In en, this message translates to:
  /// **'24 Hours (1 Day)'**
  String get twentyFourHoursPolicy;

  /// No description provided for @customDurationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Custom Duration...'**
  String get customDurationPolicy;

  /// No description provided for @addNotificationButton.
  ///
  /// In en, this message translates to:
  /// **'Add notification'**
  String get addNotificationButton;

  /// No description provided for @selectDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Day'**
  String get selectDayTitle;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @fixedCalendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed Calendar'**
  String get fixedCalendarLabel;

  /// No description provided for @completionRelativeLabel.
  ///
  /// In en, this message translates to:
  /// **'Completion-Relative'**
  String get completionRelativeLabel;

  /// No description provided for @capacityDependentLabel.
  ///
  /// In en, this message translates to:
  /// **'Capacity Dependent'**
  String get capacityDependentLabel;

  /// No description provided for @capacityDependentTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on remaining capacity'**
  String get capacityDependentTitle;

  /// No description provided for @capacityDependentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled only if capacity permits, otherwise pushed forward day-by-day'**
  String get capacityDependentSubtitle;

  /// No description provided for @taskTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get taskTypeLabel;

  /// No description provided for @simulationPresetDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Preset (Feed Pets)'**
  String get simulationPresetDaily;

  /// No description provided for @simulationPresetWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly Preset (Mow Lawn)'**
  String get simulationPresetWeekly;

  /// No description provided for @simulatedTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Simulated Time: {time}'**
  String simulatedTimeLabel(String time);

  /// No description provided for @simulationOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 Hour'**
  String get simulationOneHour;

  /// No description provided for @simulationSixHours.
  ///
  /// In en, this message translates to:
  /// **'6 Hours'**
  String get simulationSixHours;

  /// No description provided for @simulationTwentyFourHours.
  ///
  /// In en, this message translates to:
  /// **'24 Hours'**
  String get simulationTwentyFourHours;

  /// No description provided for @noActivePlaygroundTasks.
  ///
  /// In en, this message translates to:
  /// **'No active tasks.'**
  String get noActivePlaygroundTasks;

  /// No description provided for @autoDismissPolicyHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String autoDismissPolicyHours(int count);

  /// No description provided for @missedPolicyDialogIntro.
  ///
  /// In en, this message translates to:
  /// **'In the examples shown below, assume we have a daily task that we didn\'t complete, check-off, or dismiss the task in any way on Monday or Tuesday. It is now Wednesday, so what should be done with the older tasks?'**
  String get missedPolicyDialogIntro;

  /// No description provided for @dismissAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'Dismiss After'**
  String get dismissAfterLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @presetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presetsLabel;

  /// No description provided for @presetDaySingular.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get presetDaySingular;

  /// No description provided for @presetDayPlural.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get presetDayPlural;

  /// No description provided for @presetWeekSingular.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get presetWeekSingular;

  /// No description provided for @presetWeekPlural.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get presetWeekPlural;

  /// No description provided for @taskAppearanceHelpText.
  ///
  /// In en, this message translates to:
  /// **'When does the task appear in your list of tasks?'**
  String get taskAppearanceHelpText;

  /// No description provided for @enableNotificationReminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable notification reminder'**
  String get enableNotificationReminderLabel;

  /// No description provided for @notificationWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification window'**
  String get notificationWindowLabel;

  /// No description provided for @repeatIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat Interval'**
  String get repeatIntervalLabel;

  /// No description provided for @completionRelativeSummary.
  ///
  /// In en, this message translates to:
  /// **'Completion-relative: every {val} {unit} @ {time}'**
  String completionRelativeSummary(String val, String unit, String time);

  /// No description provided for @oneOffSummary.
  ///
  /// In en, this message translates to:
  /// **'One-off on {date}'**
  String oneOffSummary(String date);

  /// No description provided for @dailySummary.
  ///
  /// In en, this message translates to:
  /// **'Daily, every {count} day(s)'**
  String dailySummary(String count);

  /// No description provided for @weeklySummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly, every {count} week(s) on {days}'**
  String weeklySummary(String count, String days);

  /// No description provided for @monthlySummaryDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly, every {count} month(s) on day {day}'**
  String monthlySummaryDay(String count, String day);

  /// No description provided for @monthlySummaryNth.
  ///
  /// In en, this message translates to:
  /// **'Monthly, every {count} month(s) on {occurrence} {weekday}'**
  String monthlySummaryNth(String count, String occurrence, String weekday);

  /// No description provided for @yearlySummary.
  ///
  /// In en, this message translates to:
  /// **'Yearly, every {count} year(s) on {month} {day}'**
  String yearlySummary(String count, String month, String day);

  /// No description provided for @customScheduleSummary.
  ///
  /// In en, this message translates to:
  /// **'Custom schedule'**
  String get customScheduleSummary;

  /// No description provided for @deleteScheduleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Schedule'**
  String get deleteScheduleTooltip;

  /// No description provided for @weekdayShortMonday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMonday;

  /// No description provided for @weekdayShortTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTuesday;

  /// No description provided for @weekdayShortWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWednesday;

  /// No description provided for @weekdayShortThursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThursday;

  /// No description provided for @weekdayShortFriday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFriday;

  /// No description provided for @weekdayShortSaturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSaturday;

  /// No description provided for @weekdayShortSunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSunday;

  /// No description provided for @monthShortJanuary.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthShortJanuary;

  /// No description provided for @monthShortFebruary.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthShortFebruary;

  /// No description provided for @monthShortMarch.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthShortMarch;

  /// No description provided for @monthShortApril.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthShortApril;

  /// No description provided for @monthShortMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthShortMay;

  /// No description provided for @monthShortJune.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthShortJune;

  /// No description provided for @monthShortJuly.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthShortJuly;

  /// No description provided for @monthShortAugust.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthShortAugust;

  /// No description provided for @monthShortSeptember.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthShortSeptember;

  /// No description provided for @monthShortOctober.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthShortOctober;

  /// No description provided for @monthShortNovember.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthShortNovember;

  /// No description provided for @monthShortDecember.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthShortDecember;

  /// No description provided for @completionRelativeHelpDaily.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day after the task was last completed.} other{{count} days after the task was last completed.}}'**
  String completionRelativeHelpDaily(int count);

  /// No description provided for @completionRelativeHelpWeekly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week after the task was last completed.} other{{count} weeks after the task was last completed.}}'**
  String completionRelativeHelpWeekly(int count);

  /// No description provided for @completionRelativeHelpMonthly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month after the task was last completed.} other{{count} months after the task was last completed.}}'**
  String completionRelativeHelpMonthly(int count);

  /// No description provided for @completionRelativeHelpYearly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year after the task was last completed.} other{{count} years after the task was last completed.}}'**
  String completionRelativeHelpYearly(int count);

  /// No description provided for @repeatsEveryDayHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Repeats every day starting {date}.} other{Repeats every {count} days starting {date}.}}'**
  String repeatsEveryDayHelp(int count, String date);

  /// No description provided for @repeatsEveryWeekHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Repeats every week starting {date}.} other{Repeats every {count} weeks starting {date}.}}'**
  String repeatsEveryWeekHelp(int count, String date);

  /// No description provided for @repeatsEveryMonthHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Repeats every month starting {date}.} other{Repeats every {count} months starting {date}.}}'**
  String repeatsEveryMonthHelp(int count, String date);

  /// No description provided for @repeatsEveryYearHelp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Repeats every year starting {date}.} other{Repeats every {count} years starting {date}.}}'**
  String repeatsEveryYearHelp(int count, String date);

  /// No description provided for @recurrenceTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'RECURRENCE TYPE'**
  String get recurrenceTypeHeader;

  /// No description provided for @dailyFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'On a fixed schedule'**
  String get dailyFixedTitle;

  /// No description provided for @dailyFixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats every N days since last scheduled (e.g. every 3 days)'**
  String get dailyFixedSubtitle;

  /// No description provided for @dailyCompletionRelativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on when last completed'**
  String get dailyCompletionRelativeTitle;

  /// No description provided for @dailyCompletionRelativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats N days after you finish it (e.g. 3 days after completed)'**
  String get dailyCompletionRelativeSubtitle;

  /// No description provided for @weeklyFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'On fixed days of the week'**
  String get weeklyFixedTitle;

  /// No description provided for @weeklyFixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats on specific weekdays (e.g. every Monday & Friday)'**
  String get weeklyFixedSubtitle;

  /// No description provided for @weeklyCompletionRelativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on when last completed'**
  String get weeklyCompletionRelativeTitle;

  /// No description provided for @weeklyCompletionRelativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats N weeks after you finish it (e.g. 2 weeks after completed)'**
  String get weeklyCompletionRelativeSubtitle;

  /// No description provided for @monthlyFixedDayTitle.
  ///
  /// In en, this message translates to:
  /// **'On a fixed day of the month'**
  String get monthlyFixedDayTitle;

  /// No description provided for @monthlyFixedDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats on a specific calendar day (e.g. on the 15th of the month)'**
  String get monthlyFixedDaySubtitle;

  /// No description provided for @monthlyNthWeekdayTitle.
  ///
  /// In en, this message translates to:
  /// **'On a specific weekday of the month'**
  String get monthlyNthWeekdayTitle;

  /// No description provided for @monthlyNthWeekdaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats on a relative weekday (e.g. on the second Tuesday)'**
  String get monthlyNthWeekdaySubtitle;

  /// No description provided for @monthlyCompletionRelativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on when last completed'**
  String get monthlyCompletionRelativeTitle;

  /// No description provided for @monthlyCompletionRelativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats N months after you finish it (e.g. 1 month after completed)'**
  String get monthlyCompletionRelativeSubtitle;

  /// No description provided for @yearlyFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'On a fixed date of the year'**
  String get yearlyFixedTitle;

  /// No description provided for @yearlyFixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats on a specific calendar date (e.g. every October 12th)'**
  String get yearlyFixedSubtitle;

  /// No description provided for @yearlyCompletionRelativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Based on when last completed'**
  String get yearlyCompletionRelativeTitle;

  /// No description provided for @yearlyCompletionRelativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats N years after you finish it (e.g. 1 year after completed)'**
  String get yearlyCompletionRelativeSubtitle;

  /// No description provided for @dayOfLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of'**
  String get dayOfLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @adjustOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjust Offset'**
  String get adjustOffsetLabel;

  /// No description provided for @oneDayAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'1 day after'**
  String get oneDayAfterLabel;

  /// No description provided for @oneDayBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get oneDayBeforeLabel;

  /// No description provided for @nDaysLaterLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} days later'**
  String nDaysLaterLabel(int count);

  /// No description provided for @nDaysBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} days before'**
  String nDaysBeforeLabel(int count);

  /// No description provided for @familyNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a family name'**
  String get familyNameRequiredError;

  /// No description provided for @emailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email address'**
  String get emailRequiredError;

  /// No description provided for @emailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get emailInvalidError;

  /// No description provided for @practiceTaskTitle0.
  ///
  /// In en, this message translates to:
  /// **'Water the Houseplants'**
  String get practiceTaskTitle0;

  /// No description provided for @practiceTaskDesc0.
  ///
  /// In en, this message translates to:
  /// **'Give them just enough water.'**
  String get practiceTaskDesc0;

  /// No description provided for @practiceTaskTitle1.
  ///
  /// In en, this message translates to:
  /// **'Take out the Trash'**
  String get practiceTaskTitle1;

  /// No description provided for @practiceTaskDesc1.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget the recycling.'**
  String get practiceTaskDesc1;

  /// No description provided for @practiceTaskTitle2.
  ///
  /// In en, this message translates to:
  /// **'Wash the Dishes'**
  String get practiceTaskTitle2;

  /// No description provided for @practiceTaskDesc2.
  ///
  /// In en, this message translates to:
  /// **'Clean the pots and pans first.'**
  String get practiceTaskDesc2;

  /// No description provided for @practiceTaskTitle3.
  ///
  /// In en, this message translates to:
  /// **'Mow the Lawn'**
  String get practiceTaskTitle3;

  /// No description provided for @practiceTaskDesc3.
  ///
  /// In en, this message translates to:
  /// **'Trim the edges too.'**
  String get practiceTaskDesc3;

  /// No description provided for @practiceTaskTitle4.
  ///
  /// In en, this message translates to:
  /// **'Feed the Dog'**
  String get practiceTaskTitle4;

  /// No description provided for @practiceTaskDesc4.
  ///
  /// In en, this message translates to:
  /// **'Make sure he has fresh water.'**
  String get practiceTaskDesc4;

  /// No description provided for @practiceTaskTitle5.
  ///
  /// In en, this message translates to:
  /// **'Vacuum the Living Room'**
  String get practiceTaskTitle5;

  /// No description provided for @practiceTaskDesc5.
  ///
  /// In en, this message translates to:
  /// **'Get under the couch.'**
  String get practiceTaskDesc5;

  /// No description provided for @practiceTaskTitle6.
  ///
  /// In en, this message translates to:
  /// **'Clean the Attic'**
  String get practiceTaskTitle6;

  /// No description provided for @practiceTaskDesc6.
  ///
  /// In en, this message translates to:
  /// **'Sort the old boxes.'**
  String get practiceTaskDesc6;

  /// No description provided for @practiceTaskTitle7.
  ///
  /// In en, this message translates to:
  /// **'Fold the Laundry'**
  String get practiceTaskTitle7;

  /// No description provided for @practiceTaskDesc7.
  ///
  /// In en, this message translates to:
  /// **'Fold them neatly and put them away.'**
  String get practiceTaskDesc7;

  /// No description provided for @practiceTaskTitle8.
  ///
  /// In en, this message translates to:
  /// **'Dust the Shelves'**
  String get practiceTaskTitle8;

  /// No description provided for @practiceTaskDesc8.
  ///
  /// In en, this message translates to:
  /// **'Use a microfiber cloth.'**
  String get practiceTaskDesc8;

  /// No description provided for @practiceTaskTitle9.
  ///
  /// In en, this message translates to:
  /// **'Buy Groceries'**
  String get practiceTaskTitle9;

  /// No description provided for @practiceTaskDesc9.
  ///
  /// In en, this message translates to:
  /// **'Milk, eggs, and bread.'**
  String get practiceTaskDesc9;

  /// No description provided for @preferNewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer Newer'**
  String get preferNewerTitle;

  /// No description provided for @preferNewerDesc.
  ///
  /// In en, this message translates to:
  /// **'Only the latest occurrence remains active. Older missed occurrences are automatically skipped so you can start fresh.'**
  String get preferNewerDesc;

  /// No description provided for @preferOlderTitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer Older'**
  String get preferOlderTitle;

  /// No description provided for @preferOlderDesc.
  ///
  /// In en, this message translates to:
  /// **'Only the oldest unresolved occurrence remains active. Subsequent occurrences are skipped until it is completed.'**
  String get preferOlderDesc;

  /// No description provided for @stackPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get stackPolicyTitle;

  /// No description provided for @stackPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep all occurrences active. Missed occurrences accumulate in a backlog and must be completed individually.'**
  String get stackPolicyDesc;

  /// No description provided for @autoDismissPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Dismiss'**
  String get autoDismissPolicyTitle;

  /// No description provided for @autoDismissPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'Occurrences accumulate but are automatically dismissed/skipped after a configurable grace period.'**
  String get autoDismissPolicyDesc;

  /// No description provided for @monShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get monShort;

  /// No description provided for @tueShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tueShort;

  /// No description provided for @wedTodayShort.
  ///
  /// In en, this message translates to:
  /// **'Wed (Today)'**
  String get wedTodayShort;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @expiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredLabel;

  /// No description provided for @skippedLabel.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skippedLabel;

  /// No description provided for @pastTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get pastTabLabel;

  /// No description provided for @currentTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentTabLabel;

  /// No description provided for @futureTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Future'**
  String get futureTabLabel;

  /// No description provided for @noCurrentOccurrencesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No active occurrences.'**
  String get noCurrentOccurrencesPlaceholder;

  /// No description provided for @skipIfNoCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Skip if capacity is exceeded'**
  String get skipIfNoCapacityLabel;

  /// No description provided for @skipIfNoCapacityHelper.
  ///
  /// In en, this message translates to:
  /// **'Skip this task occurrence if daily available capacity is exceeded'**
  String get skipIfNoCapacityHelper;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
