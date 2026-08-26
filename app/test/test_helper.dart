import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart' as gt;
import 'package:nothing_ever_happens/l10n/app_localizations.dart';
import 'package:nothing_ever_happens/logic/user_settings_repository.dart';
import 'package:nothing_ever_happens/logic/task_repository.dart';
import 'package:nothing_ever_happens/logic/user_settings.dart';
import 'package:nothing_ever_happens/logic/subscription_service.dart';

class FakeSubscriptionService extends SubscriptionService {
  FakeSubscriptionService(super.ref, SubscriptionTier tier) {
    state = SubscriptionState(tier: tier);
  }
}

final List<Override> defaultTestOverrides = [
  userSettingsProvider.overrideWith(
    (ref) => Stream.value(UserSettings(hoursAvailable: 8.0)),
  ),
  taskSchedulesProvider.overrideWith((ref) => const Stream.empty()),
  taskInstancesProvider.overrideWith((ref) => const Stream.empty()),
];

/// Wraps the widget under test in MaterialApp with all localization delegates.
///
/// This resolves missing localization contexts in standard widget tests.
Widget buildTestableWidget({required Widget child, Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('es')],
    home: child,
  );
}

/// A wrapper for golden tests that automatically injects the localization delegates and supported locales.
gt.WidgetWrapper l10nMaterialAppWrapper({
  TargetPlatform platform = TargetPlatform.android,
  Iterable<LocalizationsDelegate<dynamic>>? localizations,
  NavigatorObserver? navigatorObserver,
  Iterable<Locale>? localeOverrides,
  ThemeData? theme,
}) {
  return gt.materialAppWrapper(
    platform: platform,
    localizations: localizations ?? AppLocalizations.localizationsDelegates,
    navigatorObserver: navigatorObserver,
    localeOverrides: localeOverrides ?? AppLocalizations.supportedLocales,
    theme: theme,
  );
}
