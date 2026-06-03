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

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String everyNDays(int count);

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

  /// No description provided for @rolloverLabel.
  ///
  /// In en, this message translates to:
  /// **'Rollover (Push to Next Day)'**
  String get rolloverLabel;

  /// No description provided for @rolloverDescription.
  ///
  /// In en, this message translates to:
  /// **'Overdue task rolls forward to today and remains overdue until completed.'**
  String get rolloverDescription;

  /// No description provided for @skipLabel.
  ///
  /// In en, this message translates to:
  /// **'Skip (Drop Occurrence)'**
  String get skipLabel;

  /// No description provided for @skipDescription.
  ///
  /// In en, this message translates to:
  /// **'Overdue task is automatically skipped, logged in history, and rescheduled.'**
  String get skipDescription;

  /// No description provided for @shiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift Schedule (Push Out Future Dates)'**
  String get shiftLabel;

  /// No description provided for @shiftDescription.
  ///
  /// In en, this message translates to:
  /// **'Next occurrence is calculated relative to when the task was completed late.'**
  String get shiftDescription;

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
  /// **'Day of Month (1-28, or -1 to -28)'**
  String get dayOfMonthFieldLabel;

  /// No description provided for @dayOfMonthValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid day number: 1 to 28, or -1 to -28'**
  String get dayOfMonthValidationError;

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
