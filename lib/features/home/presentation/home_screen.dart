import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/core/widgets/midnight_countdown.dart';
import 'package:kelimelig/features/home/cubit/home_cubit.dart';
import 'package:kelimelig/injection.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(sl())..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: BlocConsumer<HomeCubit, HomeState>(
            listener: (context, state) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.error!)),
                );
              }
            },
            builder: (context, state) {
              if (state.loading || state.snapshot == null) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.cosmicGreen),
                );
              }
              final snap = state.snapshot!;
              final user = snap.user;
              return RefreshIndicator(
                color: AppColors.cosmicGreen,
                onRefresh: () => context.read<HomeCubit>().load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    const Center(child: GameLogo(size: 112)),
                    const SizedBox(height: 20),
                    _LeagueCard(user: user, snap: snap),
                    const SizedBox(height: 14),
                    _DailyCta(user: user, snap: snap),
                    const SizedBox(height: 14),
                    _EndlessCard(best: user.endlessBest),
                    if (snap.dailyRewardAvailable && !user.isAnonymous) ...[
                      const SizedBox(height: 14),
                      _RewardCard(day: snap.rewardCycleDay),
                    ],
                    if (!user.isAnonymous) ...[
                      const SizedBox(height: 14),
                      _PeriodBoardsCarousel(snap: snap),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.user, required this.snap});

  final UserEntity user;
  final HomeSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final accent = AppColors.forLeague(user.currentLeague);
    final title = l10n.t('league_named').replaceAll(
      '{tier}',
      user.currentLeague.labelFor(l10n.id).toUpperCase(),
    );
    return CosmicGlassCard(
      colors: const [AppColors.cosmicGold, Color(0xFFF39C12), Color(0xFFE67E22)],
      onTap: () => user.isAnonymous
          ? context.go('/profile')
          : context.push('/settings'),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                user.currentLeague.symbol,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 14),
                    ],
                  ),
                ),
              ),
              if (user.isAnonymous)
                Text(
                  l10n.t('league_register_note'),
                  style: const TextStyle(
                    color: Color(0xFFF1C40F),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                )
              else if (snap.leagueRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '#${snap.leagueRank} · ${snap.leaguePoints}p',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (user.hasWeekTitle) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.t('week_champion'),
                style: const TextStyle(
                  color: AppColors.cosmicGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(icon: '🔥', value: '${user.streak}', color: AppColors.cosmicRed),
              _divider(),
              _Stat(icon: '⭐', value: 'Lv.${user.level}', color: AppColors.cosmicBlue),
              _divider(),
              _Stat(icon: '🪙', value: '${user.coin}', color: AppColors.cosmicGold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0x3394A3B8),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.color});

  final String icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _DailyCta extends StatelessWidget {
  const _DailyCta({required this.user, required this.snap});

  final UserEntity user;
  final HomeSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final done = snap.dailyStatus == DailyStatus.completed;
    final enabled = !done;
    final resume = snap.dailyStatus == DailyStatus.started;
    final l10n = sl<L10n>();
    final subtitle = done
        ? l10n.t('daily_next_midnight')
        : resume
            ? l10n.t('daily_resume_sub')
            : user.isAnonymous
                ? l10n.t('daily_guest')
                : l10n.t('daily_reg');
    final title = done
        ? l10n.t('daily_done')
        : resume
            ? l10n.t('daily_resume')
            : l10n.t('daily_play');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () async {
                await context.push('/game/daily');
                if (context.mounted) await context.read<HomeCubit>().load();
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cosmicGreen,
                      AppColors.cosmicTeal,
                      Color(0xFF27AE60),
                    ],
                  )
                : null,
            color: enabled ? null : const Color(0xB30F172A),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.cosmicGreen.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.cosmicTeal.withValues(alpha: 0.22),
                      blurRadius: 60,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: enabled ? AppColors.cosmicBg : const Color(0xFFF0FDF4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.cosmicBg.withValues(alpha: 0.75)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (done) ...[
                  const SizedBox(height: 12),
                  MidnightCountdown(
                    onElapsed: () => context.read<HomeCubit>().load(),
                    style: const TextStyle(
                      color: Color(0xFFF1C40F),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndlessCard extends StatelessWidget {
  const _EndlessCard({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return CosmicGlassCard(
      colors: const [
        AppColors.cosmicPurple,
        Color(0xFF8E44AD),
        AppColors.cosmicRed,
      ],
      onTap: () => context.push('/game/endless'),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cosmicPurple, Color(0xFF8E44AD)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cosmicPurple.withValues(alpha: 0.5),
                  blurRadius: 22,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '∞',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('endless'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t('endless_sub'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.t('record').toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '$best',
                style: const TextStyle(
                  color: AppColors.cosmicPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0x809B59B6), blurRadius: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return CosmicGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: () async {
        final r = await context.read<HomeCubit>().claimReward();
        if (r != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.t('daily_reward_got').replaceAll('{n}', '${r.day}')),
            ),
          );
        }
      },
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppColors.cosmicGold, Color(0xFFE67E22)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cosmicGold.withValues(alpha: 0.5),
                  blurRadius: 18,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🎁', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('daily_reward_title'),
                  style: const TextStyle(
                    color: AppColors.cosmicGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  l10n.t('daily_reward_sub').replaceAll('{n}', '$day'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '→',
            style: TextStyle(
              color: AppColors.cosmicGold,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodBoardsCarousel extends StatefulWidget {
  const _PeriodBoardsCarousel({required this.snap});

  final HomeSnapshot snap;

  @override
  State<_PeriodBoardsCarousel> createState() => _PeriodBoardsCarouselState();
}

class _PeriodBoardsCarouselState extends State<_PeriodBoardsCarousel> {
  // Sol hizalı: üst panellerle aynı kenar; sağda sıradaki kartın ucu görünür.
  late final PageController _controller = PageController(viewportFraction: 0.94);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final snap = widget.snap;
    final boards = snap.periodStandings.isNotEmpty
        ? snap.periodStandings
        : [
            PeriodStandingBrief(
              period: RankPeriod.week,
              periodId: snap.weekId,
              rank: snap.leagueRank,
              points: snap.leaguePoints,
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _controller,
            itemCount: boards.length,
            padEnds: false,
            clipBehavior: Clip.none,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == boards.length - 1 ? 0 : 12,
                ),
                child: _PeriodBoardCard(brief: boards[index], snap: snap),
              );
            },
          ),
        ),
        if (boards.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < boards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: i == _page
                        ? AppColors.cosmicGreen
                        : const Color(0xFF475569),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('period_swipe_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodBoardCard extends StatelessWidget {
  const _PeriodBoardCard({required this.brief, required this.snap});

  final PeriodStandingBrief brief;
  final HomeSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final accent = _accentFor(brief.period);
    final left = _remainingFor(brief.period);
    final rank = brief.rank;
    final fill = rank == null
        ? 0.2
        : (1 - ((rank - 1).clamp(0, 49) / 49)).clamp(0.08, 1.0);
    return CosmicGlassCard(
      colors: [accent, Color.lerp(accent, const Color(0xFF0F172A), 0.35)!],
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      onTap: () => context.go('/league'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _titleFor(l10n, brief.period),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                l10n
                    .t('weekly_left')
                    .replaceAll('{d}', '${left.inDays}')
                    .replaceAll('{h}', '${left.inHours % 24}'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 8,
              backgroundColor: const Color(0xCC0F172A),
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_thisLabel(l10n, brief.period)}: ',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                rank == null ? '—' : '#$rank · ${brief.points}p',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${l10n.t('difficulty')}: ',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                snap.user.currentLeague.labelFor(l10n.id),
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _accentFor(RankPeriod period) => switch (period) {
        RankPeriod.week => AppColors.cosmicGreen,
        RankPeriod.month => AppColors.cosmicBlue,
        RankPeriod.season => AppColors.cosmicTeal,
        RankPeriod.year => AppColors.cosmicGold,
      };

  Duration _remainingFor(RankPeriod period) => switch (period) {
        RankPeriod.week => DateKeys.weekRemaining(),
        RankPeriod.month => DateKeys.monthRemaining(),
        RankPeriod.season => DateKeys.seasonRemaining(),
        RankPeriod.year => DateKeys.yearRemaining(),
      };

  String _titleFor(L10n l10n, RankPeriod period) => switch (period) {
        RankPeriod.week => l10n.t('weekly_title'),
        RankPeriod.month => l10n.t('monthly_title'),
        RankPeriod.season => l10n.t('season_title'),
        RankPeriod.year => l10n.t('yearly_title'),
      };

  String _thisLabel(L10n l10n, RankPeriod period) => switch (period) {
        RankPeriod.week => l10n.t('weekly_this'),
        RankPeriod.month => l10n.t('monthly_this'),
        RankPeriod.season => l10n.t('season_this'),
        RankPeriod.year => l10n.t('yearly_this'),
      };
}

