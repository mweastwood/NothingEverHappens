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
