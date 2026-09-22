import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';

/// Global admin content filters: language + league.
class AdminLocaleScope extends InheritedWidget {
  const AdminLocaleScope({
    super.key,
    required this.locale,
    required this.league,
    required super.child,
  });

  final String locale;
  final LeagueTier league;

  static String of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminLocaleScope>();
    return scope?.locale ?? GameLocale.tr.id;
  }

  static LeagueTier leagueOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminLocaleScope>();
    return scope?.league ?? LeagueTier.bronze;
  }

  @override
  bool updateShouldNotify(AdminLocaleScope oldWidget) =>
      oldWidget.locale != locale || oldWidget.league != league;
}
