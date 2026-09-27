import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/rewarded_ad_flow.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/features/home/cubit/home_cubit.dart';
import 'package:kelimelig/injection.dart';

const _homeCardPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    const Center(child: GameLogo(size: 84)),
                    const SizedBox(height: 18),
                    _LeagueCard(user: user, snap: snap),
                    const SizedBox(height: 12),
                    _DailyCta(user: user, snap: snap),
                    const SizedBox(height: 12),
                    _EndlessCard(best: user.endlessBest),
                    if (snap.dailyRewardAvailable && !user.isAnonymous) ...[
                      const SizedBox(height: 12),
                      _RewardCard(day: snap.rewardCycleDay),
                    ],
                    if (!user.isAnonymous) ...[
                      const SizedBox(height: 12),
                      _PeriodBoardsCarousel(snap: snap),
                    ],
                    const SizedBox(height: 12),
                    const _ModeCard(duel: true),
                    const SizedBox(height: 12),
                    const _ModeCard(duel: false),
                    const SizedBox(height: 12),
                    const _AdCoinPanel(),
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
    final accent = user.currentLeague == LeagueTier.bronze
        ? const Color(0xFFFFC107)
        : AppColors.forLeague(user.currentLeague);
    final title = l10n.t('league_named').replaceAll(
      '{tier}',
      user.currentLeague.labelFor(l10n.id).toUpperCase(),
    );
    return CosmicGlassCard(
      padding: _homeCardPadding,
      colors: const [Color(0xFFFFC107), Color(0xFFFF8C00), Color(0xFFFFC107)],
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
              if (snap.leagueRank != null)
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
          const SizedBox(height: 8),
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

  String _title(L10n l10n) => snap.dailyStatus == DailyStatus.started
      ? l10n.t('daily_resume')
      : l10n.t('daily_play');

  Future<void> _open(BuildContext context) async {
    await context.push('/game/daily');
    if (context.mounted) await context.read<HomeCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final subtitle = snap.dailyStatus == DailyStatus.started
        ? l10n.t('daily_resume_sub')
        : user.isAnonymous
            ? l10n.t('daily_guest')
            : l10n.t('daily_reg');
    const accent = Color(0xFF00FFAA);
    return CosmicGlassCard(
      padding: _homeCardPadding,
      colors: const [
        accent,
        Color(0xFF00C9A7),
        accent,
      ],
      onTap: () => _open(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x66000000),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.calendar_today_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(l10n),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.duel});

  final bool duel;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final accent = duel ? const Color(0xFF3A7BD5) : const Color(0xFF00D2FF);
    final colors = duel
        ? const [Color(0xFF3A7BD5), Color(0xFF2E5A9C)]
        : const [Color(0xFF00D2FF), Color(0xFF1288A8)];
    return CosmicGlassCard(
      padding: _homeCardPadding,
      colors: [
        colors[0],
        colors[1],
        colors[0].withValues(alpha: 0.7),
      ],
      onTap: () => context.push(duel ? '/duel' : '/room'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x66000000),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              duel ? Icons.bolt_rounded : Icons.lock_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(duel ? 'duel_title' : 'room_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t(duel ? 'duel_sub' : 'room_sub'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: _homeCardPadding,
      colors: const [
        Color(0xFFB200FF),
        Color(0xFF7A1FA2),
        Color(0xFFB200FF),
      ],
      onTap: () => context.push('/game/endless'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x66000000),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB200FF).withValues(alpha: 0.28),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '∞',
              style: TextStyle(
                color: Color(0xFFB200FF),
                fontSize: 22,
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
                    color: Color(0xFFB200FF),
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

class _AdCoinPanel extends StatefulWidget {
  const _AdCoinPanel();

  @override
  State<_AdCoinPanel> createState() => _AdCoinPanelState();
}

class _AdCoinPanelState extends State<_AdCoinPanel> {
  var _busy = false;
  int? _reward;

  @override
  void initState() {
    super.initState();
    sl<GameServer>().getConfig().then((config) {
      if (mounted) setState(() => _reward = config.adCoinReward);
    });
  }

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthCubit>();
    final before = auth.state.user?.coin ?? 0;
    final coins = await collectRewardedAdCoins(
      server: sl<GameServer>(),
      userId: auth.state.user?.id ?? '',
      balanceBefore: before,
    );
    if (!mounted) return;
    await auth.refreshUser();
    if (!mounted) return;
    await context.read<HomeCubit>().load();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(coins == 0 ? UserMessages.adUnavailable : '+$coins coin'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final amount = _reward ?? 15;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _watch,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x26FFC107), Color(0x26FF8C00)],
            ),
            border: Border.all(color: const Color(0x66FFC107)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33FFC107),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFFFC107),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('home_ad_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('home_ad_sub').replaceAll('{n}', '$amount'),
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC107), Color(0xFFFF8C00)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FFC107),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              l10n.t('home_ad_watch'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

