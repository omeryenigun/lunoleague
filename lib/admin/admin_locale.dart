import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';

/// Global admin content filters: language + league.
class AdminLocaleScope extends InheritedWidget {
  const AdminLocaleScope({
    super.key,
    required this.locale,
    required this.league,
    this.listLength,
    required super.child,
  });

  final String locale;
  final LeagueTier league;

  /// 3 or 4 lists short Grid words. Null follows the selected league length.
  final int? listLength;

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

  static int wordLengthOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminLocaleScope>();
    return scope?.listLength ?? scope?.league.wordLength ?? LeagueTier.bronze.wordLength;
  }

  @override
  bool updateShouldNotify(AdminLocaleScope oldWidget) =>
      oldWidget.locale != locale ||
      oldWidget.league != league ||
      oldWidget.listLength != listLength;
}
