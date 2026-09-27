import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

const _kPageBg = Color(0xFF071018);
const _kTitleGreen = Color(0xFF4ADE80);
const _kLeagueCardFill = Color(0xFF0F1729);

class _LeaguePageBackdrop extends StatelessWidget {
  const _LeaguePageBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kPageBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.9),
                radius: 0.95,
                colors: [Color(0x3322C55E), Color(0x00071018)],
                stops: [0, 0.45],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.4),
                radius: 0.9,
                colors: [Color(0x24A855F7), Color(0x00071018)],
                stops: [0, 0.45],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.8),
                radius: 1.0,
                colors: [Color(0x1AF59E0B), Color(0x00071018)],
                stops: [0, 0.5],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen>
    with SingleTickerProviderStateMixin {
  late Future<CompetitionSnapshot> _future =
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
            body: _LeaguePageBackdrop(
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
            body: _LeaguePageBackdrop(
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
          body: _LeaguePageBackdrop(
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
                    color: const Color(0x1A94A3B8),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        for (final board in boards) _Board(data: board),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: _MarathonStatsAction(),
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
    void open() => context.push('/marathon');
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: _kLeagueCardFill,
                border: Border.all(color: const Color(0x994ADE80), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x264ADE80), blurRadius: 18),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x334ADE80),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.insights_outlined,
                      color: _kTitleGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: _kTitleGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        letterSpacing: 0.3,
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
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: open,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTitleGreen,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: _kTitleGreen,
              ),
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.cosmicGreen : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                shadows: active
                    ? const [
                        Shadow(color: Color(0x802ECC71), blurRadius: 12),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 3,
              width: active ? 36 : 0,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                gradient: active
                    ? const LinearGradient(
                        colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
                      )
                    : null,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.cosmicGreen.withValues(alpha: 0.7),
                          blurRadius: 12,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0x990F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cosmicGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.caption.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (data.title != null) ...[
                const SizedBox(height: 6),
                Text(
                  data.title!,
                  style: const TextStyle(
                    color: AppColors.cosmicGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
              if (me != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: '#',
                              style: TextStyle(
                                color: AppColors.cosmicGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: '${me.rank} / ${entries.length}',
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${me.points} puan',
                      style: const TextStyle(
                        color: AppColors.cosmicGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        shadows: [
                          Shadow(color: Color(0x80F1C40F), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
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
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0x660F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1494A3B8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: Color(0x0F94A3B8)),
                  _LbRow(entry: entries[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LbRow extends StatelessWidget {
  const _LbRow({required this.entry});

  final LeaderboardEntry entry;

  Color get _rankColor {
    if (entry.rank == 1) return AppColors.cosmicGold;
    if (entry.rank == 2) return const Color(0xFFCBD5E1);
    if (entry.rank == 3) return const Color(0xFFE67E22);
    return const Color(0xFF64748B);
  }

  String get _rankLabel {
    if (entry.rank == 1) return '🥇';
    if (entry.rank == 2) return '🥈';
    if (entry.rank == 3) return '🥉';
    return '#${entry.rank}';
  }

  @override
  Widget build(BuildContext context) {
    final me = entry.isCurrentUser;
    return Container(
      decoration: me
          ? const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x1F2ECC71),
                  Color(0x0A2ECC71),
                ],
              ),
              border: Border(
                left: BorderSide(color: AppColors.cosmicGreen, width: 3),
              ),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              _rankLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _rankColor,
                fontWeight: FontWeight.w900,
                fontSize: entry.rank <= 3 ? 15 : 14,
                shadows: entry.rank <= 3
                    ? [Shadow(color: _rankColor.withValues(alpha: 0.55), blurRadius: 10)]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              me ? '${entry.displayName}  · sen' : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: me ? AppColors.cosmicGreen : const Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 15,
                shadows: me
                    ? const [
                        Shadow(color: Color(0x802ECC71), blurRadius: 10),
                      ]
                    : null,
              ),
            ),
          ),
          Text(
            '${entry.points} puan',
            style: TextStyle(
              color: me ? AppColors.cosmicGreen : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
