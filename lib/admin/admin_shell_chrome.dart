import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/admin_hub.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';

const _sectionEmoji = <AdminSection, String>{
  AdminSection.overview: '📊',
  AdminSection.users: '👥',
  AdminSection.games: '🎮',
  AdminSection.words: '📖',
  AdminSection.daily: '📅',
  AdminSection.league: '🏆',
  AdminSection.shop: '🛒',
  AdminSection.settings: '⚙️',
  AdminSection.scenes: '🔳',
  AdminSection.staff: '🛡️',
};

const _menuGroups = <String, List<AdminSection>>{
  'Yönetim': [
    AdminSection.overview,
    AdminSection.users,
    AdminSection.games,
    AdminSection.words,
  ],
  'İçerik': [
    AdminSection.daily,
    AdminSection.league,
    AdminSection.shop,
    AdminSection.scenes,
  ],
  'Sistem': [
    AdminSection.settings,
    AdminSection.staff,
  ],
};

class AdminGameSidebar extends StatelessWidget {
  const AdminGameSidebar({
    super.key,
    required this.game,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.onLeave,
    this.account,
  });

  final AdminGameDefinition game;
  final List<AdminSection> sections;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onLeave;
  final AdminAccount? account;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminHubColors.bar,
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AdminHubColors.primary, AdminHubColors.teal],
                    ).createShader(bounds),
                    child: Text(
                      game.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    GameVersion.parse(gameVersionCode).label,
                    style: const TextStyle(
                      color: AdminHubColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x0DFFFFFF)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  for (final group in _menuGroups.entries)
                    ..._group(group.key, group.value),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _MenuRow(
                emoji: '🚪',
                label: 'Çıkış',
                selected: false,
                onTap: onLeave,
              ),
            ),
            if (account != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AdminHubColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x0DFFFFFF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AdminHubColors.primary,
                          child: Text(
                            account!.displayName.isEmpty
                                ? '?'
                                : account!.displayName
                                    .substring(0, 1)
                                    .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account!.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                account!.role.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminHubColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(String title, List<AdminSection> items) {
    final visible = [
      for (final section in items)
        if (sections.contains(section)) section,
    ];
    if (visible.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AdminHubColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ),
      for (final section in visible)
        _MenuRow(
          emoji: _sectionEmoji[section] ?? '•',
          label: adminSectionInfo[section]!.label,
          selected: sections[selected] == section,
          onTap: () => onSelect(sections.indexOf(section)),
        ),
    ];
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x266C3CE9) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AdminHubColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(21, 12, 24, 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminHubColors.primary
                        : const Color(0x0DFFFFFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AdminHubColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminGameTopBar extends StatelessWidget {
  const AdminGameTopBar({
    super.key,
    required this.game,
    required this.onLeave,
    this.showMenu,
    this.locale,
    this.onLocale,
    this.league,
    this.listLength,
    this.onLeagueLength,
  });

  final AdminGameDefinition game;
  final VoidCallback onLeave;
  final VoidCallback? showMenu;
  final String? locale;
  final ValueChanged<String>? onLocale;
  final LeagueTier? league;
  final int? listLength;
  final ValueChanged<int>? onLeagueLength;

  @override
  Widget build(BuildContext context) {
    final selectedLength = listLength ?? league?.wordLength;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AdminHubColors.bg,
        border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            if (showMenu != null) ...[
              _IconBtn(icon: Icons.menu, onTap: showMenu!, tooltip: 'Menü'),
              const SizedBox(width: 12),
            ],
            _IconBtn(
              icon: Icons.arrow_back,
              onTap: onLeave,
              tooltip: 'Oyunlara dön',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${GameVersion.parse(gameVersionCode).label} — ${game.summary}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminHubColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (game.leagueFilter && onLeagueLength != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminHubColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final length in const [3, 4])
                        _LeagueTab(
                          label: '$length',
                          selected: selectedLength == length,
                          onTap: () => onLeagueLength!(length),
                        ),
                      for (final tier in LeagueTier.values)
                        _LeagueTab(
                          label: selectedLength == tier.wordLength
                              ? '✓ ${tier.label}'
                              : tier.label,
                          selected: selectedLength == tier.wordLength,
                          onTap: () => onLeagueLength!(tier.wordLength),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (game.localeFilter && locale != null && onLocale != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminHubColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: locale,
                    dropdownColor: AdminHubColors.card,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    items: [
                      for (final loc in GameLocale.all)
                        DropdownMenuItem(
                          value: loc.id,
                          child: Text(
                            '${loc.id.toUpperCase()}  ${loc.nativeName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (next) {
                      if (next == null) return;
                      onLocale!(next);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeagueTab extends StatelessWidget {
  const _LeagueTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? AdminHubColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF042F2A) : AdminHubColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AdminHubColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}
