import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/rewarded_ad_flow.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/core/services/device_link.dart';
import 'package:kelimelig/core/widgets/game_boot_progress.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/home/cubit/home_cubit.dart';
import 'package:kelimelig/injection.dart';

const _homeBg = Color(0xFF071018);
const _homeMuted = Color(0xFFB8C3D6);
const _homeHint = Color(0xFF64748B);
const _homeGold = Color(0xFFFBBF24);
const _homeGoldMeta = Color(0xFFFDE68A);
const _homeAmber = Color(0xFFF59E0B);
const _homeAmberEnd = Color(0xFFD97706);
const _homeBtnInk = Color(0xFF1C1917);
const _homeGreen = Color(0xFF4ADE80);
const _homePurple = Color(0xFFC084FC);
const _homeBlue = Color(0xFF60A5FA);
const _homeCyan = Color(0xFF22D3EE);

const _homeCardPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

/// Logo→ilk panel ve son panel→alt menü; panel arası 8px'e dokunulmaz.
const _homeEdgeGap = 16.0;

const _homeTitleStyle = TextStyle(
  fontWeight: FontWeight.w800,
  fontSize: 15,
  letterSpacing: 0.5,
);

const _homeSubStyle = TextStyle(
  color: _homeMuted,
  fontSize: 12.5,
  height: 1.35,
  fontWeight: FontWeight.w500,
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = HomeCubit(sl());
        if (sl<DeviceLink>().online) {
          cubit.load();
        } else {
          cubit.showOffline();
        }
        return cubit;
      },
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _homeBg,
      body: _HomeBackdrop(
        child: SafeArea(
          bottom: false,
          child: BlocConsumer<HomeCubit, HomeState>(
            listener: (context, state) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.error!)),
                );
              }
            },
            builder: (context, state) {
              if (state.offline) return const _OfflineHome();
              if (state.loading || state.snapshot == null) {
                return const Center(child: GameBootProgress());
              }
              final snap = state.snapshot!;
              final user = snap.user;
              return RefreshIndicator(
                color: _homeGreen,
                onRefresh: () => context.read<HomeCubit>().load(),
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewport.maxHeight - 4,
                        ),
                        child: _EqualEdgeColumn(
                          minEdge: _homeEdgeGap,
                          header: const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x5922C55E),
                                    blurRadius: 24,
                                    offset: Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Color(0x40A855F7),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: GameLogo(size: 84),
                            ),
                          ),
                          body: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LeagueCard(user: user, snap: snap),
                              const SizedBox(height: 8),
                              _DailyCta(snap: snap),
                              const SizedBox(height: 8),
                              _EndlessCard(best: user.endlessBest),
                              if (snap.dailyRewardAvailable) ...[
                                const SizedBox(height: 8),
                                _RewardCard(day: snap.rewardCycleDay),
                              ],
                              const SizedBox(height: 8),
                              _PeriodBoardsCarousel(snap: snap),
                              const SizedBox(height: 8),
                              const _ModeCard(duel: true),
                              const SizedBox(height: 8),
                              const _ModeCard(duel: false),
                              const SizedBox(height: 8),
                              const _AdCoinPanel(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OfflineHome extends StatelessWidget {
  const _OfflineHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Semantics(
          label: sl<L10n>().t('no_internet'),
          child: const Icon(
            Icons.wifi_off_rounded,
            color: _homeGold,
            size: 28,
          ),
        ),
        const Spacer(),
        const Center(child: GameLogo(size: 84)),
        const Spacer(),
      ],
    );
  }
}

/// Logo ile kartlar, kartlar ile alt menü arasında aynı boşluk.
/// İçerik kısa kalırsa artan yükseklik iki kenara eşit bölünür.
class _EqualEdgeColumn extends MultiChildRenderObjectWidget {
  _EqualEdgeColumn({
    required this.minEdge,
    required Widget header,
    required Widget body,
  }) : super(children: [header, body]);

  final double minEdge;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderEqualEdgeColumn(minEdge);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderEqualEdgeColumn renderObject,
  ) {
    renderObject.minEdge = minEdge;
  }
}

class _EqualEdgeParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualEdgeColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualEdgeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualEdgeParentData> {
  _RenderEqualEdgeColumn(this._minEdge);

  double _minEdge;
  double get minEdge => _minEdge;
  set minEdge(double value) {
    if (_minEdge == value) return;
    _minEdge = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualEdgeParentData) {
      child.parentData = _EqualEdgeParentData();
    }
  }

  @override
  void performLayout() {
    final header = firstChild!;
    final body = childAfter(header)!;
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);

    header.layout(childConstraints, parentUsesSize: true);
    body.layout(childConstraints, parentUsesSize: true);

    final contentH = header.size.height + body.size.height + _minEdge * 2;
    final height = constraints.constrainHeight(
      math.max(contentH, constraints.minHeight),
    );
    final extra = math.max(0.0, height - contentH);
    final edge = _minEdge + extra / 2;

    final headerPd = header.parentData! as _EqualEdgeParentData;
    headerPd.offset = Offset.zero;
    final bodyPd = body.parentData! as _EqualEdgeParentData;
    bodyPd.offset = Offset(0, header.size.height + edge);

    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _homeBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -0.9),
                radius: 0.9,
                colors: [Color(0x2E22C55E), Color(0x00071018)],
                stops: [0.0, 0.45],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.5),
                radius: 0.9,
                colors: [Color(0x29A855F7), Color(0x00071018)],
                stops: [0.0, 0.45],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.9),
                radius: 1.0,
                colors: [Color(0x1AF59E0B), Color(0x00071018)],
                stops: [0.0, 0.5],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.child,
    required this.accent,
    required this.fill,
    this.borderOpacity = 0.55,
    this.glowOpacity = 0.15,
    this.padding = _homeCardPadding,
    this.onTap,
  });

  final Widget child;
  final Color accent;
  final List<Color> fill;
  final double borderOpacity;
  final double glowOpacity;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fill,
            ),
            border: Border.all(
              color: accent.withValues(alpha: borderOpacity),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: glowOpacity),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x0AFFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 0.6],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeIconBox extends StatelessWidget {
  const _HomeIconBox({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: child,
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
    final title = l10n.t('league_named').replaceAll(
      '{tier}',
      user.currentLeague.labelFor(l10n.id).toUpperCase(),
    );
    return _HomeCard(
      accent: _homeAmber,
      fill: const [Color(0x29F59E0B), Color(0x1AB45309)],
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => context.push('/settings'),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                user.currentLeague.symbol,
                style: const TextStyle(fontSize: 18, height: 1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: _homeTitleStyle.copyWith(color: _homeGold),
                ),
              ),
              if (snap.leagueRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _homeAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _homeAmber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '#${snap.leagueRank} · ${snap.leaguePoints}p',
                    style: const TextStyle(
                      color: _homeGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          if (user.hasWeekTitle) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.t('week_champion'),
                style: const TextStyle(
                  color: _homeGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat(icon: '🔥', value: '${user.streak}'),
              const SizedBox(width: 18),
              _Stat(icon: '⭐', value: 'Lv.${user.level}'),
              const SizedBox(width: 18),
              _Stat(icon: '🪙', value: '${user.coin}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16, height: 1)),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: _homeGoldMeta,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _DailyCta extends StatelessWidget {
  const _DailyCta({required this.snap});

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
        : l10n.t('daily_reg');
    return _HomeCard(
      accent: const Color(0xFF22C55E),
      fill: const [Color(0x2E22C55E), Color(0x1A064E3B)],
      onTap: () => _open(context),
      child: Row(
        children: [
          const _HomeIconBox(
            accent: Color(0xFF22C55E),
            child: Icon(
              Icons.calendar_today_rounded,
              color: _homeGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(l10n),
                  style: _homeTitleStyle.copyWith(color: _homeGreen),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: _homeSubStyle),
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
    final accent = duel ? const Color(0xFF3B82F6) : const Color(0xFF06B6D4);
    final title = duel ? _homeBlue : _homeCyan;
    final fill = duel
        ? const [Color(0x2E3B82F6), Color(0x1A1E3A8A)]
        : const [Color(0x2E06B6D4), Color(0x1A083344)];
    return _HomeCard(
      accent: accent,
      fill: fill,
      borderOpacity: 0.5,
      onTap: () => context.push(duel ? '/duel' : '/room'),
      child: Row(
        children: [
          _HomeIconBox(
            accent: accent,
            child: Icon(
              duel ? Icons.bolt_rounded : Icons.lock_rounded,
              color: title,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(duel ? 'duel_title' : 'room_title').toUpperCase(),
                  style: _homeTitleStyle.copyWith(color: title),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t(duel ? 'duel_sub' : 'room_sub'),
                  style: _homeSubStyle,
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
    return _HomeCard(
      accent: const Color(0xFFA855F7),
      fill: const [Color(0x33A855F7), Color(0x1A581C87)],
      glowOpacity: 0.18,
      onTap: () => context.push('/marathon'),
      child: Row(
        children: [
          const _HomeIconBox(
            accent: Color(0xFFA855F7),
            child: Text(
              '∞',
              style: TextStyle(
                color: _homePurple,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('endless_home'),
                  style: _homeTitleStyle.copyWith(color: _homePurple),
                ),
                const SizedBox(height: 3),
                Text(l10n.t('endless_sub'), style: _homeSubStyle),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.t('record').toUpperCase(),
                style: TextStyle(
                  color: _homePurple.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$best',
                style: const TextStyle(
                  color: _homePurple,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
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
    return _HomeCard(
      accent: _homeAmber,
      fill: const [Color(0x26F59E0B), Color(0x1478350F)],
      borderOpacity: 0.5,
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
          const _HomeIconBox(
            accent: _homeAmber,
            child: Text('🎁', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('daily_reward_title'),
                  style: _homeTitleStyle.copyWith(color: _homeGold),
                ),
                Text(
                  l10n.t('daily_reward_sub').replaceAll('{n}', '$day'),
                  style: _homeSubStyle,
                ),
              ],
            ),
          ),
          const Text(
            '→',
            style: TextStyle(
              color: _homeGold,
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
          height: 96,
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
          const SizedBox(height: 4),
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
                    color: i == _page ? _homeGreen : _homeHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.t('period_swipe_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _homeHint,
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
    final fill = _fillFor(brief.period);
    final left = _remainingFor(brief.period);
    final rank = brief.rank;
    final progress = rank == null
        ? 0.2
        : (1 - ((rank - 1).clamp(0, 49) / 49)).clamp(0.08, 1.0);
    return _HomeCard(
      accent: accent,
      fill: fill,
      borderOpacity: 0.5,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      onTap: () => context.go('/league'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _titleFor(l10n, brief.period),
                  style: _homeTitleStyle.copyWith(color: accent, fontSize: 13),
                ),
              ),
              Text(
                l10n
                    .t('weekly_left')
                    .replaceAll('{d}', '${left.inDays}')
                    .replaceAll('{h}', '${left.inHours % 24}'),
                style: const TextStyle(
                  color: _homeHint,
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
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xCC071018),
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_thisLabel(l10n, brief.period)}: ',
                style: const TextStyle(
                  color: _homeMuted,
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
                  color: _homeMuted,
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
        RankPeriod.week => _homeGreen,
        RankPeriod.month => _homeBlue,
        RankPeriod.season => _homeCyan,
        RankPeriod.year => _homeGold,
      };

  List<Color> _fillFor(RankPeriod period) => switch (period) {
        RankPeriod.week => const [Color(0x2E22C55E), Color(0x1A064E3B)],
        RankPeriod.month => const [Color(0x2E3B82F6), Color(0x1A1E3A8A)],
        RankPeriod.season => const [Color(0x2E06B6D4), Color(0x1A083344)],
        RankPeriod.year => const [Color(0x29F59E0B), Color(0x1AB45309)],
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
    return _HomeCard(
      accent: _homeAmber,
      fill: const [Color(0x26F59E0B), Color(0x1478350F)],
      borderOpacity: 0.5,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: _busy ? null : _watch,
      child: Row(
        children: [
          const _HomeIconBox(
            accent: _homeAmber,
            child: Icon(
              Icons.card_giftcard_rounded,
              color: _homeGold,
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
                  style: _homeTitleStyle.copyWith(color: _homeGold),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('home_ad_sub').replaceAll('{n}', '$amount'),
                  style: _homeSubStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_homeAmber, _homeAmberEnd],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59F59E0B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _homeBtnInk,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: _homeBtnInk,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.t('home_ad_watch'),
                          style: const TextStyle(
                            color: _homeBtnInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
