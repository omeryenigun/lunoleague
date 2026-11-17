import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

const _kPageBg = AppColors.cosmicBg;
const _kTitleGreen = Color(0xFF4ADE80);

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen>
    with SingleTickerProviderStateMixin {
  late final Future<CompetitionSnapshot> _future =
      sl<GameServer>().competitionSnapshot();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: _kPageBg,
            body: CosmicBackdrop(
              child: Center(
                child: CircularProgressIndicator(color: _kTitleGreen),
              ),
            ),
          );
        }
        final data = snap.data!;
        if (data.guest) {
          return Scaffold(
            backgroundColor: _kPageBg,
            body: CosmicBackdrop(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                      child: GamePageHeader(
                        title: l10n.t('league'),
                        bottomSpacing: 0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                      child: Text.rich(
                        TextSpan(children: _leagueDescSpans(l10n)),
                      ),
                    ),
                    for (var i = 0; i < LeagueTier.values.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _GuestLeagueOption(
                        tier: LeagueTier.values[i],
                        locale: l10n.id,
                        delayMs: 50 + i * 70,
                        onTap: () async {
                          await sl<GameServer>().setLeague(LeagueTier.values[i]);
                          if (!context.mounted) return;
                          context.push('/marathon');
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _MarathonStatsAction(),
                  ],
                ),
              ),
            ),
          );
        }

        final titles = [
          l10n.t('week'),
          l10n.t('month'),
          l10n.t('season'),
          l10n.t('year'),
        ];
        final boards = [
          _BoardData(
            caption: 'Bu hafta ${data.weekId} · sıralama ve ödüller',
            title: data.weekTitleActive ? l10n.t('week_champion') : null,
            entries: data.week,
          ),
          _BoardData(
            caption: 'Aylık şampiyonluk ${data.monthId} · üst %10 ödül',
            entries: data.month,
          ),
          _BoardData(
            caption: 'Sezon ${data.seasonId} · rozet ve ödüller',
            entries: data.season,
          ),
          _BoardData(
            caption: 'Onur listesi ${data.yearId}',
            entries: data.year,
          ),
        ];

        return Scaffold(
          backgroundColor: _kPageBg,
          body: CosmicBackdrop(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: GamePageHeader(
                      title:
                          '${data.league.symbol} ${data.league.labelFor(l10n.id)} ${l10n.t('league').toLowerCase()}',
                      bottomSpacing: 0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < titles.length; i++)
                          Expanded(
                            child: _LeagueTab(
                              label: titles[i],
                              active: _tabs.index == i,
                              onTap: () => _tabs.animateTo(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1.5,
                    color: const Color(0xFF1E293B),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        for (final board in boards) _Board(data: board),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeagueLook {
  const _LeagueLook({
    required this.fillStart,
    required this.fillEnd,
    required this.border,
    required this.barStart,
    required this.barEnd,
    required this.name,
    required this.medalBg,
    required this.arrow,
    required this.glow,
  });

  final Color fillStart;
  final Color fillEnd;
  final Color border;
  final Color barStart;
  final Color barEnd;
  final Color name;
  final Color medalBg;
  final Color arrow;
  final Color glow;

  static _LeagueLook of(LeagueTier tier) => switch (tier) {
        LeagueTier.bronze => const _LeagueLook(
            fillStart: Color(0x24CD7F32),
            fillEnd: Color(0x0F8B5A2B),
            border: Color(0x8CCD7F32),
            barStart: Color(0xFFCD7F32),
            barEnd: Color(0xFF8B5A2B),
            name: Color(0xFFE8A866),
            medalBg: Color(0x2ECD7F32),
            arrow: Color(0xFFCD7F32),
            glow: Color(0x1ACD7F32),
          ),
        LeagueTier.silver => const _LeagueLook(
            fillStart: Color(0x1FC0C0C0),
            fillEnd: Color(0x0D6B7280),
            border: Color(0x73C0C0C0),
            barStart: Color(0xFFE0E0E0),
            barEnd: Color(0xFF909090),
            name: Color(0xFFD4D4D4),
            medalBg: Color(0x2EC0C0C0),
            arrow: Color(0xFFC0C0C0),
            glow: Color(0x14C0C0C0),
          ),
        LeagueTier.gold => const _LeagueLook(
            fillStart: Color(0x26FFD700),
            fillEnd: Color(0x12B8860B),
            border: Color(0x99FFD700),
            barStart: Color(0xFFFFD700),
            barEnd: Color(0xFFB8860B),
            name: Color(0xFFFBBF24),
            medalBg: Color(0x33FFD700),
            arrow: Color(0xFFFFD700),
            glow: Color(0x2EFFD700),
          ),
      };
}

class _GuestLeagueOption extends StatelessWidget {
  const _GuestLeagueOption({
    required this.tier,
    required this.locale,
    required this.onTap,
    this.delayMs = 0,
  });

  final LeagueTier tier;
  final String locale;
  final VoidCallback onTap;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final look = _LeagueLook.of(tier);
    final l10n = sl<L10n>();
    final detail = l10n
        .t('letters_tries')
        .replaceAll('{n}', '${tier.wordLength}')
        .replaceAll('{m}', '${tier.maxAttempts}');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delayMs),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [look.fillStart, look.fillEnd],
              ),
              border: Border.all(color: look.border, width: 1.5),
              boxShadow: [
                BoxShadow(color: look.glow, blurRadius: 18),
                BoxShadow(
                  color: look.fillStart.withValues(alpha: 0.35),
                  blurRadius: 24,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [look.barStart, look.barEnd],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: look.medalBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                tier.symbol,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${tier.labelFor(locale)} ${l10n.t('league')}',
                                    style: TextStyle(
                                      color: look.name,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    detail,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: look.arrow,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<InlineSpan> _leagueDescSpans(L10n l10n) {
  const body = TextStyle(
    color: Color(0xFF94A3B8),
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  const accent = TextStyle(
    color: Color(0xFF4ADE80),
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w700,
  );
  final text = l10n.t('league_need_account');
  final highlight = switch (l10n.id) {
    'tr' => 'giriş yap',
    'en' => 'Log in',
    _ => null,
  };
  if (highlight == null) {
    return [TextSpan(text: text, style: body)];
  }
  final at = text.toLowerCase().indexOf(highlight.toLowerCase());
  if (at < 0) {
    return [TextSpan(text: text, style: body)];
  }
  return [
    TextSpan(text: text.substring(0, at), style: body),
    TextSpan(
      text: text.substring(at, at + highlight.length),
      style: accent,
    ),
    TextSpan(text: text.substring(at + highlight.length), style: body),
  ];
}

String _marathonStatsLabel(L10n l10n) {
  if (l10n.id == 'tr') return 'Maraton İstatistikleri';
  return '${l10n.t('endless')} · ${l10n.t('game_stats')}';
}

class _MarathonStatsAction extends StatelessWidget {
  const _MarathonStatsAction();

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final label = _marathonStatsLabel(l10n);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/marathon'),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                Color(0x2622C55E),
                Color(0xCC1E293B),
              ],
            ),
            border: Border.all(color: const Color(0x6622C55E), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x1A22C55E), blurRadius: 15),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x3322C55E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: _kTitleGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kTitleGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _kTitleGreen,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardData {
  const _BoardData({
    required this.caption,
    required this.entries,
    this.title,
  });

  final String caption;
  final String? title;
  final List<LeaderboardEntry> entries;
}

class _LeagueTab extends StatelessWidget {
  const _LeagueTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? _kTitleGreen : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                shadows: active
                    ? const [
                        Shadow(color: Color(0x804ADE80), blurRadius: 12),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 3,
              width: active ? double.infinity : 0,
              margin: active
                  ? const EdgeInsets.symmetric(horizontal: 4)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                color: active ? _kTitleGreen : null,
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x804ADE80),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.data});

  final _BoardData data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries;
    final me = entries.where((e) => e.isCurrentUser).firstOrNull;
    final top = entries.where((e) => e.rank >= 1 && e.rank <= 3).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final rest = entries.where((e) => e.rank > 3).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          decoration: BoxDecoration(
            color: const Color(0x801E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x4D22C55E)),
            boxShadow: const [
              BoxShadow(color: Color(0x0D22C55E), blurRadius: 15),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.caption.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              if (data.title != null) ...[
                const SizedBox(height: 6),
                Text(
                  data.title!,
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
              if (me != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: '#',
                              style: TextStyle(
                                color: _kTitleGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            TextSpan(
                              text: '${me.rank} / ${entries.length}',
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${me.points} puan',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        shadows: [
                          Shadow(color: Color(0x80FBBF24), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Sıralama yok',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else ...[
          if (top.isNotEmpty) ...[
            _Podium(entries: top),
            const SizedBox(height: 10),
          ],
          if (rest.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xCC0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFF1E293B)),
                    _LbRow(entry: rest[i]),
                  ],
                ],
              ),
            ),
        ],
        const SizedBox(height: 15),
        const _MarathonStatsAction(),
      ],
    );
  }
}

class _PodiumStyle {
  const _PodiumStyle({
    required this.blockHeight,
    required this.avatarSize,
    required this.border,
    required this.glow,
    required this.gradient,
  });

  final double blockHeight;
  final double avatarSize;
  final Color border;
  final Color glow;
  final List<Color> gradient;

  static _PodiumStyle forRank(int rank) => switch (rank) {
        1 => const _PodiumStyle(
            blockHeight: 110,
            avatarSize: 65,
            border: Color(0xFFFBBF24),
            glow: Color(0x80FBBF24),
            gradient: [Color(0xFFFBBF24), Color(0xFFB45309)],
          ),
        2 => const _PodiumStyle(
            blockHeight: 80,
            avatarSize: 50,
            border: Color(0xFFCBD5E1),
            glow: Color(0x4DCBD5E1),
            gradient: [Color(0xFF94A3B8), Color(0xFF475569)],
          ),
        _ => const _PodiumStyle(
            blockHeight: 60,
            avatarSize: 50,
            border: Color(0xFFD97706),
            glow: Color(0x4DD97706),
            gradient: [Color(0xFFD97706), Color(0xFF78350F)],
          ),
      };
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  LeaderboardEntry? _at(int rank) {
    for (final e in entries) {
      if (e.rank == rank) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final second = _at(2);
    final first = _at(1);
    final third = _at(3);

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _PodiumPlace(entry: second)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: first != null
                ? _PodiumPlace(entry: first)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: third != null
                ? _PodiumPlace(entry: third)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = _PodiumStyle.forRank(entry.rank);
    final me = entry.isCurrentUser;
    final name = me ? '${entry.displayName} · sen' : entry.displayName;
    final isGold = entry.rank == 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: style.avatarSize,
          height: style.avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(
              color: style.border,
              width: isGold ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: style.glow,
                blurRadius: isGold ? 20 : 15,
              ),
            ],
          ),
          child: Icon(
            isGold ? Icons.emoji_events_rounded : Icons.person_rounded,
            color: style.border,
            size: isGold ? 30 : 24,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: me ? _kTitleGreen : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.points} p',
          style: const TextStyle(
            color: Color(0xFFFBBF24),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: style.blockHeight,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: style.gradient,
            ),
            border: Border.all(
              color: entry.rank == 1
                  ? const Color(0xFFFCD34D)
                  : entry.rank == 2
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFF59E0B),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 20,
                spreadRadius: -8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isGold ? 28 : 24,
              shadows: const [
                Shadow(color: Color(0x66000000), blurRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LbRow extends StatelessWidget {
  const _LbRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final me = entry.isCurrentUser;
    return Container(
      decoration: me
          ? const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x1F22C55E),
                  Color(0x0A22C55E),
                ],
              ),
              border: Border(
                left: BorderSide(color: _kTitleGreen, width: 3),
              ),
            )
          : null,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: me ? _kTitleGreen : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              me ? '${entry.displayName}  · sen' : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: me ? _kTitleGreen : const Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            '${entry.points} puan',
            style: TextStyle(
              color: me ? _kTitleGreen : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
