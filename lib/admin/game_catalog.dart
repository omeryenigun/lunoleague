import 'package:flutter/material.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

/// Screens a game exposes inside the shared admin shell.
enum AdminSection {
  overview,
  users,
  games,
  words,
  daily,
  league,
  shop,
  settings,
  scenes,
}

class AdminSectionInfo {
  const AdminSectionInfo({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const adminSectionInfo = <AdminSection, AdminSectionInfo>{
  AdminSection.overview: AdminSectionInfo(
    label: 'Özet',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  AdminSection.users: AdminSectionInfo(
    label: 'Kullanıcılar',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  AdminSection.games: AdminSectionInfo(
    label: 'Oyunlar',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports,
  ),
  AdminSection.words: AdminSectionInfo(
    label: 'Kelimeler',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  AdminSection.daily: AdminSectionInfo(
    label: 'Daily',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
  ),
  AdminSection.league: AdminSectionInfo(
    label: 'Lig',
    icon: Icons.emoji_events_outlined,
    selectedIcon: Icons.emoji_events,
  ),
  AdminSection.shop: AdminSectionInfo(
    label: 'Mağaza',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
  ),
  AdminSection.settings: AdminSectionInfo(
    label: 'Ayarlar',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
  ),
  AdminSection.scenes: AdminSectionInfo(
    label: 'Sahneler',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
  ),
};

/// One isolated game in the shared admin. Adding a game means a new
/// definition plus its own scoped store — never a shared box.
class AdminGameDefinition {
  const AdminGameDefinition({
    required this.id,
    required this.name,
    required this.summary,
    required this.icon,
    required this.sections,
    this.localeFilter = false,
    this.leagueFilter = false,
  });

  final String id;
  final String name;
  final String summary;
  final IconData icon;
  final List<AdminSection> sections;
  final bool localeFilter;
  final bool leagueFilter;

  /// Hive box and meta prefix. Example: `luno_league__users`.
  String get storePrefix => '${id}__';
}

class AdminGameCatalog {
  static const games = <AdminGameDefinition>[
    AdminGameDefinition(
      id: GameIds.lunoLeague,
      name: 'Luno League',
      summary: 'Kelime tahmin',
      icon: Icons.abc,
      localeFilter: true,
      leagueFilter: true,
      sections: [
        AdminSection.overview,
        AdminSection.users,
        AdminSection.games,
        AdminSection.words,
        AdminSection.daily,
        AdminSection.league,
        AdminSection.shop,
        AdminSection.settings,
      ],
    ),
    AdminGameDefinition(
      id: GameIds.lunoGrid,
      name: 'Luno Grid',
      summary: 'Harf çemberi',
      icon: Icons.grid_on,
      sections: [
        AdminSection.overview,
        AdminSection.users,
        AdminSection.games,
        AdminSection.words,
        AdminSection.daily,
        AdminSection.scenes,
        AdminSection.settings,
      ],
    ),
    AdminGameDefinition(
      id: GameIds.lunoFall,
      name: 'Luno Fall',
      summary: 'Harf yakalama',
      icon: Icons.waterfall_chart,
      sections: [
        AdminSection.overview,
        AdminSection.games,
        AdminSection.shop,
        AdminSection.settings,
      ],
    ),
  ];

  static AdminGameDefinition byId(String id) {
    return games.firstWhere(
      (game) => game.id == id,
      orElse: () => throw StateError('Kayıtlı oyun yok: $id'),
    );
  }
}
