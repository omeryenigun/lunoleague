import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserEntity> _future = sl<GameServer>().profile();

  void _reload() {
    setState(() => _future = sl<GameServer>().profile());
  }

  Future<void> _openLogin() async {
    await context.push('/login');
    if (mounted) {
      await context.read<AuthCubit>().bootstrap();
      _reload();
    }
  }

  Future<void> _openRegister() async {
    await context.push('/register');
    if (mounted) {
      await context.read<AuthCubit>().bootstrap();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.cosmicGreen),
                );
              }
              final u = snap.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ShimmerTitle(
                          text: l10n.t('profile'),
                          fontSize: 28,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AvatarRing(avatar: u.avatar),
                  const SizedBox(height: 12),
                  Text(
                    u.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF8FAFC),
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(color: Color(0x4D2ECC71), blurRadius: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.forLeague(u.currentLeague)
                                .withValues(alpha: 0.18),
                            AppColors.forLeague(u.currentLeague)
                                .withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.forLeague(u.currentLeague)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        u.isAnonymous
                            ? l10n.t('guest_badge')
                            : '${u.currentLeague.symbol} ${u.currentLeague.labelFor(l10n.id).toUpperCase()} ${l10n.t('league').toUpperCase()}',
                        style: TextStyle(
                          color: u.isAnonymous
                              ? const Color(0xFFCBD5E1)
                              : AppColors.forLeague(u.currentLeague),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  if (u.hasWeekTitle) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('week_champion'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.cosmicGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (u.isAnonymous) ...[
                    const SizedBox(height: 18),
                    _GlassCard(
                      child: Column(
                        children: [
                          Text(
                            l10n.t('profile_login_sub'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CosmicContinueButton(
                            label: l10n.t('sign_in_title'),
                            showArrow: false,
                            onPressed: _openLogin,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _openRegister,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF0FDF4),
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(
                                color: AppColors.cosmicBlue.withValues(alpha: 0.45),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(l10n.t('email_register')),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final auth = context.read<AuthCubit>();
                              await auth.google();
                              if (!context.mounted) return;
                              final error = auth.state.error;
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error)),
                                );
                                return;
                              }
                              if (auth.state.user?.authProvider !=
                                  AuthProvider.google) {
                                return;
                              }
                              await auth.finishOnboarding();
                              if (mounted) _reload();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.cosmicGreen,
                              side: BorderSide(
                                color: AppColors.cosmicGreen.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.login),
                            label: Text(l10n.t('google')),
                          ),
                          if (Theme.of(context).platform ==
                              TargetPlatform.iOS) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final auth = context.read<AuthCubit>();
                                await auth.apple();
                                await auth.finishOnboarding();
                                if (mounted) _reload();
                              },
                              child: Text(l10n.t('apple')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          icon: '🔥',
                          label: 'Streak',
                          value: '${u.streak} gün',
                          color: AppColors.cosmicRed,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '⭐',
                          label: 'Level',
                          value: '${u.level}',
                          color: AppColors.cosmicGold,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '🪙',
                          label: 'Coin',
                          value: '${u.coin}',
                          color: AppColors.cosmicGold,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '🛡️',
                          label: 'Streak kalkanı',
                          value: '${u.shields}',
                          color: AppColors.cosmicBlue,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  if (u.badges.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final b in u.badges)
                          Chip(
                            backgroundColor: const Color(0x991E293B),
                            side: const BorderSide(color: Color(0x2694A3B8)),
                            label: Text(
                              _badgeLabel(b),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _MenuRow(
                          label: '📊 İstatistikler',
                          onTap: () => context.push('/statistics'),
                          showDivider: true,
                        ),
                        _MenuRow(
                          label: '🏅 Başarımlar',
                          onTap: () => context.push('/achievements'),
                          showDivider: true,
                        ),
                        _MenuRow(
                          label: '📖 Kelime Defteri',
                          onTap: () => context.push('/word-book'),
                          showDivider: u.isAnonymous,
                        ),
                        if (u.isAnonymous)
                          _MenuRow(
                            label: '🔐 ${l10n.t('login_or_register')}',
                            onTap: _openLogin,
                            showDivider: false,
                          ),
                      ],
                    ),
                  ),
                  if (!u.isAnonymous) ...[
                    const SizedBox(height: 22),
                    OutlinedButton(
                      onPressed: () async {
                        await context.read<AuthCubit>().signOut();
                        if (context.mounted) context.go('/login');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cosmicRed,
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.cosmicRed.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(l10n.t('sign_out')),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _badgeLabel(String id) {
    if (id.startsWith('month_')) return 'Aylık şampiyon';
    return switch (id) {
      'season_legend' => 'Sezon efsanesi',
      'season_epic' => 'Sezon %10',
      'season_play' => 'Sezon katılım',
      'year_honor' => 'Yıllık onur',
      _ => id,
    };
  }
}

class _AvatarRing extends StatefulWidget {
  const _AvatarRing({this.avatar});

  final String? avatar;

  @override
  State<_AvatarRing> createState() => _AvatarRingState();
}

class _AvatarRingState extends State<_AvatarRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 104,
        height: 104,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) {
            return CustomPaint(
              painter: _RingPainter(progress: _spin.value),
              child: child,
            );
          },
          child: Center(child: _avatarFace(widget.avatar)),
        ),
      ),
    );
  }
}

Widget _avatarFace(String? avatar) {
  if (avatar != null && avatar.isNotEmpty) {
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(avatar),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }
  return const Text(
    '👑',
    style: TextStyle(
      fontSize: 46,
      shadows: [
        Shadow(color: Color(0x80F1C40F), blurRadius: 18),
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          AppColors.cosmicGreen,
          AppColors.cosmicTeal,
          AppColors.cosmicBlue,
          Color(0xFF9B59B6),
          AppColors.cosmicRed,
          AppColors.cosmicGold,
          AppColors.cosmicGreen,
        ],
      ).createShader(rect);
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 2, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: child,
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.showDivider,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 17, shadows: [
                Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
              ])),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0x1494A3B8)),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: const Color(0xFFF1F5F9).withValues(alpha: 0.55),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0x1494A3B8)),
      ],
    );
  }
}

Future<({UserEntity user, HomeSnapshot home, CompetitionSnapshot competition})>
    _loadStats() async {
  final server = sl<GameServer>();
  final user = await server.profile();
  final home = await server.homeSnapshot();
  final competition = await server.competitionSnapshot();
  return (user: user, home: home, competition: competition);
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Material(
                      color: const Color(0x991E293B),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => context.pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x2694A3B8),
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFFCBD5E1),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: ShimmerTitle(
                          text: 'İstatistik',
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _loadStats(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.cosmicGreen,
                        ),
                      );
                    }
                    final bundle = snap.data!;
                    final u = bundle.user;
                    final lost = u.gamesPlayed - u.gamesWon;
                    final fastest = u.fastestSolveSeconds;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _StatsCompare(bundle: bundle),
                        const SizedBox(height: 16),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🎮',
                              label: 'Toplam oyun',
                              value: '${u.gamesPlayed}',
                              iconColors: const [
                                Color(0x403498DB),
                                Color(0x262980B9),
                              ],
                              iconBorder: const Color(0x663498DB),
                            ),
                            _RichStat(
                              icon: '✅',
                              label: 'Kazanılan',
                              value: '${u.gamesWon}',
                              valueColor: AppColors.cosmicGreen,
                              iconColors: const [
                                Color(0x402ECC71),
                                Color(0x261ABC9C),
                              ],
                              iconBorder: const Color(0x662ECC71),
                            ),
                            _RichStat(
                              icon: '❌',
                              label: 'Kaybedilen',
                              value: '$lost',
                              valueColor: AppColors.cosmicRed,
                              iconColors: const [
                                Color(0x40E74C3C),
                                Color(0x26C0392B),
                              ],
                              iconBorder: const Color(0x66E74C3C),
                            ),
                            _RichStat(
                              icon: '📊',
                              label: 'Kazanma oranı',
                              value:
                                  '%${(u.winRate * 100).toStringAsFixed(0)}',
                              valueColor: AppColors.cosmicTeal,
                              iconColors: const [
                                Color(0x401ABC9C),
                                Color(0x2616A085),
                              ],
                              iconBorder: const Color(0x661ABC9C),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🎯',
                              label: 'Ortalama tahmin',
                              value: u.averageGuesses.toStringAsFixed(1),
                              iconColors: const [
                                Color(0x409B59B6),
                                Color(0x268E44AD),
                              ],
                              iconBorder: const Color(0x669B59B6),
                            ),
                            _RichStat(
                              icon: '⚡',
                              label: 'En hızlı çözüm',
                              value: fastest == null ? '—' : '$fastest sn',
                              valueColor: fastest == null
                                  ? const Color(0xFF475569)
                                  : AppColors.cosmicGold,
                              iconColors: const [
                                Color(0x40F1C40F),
                                Color(0x26E67E22),
                              ],
                              iconBorder: const Color(0x66F1C40F),
                            ),
                            _RichStat(
                              icon: '🏆',
                              label: 'İlk tahminde çözüm',
                              value: '${u.firstGuessWins}',
                              iconColors: const [
                                Color(0x40E67E22),
                                Color(0x26D35400),
                              ],
                              iconBorder: const Color(0x66E67E22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🔥',
                              label: 'En uzun Daily streak',
                              value: '${u.longestStreak}',
                              valueColor: AppColors.cosmicRed,
                              iconColors: const [
                                Color(0x40E74C3C),
                                Color(0x26C0392B),
                              ],
                              iconBorder: const Color(0x66E74C3C),
                            ),
                            _RichStat(
                              icon: '♾️',
                              label: 'En uzun Kelime Maratonu',
                              value: '${u.endlessBest}',
                              valueColor: const Color(0xFF9B59B6),
                              iconColors: const [
                                Color(0x409B59B6),
                                Color(0x268E44AD),
                              ],
                              iconBorder: const Color(0x669B59B6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '📖',
                              label: 'Öğrenilen kelime',
                              value: '${u.wordsLearned}',
                              iconColors: const [
                                Color(0x40FF6B9D),
                                Color(0x26E64C8A),
                              ],
                              iconBorder: const Color(0x66FF6B9D),
                            ),
                            _RichStat(
                              icon: '👑',
                              label: 'Lig birinciliği',
                              value: '${u.leagueWins}',
                              valueColor: AppColors.cosmicGold,
                              iconColors: const [
                                Color(0x40F1C40F),
                                Color(0x26E67E22),
                              ],
                              iconBorder: const Color(0x66F1C40F),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCompare extends StatefulWidget {
  const _StatsCompare({required this.bundle});

  final ({UserEntity user, HomeSnapshot home, CompetitionSnapshot competition})
      bundle;

  @override
  State<_StatsCompare> createState() => _StatsCompareState();
}

enum _StatsSpan { all, today, month, year }

class _StatsCompareState extends State<_StatsCompare> {
  var _span = _StatsSpan.all;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final user = widget.bundle.user;
    final competition = widget.bundle.competition;
    final board = switch (_span) {
      _StatsSpan.month => competition.month,
      _StatsSpan.year => competition.year,
      _ => competition.week,
    };
    final mine = board.where((e) => e.isCurrentUser).firstOrNull;
    final others = board.where((e) => !e.isCurrentUser);
    final average = others.isEmpty
        ? 0
        : others.map((e) => e.points).reduce((a, b) => a + b) / others.length;
    final today = _span == _StatsSpan.today;
    final playedToday = widget.bundle.home.dailyStatus == DailyStatus.completed ||
        widget.bundle.home.dailyIndex > 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3346E8A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatsTab(
                  label: l10n.t('stats_all'),
                  selected: _span == _StatsSpan.all,
                  onTap: () => setState(() => _span = _StatsSpan.all),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_today'),
                  selected: _span == _StatsSpan.today,
                  onTap: () => setState(() => _span = _StatsSpan.today),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_month'),
                  selected: _span == _StatsSpan.month,
                  onTap: () => setState(() => _span = _StatsSpan.month),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_year'),
                  selected: _span == _StatsSpan.year,
                  onTap: () => setState(() => _span = _StatsSpan.year),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(l10n.t('stats_you'), style: _head)),
              Expanded(child: Text(l10n.t('stats_field'), style: _head)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompareTile(
                  value: today
                      ? (playedToday ? l10n.t('stats_daily_done') : '—')
                      : '${mine?.points ?? (_span == _StatsSpan.all ? widget.bundle.home.leaguePoints : 0)}',
                  label: today ? l10n.t('stats_daily') : l10n.t('stats_points'),
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompareTile(
                  value: today
                      ? '—'
                      : (others.isEmpty ? '—' : average.round().toString()),
                  label: l10n.t('stats_avg_points'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompareTile(
                  value: today
                      ? '${user.streak}'
                      : user.averageGuesses.toStringAsFixed(1),
                  label: today ? l10n.t('stats_streak') : l10n.t('stats_avg_guess'),
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompareTile(
                  value: today ? '${user.longestStreak}' : '—',
                  label: today
                      ? l10n.t('stats_best_streak')
                      : l10n.t('stats_avg_guess'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (today)
            const SizedBox.shrink()
          else if (mine == null || board.length < 2)
            Text(
              l10n.t('stats_no_rank'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            _RankBars(
              board: board,
              caption: l10n
                  .t('stats_rank')
                  .replaceAll('{count}', '${board.length}')
                  .replaceAll('{rank}', '${mine.rank}'),
            ),
        ],
      ),
    );
  }
}

const _head = TextStyle(
  color: Color(0xFF94A3B8),
  fontWeight: FontWeight.w700,
  fontSize: 13,
);

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x3346E8A0) : const Color(0x221E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.cosmicGreen : const Color(0x2294A3B8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cosmicGreen : const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CompareTile extends StatelessWidget {
  const _CompareTile({
    required this.value,
    required this.label,
    this.emphasize = false,
  });

  final String value;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.cosmicGreen : const Color(0xFFF8FAFC);
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RankBars extends StatelessWidget {
  const _RankBars({required this.board, required this.caption});

  final List<LeaderboardEntry> board;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ranked = [...board]..sort((a, b) => a.rank.compareTo(b.rank));
    final shown = ranked.length <= 7
        ? ranked
        : _window(ranked);
    final maxPoints = shown.map((e) => e.points).fold<int>(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in shown)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 18 + 70 * (entry.points / maxPoints),
                        decoration: BoxDecoration(
                          color: entry.isCurrentUser
                              ? AppColors.cosmicGreen
                              : const Color(0xFF1E3A34),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          caption,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<LeaderboardEntry> _window(List<LeaderboardEntry> ranked) {
    final index = ranked.indexWhere((e) => e.isCurrentUser);
    final start = (index - 3).clamp(0, ranked.length - 7);
    return ranked.sublist(start, start + 7);
  }
}

class _RichStat {
  const _RichStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColors,
    required this.iconBorder,
    this.valueColor = const Color(0xFFF8FAFC),
  });

  final String icon;
  final String label;
  final String value;
  final List<Color> iconColors;
  final Color iconBorder;
  final Color valueColor;
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.rows});

  final List<_RichStat> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _RichStatRow(stat: rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, color: Color(0x1494A3B8)),
          ],
        ],
      ),
    );
  }
}

class _RichStatRow extends StatelessWidget {
  const _RichStatRow({required this.stat});

  final _RichStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: stat.iconColors,
              ),
              border: Border.all(color: stat.iconBorder),
              boxShadow: [
                BoxShadow(
                  color: stat.iconBorder.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(stat.icon, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stat.label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            stat.value,
            style: TextStyle(
              color: stat.valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              shadows: [
                Shadow(
                  color: stat.valueColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
