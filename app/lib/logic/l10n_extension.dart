import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppLocalizationsDateLists on AppLocalizations {
  /// Localized full month names (January..December, 0-indexed).
  List<String> get monthNames => [
    monthJanuary,
    monthFebruary,
    monthMarch,
    monthApril,
    monthMay,
    monthJune,
    monthJuly,
    monthAugust,
    monthSeptember,
    monthOctober,
    monthNovember,
    monthDecember,
  ];

  /// Localized full weekday names (Monday..Sunday, 0-indexed).
  List<String> get weekdayNames => [
    weekdayMonday,
    weekdayTuesday,
    weekdayWednesday,
    weekdayThursday,
    weekdayFriday,
    weekdaySaturday,
    weekdaySunday,
  ];
}
