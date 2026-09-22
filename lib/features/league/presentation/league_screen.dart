import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/dev_bypass_button.dart';
import 'package:kelimelig/injection.dart';

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
          return Scaffold(
            backgroundColor: AppColors.cosmicBg,
            body: CosmicBackdrop(
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.cosmicGreen),
              ),
            ),
          );
        }
        final data = snap.data!;
        if (data.guest) {
          return Scaffold(
            backgroundColor: AppColors.cosmicBg,
            body: CosmicBackdrop(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ShimmerTitle(
                          text: l10n.t('league'),
                          fontSize: 28,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l10n.t('league_need_account'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (DevBypassButton.enabled) ...[
                        const SizedBox(height: 16),
                        DevBypassButton(
                          displayName: context
                              .read<AuthCubit>()
                              .state
                              .user
                              ?.displayName,
                          onDone: () => context.go('/home'),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
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
          backgroundColor: AppColors.cosmicBg,
          body: CosmicBackdrop(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          data.league.symbol,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${data.league.label} ${l10n.t('league').toLowerCase()}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.forLeague(data.league),
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: AppColors.forLeague(data.league)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                ],
              ),
            ),
          ),
        );
      },
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
