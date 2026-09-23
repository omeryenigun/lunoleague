import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:kelimelig/injection.dart';
import 'package:share_plus/share_plus.dart';

String buildShareText({
  required L10n l10n,
  required GameOutcome outcome,
  required List<EvaluatedGuess> guesses,
  required int maxAttempts,
  required bool isDaily,
}) {
  final won = outcome.won;
  final title = won ? l10n.t('result_win_title') : l10n.t('result_lose_title');
  final detail = won
      ? l10n
          .t('result_guesses')
          .replaceAll('{n}', '${outcome.guesses}')
          .replaceAll('{m}', '$maxAttempts')
      : isDaily
          ? l10n.t('result_lose_sub_daily')
          : l10n.t('result_lose_sub');
  final score = l10n
      .t('share_score')
      .replaceAll('{n}', '${outcome.guesses}')
      .replaceAll('{m}', '$maxAttempts');
  final time = l10n.t('share_time').replaceAll('{t}', _shareClock(outcome.timeSpentSeconds));
  final rewards = [
    l10n.t('share_xp').replaceAll('{n}', _shareSigned(outcome.xpEarned)),
    l10n.t('share_coins').replaceAll('{n}', _shareSigned(outcome.coinEarned)),
  ].join(' · ');
  final lines = <String>[
    AppConstants.appName,
    title,
    detail,
    '$score · $time',
    rewards,
  ];
  if (isDaily || outcome.leaguePoints != 0) {
    lines.add(
      l10n.t('share_league').replaceAll('{n}', _shareSigned(outcome.leaguePoints)),
    );
  }
  if (isDaily) {
    lines.add('🔥 ${l10n.t('result_streak_days').replaceAll('{n}', '${outcome.streak}')}');
  } else if (outcome.endlessRun > 0) {
    lines.add(l10n.t('share_run').replaceAll('{n}', '${outcome.endlessRun}'));
  }
  if (outcome.rankAfter != null) {
    lines.add(l10n.t('share_rank').replaceAll('{n}', '${outcome.rankAfter}'));
  }
  if (outcome.unlockedAchievements.isNotEmpty) {
    lines.add(
      '${l10n.t('result_achievement')}: ${outcome.unlockedAchievements.join(', ')}',
    );
  }
  final buf = StringBuffer('${lines.join('\n')}\n\n');
  for (final guess in guesses) {
    for (final status in guess.statuses) {
      buf.write(switch (status) {
        LetterStatus.correct => '🟩',
        LetterStatus.present => '🟨',
        _ => '⬜',
      });
    }
    buf.writeln();
  }
  return buf.toString().trimRight();
}

String _shareSigned(int value) => value > 0 ? '+$value' : '$value';

String _shareClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.outcome,
    required this.guesses,
    required this.maxAttempts,
    required this.isDaily,
    required this.onHome,
    required this.onLearn,
    required this.onReplay,
    this.onReviveWithAd,
    this.onEndAd,
  });

  final GameOutcome outcome;
  final List<EvaluatedGuess> guesses;
  final int maxAttempts;
  final bool isDaily;
  final VoidCallback onHome;
  final VoidCallback onLearn;
  final VoidCallback onReplay;
  final VoidCallback? onReviveWithAd;
  final Future<bool> Function()? onEndAd;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _icon;
  late final AnimationController _aura;
  late final AnimationController _border;
  late final AnimationController _shake;
  late final AnimationController _shimmer;
  late final AnimationController _particles;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final List<_Particle> _bits;
  final _rng = Random(42);
  var _endAdClaimed = false;
  var _endAdBusy = false;

  GameOutcome get outcome => widget.outcome;
  bool get won => outcome.won;

  Future<void> _offerEndAd() async {
    final offer = widget.onEndAd;
    if (offer == null || _endAdBusy || _endAdClaimed) return;
    _endAdBusy = true;
    final watched = await offer();
    _endAdBusy = false;
    if (mounted && watched) setState(() => _endAdClaimed = true);
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scale = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _icon = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: won ? 1400 : 2800),
    );
    _aura = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _border = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _particles = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    final colors = won
        ? AppColors.cosmicStarColors
        : const [
            Color(0x99E74C3C),
            Color(0x80C0392B),
            Color(0x80E67E22),
            Color(0x6694A3B8),
            Color(0x6664748B),
            Color(0x80475569),
          ];
    _bits = List.generate(won ? 56 : 48, (_) {
      return _Particle(
        x: _rng.nextDouble(),
        drift: (_rng.nextDouble() - 0.5) * (won ? 0.35 : 0.28),
        size: won ? (5 + _rng.nextDouble() * 8) : (2 + _rng.nextDouble() * 5),
        round: won ? _rng.nextBool() : true,
        color: colors[_rng.nextInt(colors.length)],
        delay: _rng.nextDouble() * (won ? 0.45 : 0.55),
        duration: won
            ? (1.8 + _rng.nextDouble() * 1.6)
            : (2.4 + _rng.nextDouble() * 2.2),
        spins: won ? (2 + _rng.nextDouble() * 4) : 0,
      );
    });

    if (widget.onEndAd != null && widget.onReviveWithAd == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        await _offerEndAd();
      });
    }

    Future<void>.delayed(const Duration(milliseconds: 80), () async {
      if (!mounted) return;
      if (!won) {
        await _shake.forward();
      }
      if (!mounted) return;
      _enter.forward();
      _aura.forward();
      _particles.forward();
      _icon.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _icon.dispose();
    _aura.dispose();
    _border.dispose();
    _shake.dispose();
    _shimmer.dispose();
    _particles.dispose();
    super.dispose();
  }

  String _subtitle(L10n l10n) {
    if (won) {
      return l10n
          .t('result_guesses')
          .replaceAll('{n}', '${outcome.guesses}')
          .replaceAll('{m}', '${widget.maxAttempts}');
    }
    return widget.isDaily
        ? l10n.t('result_lose_sub_daily')
        : l10n.t('result_lose_sub');
  }

  String _primaryLabel(L10n l10n) {
    if (widget.isDaily) return l10n.t('home');
    if (won) return l10n.t('result_next');
    return widget.onReviveWithAd != null
        ? l10n.t('result_reset_run')
        : l10n.t('result_retry');
  }

  VoidCallback get _primaryAction {
    if (widget.isDaily) return widget.onHome;
    return widget.onReplay;
  }

  Future<void> _share() async {
    final text = buildShareText(
      l10n: sl<L10n>(),
      outcome: outcome,
      guesses: widget.guesses,
      maxAttempts: widget.maxAttempts,
      isDaily: widget.isDaily,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final canRevive = !widget.isDaily && widget.onReviveWithAd != null;
    final auraColor = won ? AppColors.cosmicGreen : AppColors.cosmicRed;

    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = t == 0 || t == 1
                ? 0.0
                : sin(t * pi * 10) * 6 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _aura,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_aura.value);
                  final opacity = t < 0.3
                      ? t / 0.3
                      : (1 - ((t - 0.3) / 0.7)).clamp(0.0, 1.0);
                  return IgnorePointer(
                    child: Opacity(
                      opacity: opacity * (won ? 0.9 : 0.85),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.85 + t * 0.4,
                            colors: [
                              auraColor.withValues(alpha: won ? 0.4 : 0.38),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_enter, _particles]),
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ParticlePainter(
                          bits: _bits,
                          progress: max(_enter.value, _particles.value),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale:
                            Tween<double>(begin: 0.82, end: 1).animate(_scale),
                        child: _ResultCard(
                          borderTick: _border,
                          won: won,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _icon,
                                builder: (context, child) {
                                  final bob = sin(_icon.value * pi) *
                                      (won ? 8 : 6);
                                  final tilt = sin(_icon.value * pi) *
                                      (won ? 0.08 : 0.05);
                                  return Transform.translate(
                                    offset: Offset(0, -bob),
                                    child: Transform.rotate(
                                      angle: tilt,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  won ? '🏆' : '💔',
                                  style: TextStyle(
                                    fontSize: won ? 64 : 58,
                                    shadows: [
                                      Shadow(
                                        color: won
                                            ? const Color(0xCCF1C40F)
                                            : const Color(0x99E74C3C),
                                        blurRadius: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _ShimmerHeadline(
                                text: won
                                    ? l10n.t('result_win_title')
                                    : l10n.t('result_lose_title'),
                                tick: _shimmer,
                                won: won,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _subtitle(l10n),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (won)
                                _WordChip(word: outcome.word)
                              else
                                _AnswerBox(
                                  label: l10n.t('result_answer_label'),
                                  word: outcome.word,
                                  meaning: outcome.definition,
                                ),
                              const SizedBox(height: 16),
                              _StatRow(
                                icon: '⭐',
                                label: 'XP',
                                value: won
                                    ? '+${outcome.xpEarned}'
                                    : '${outcome.xpEarned}',
                                valueColor: won
                                    ? AppColors.cosmicGreen
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(height: 8),
                              _StatRow(
                                icon: '🪙',
                                label: l10n.t('shop_coins'),
                                value: '+${outcome.coinEarned}',
                                valueColor: AppColors.cosmicGold,
                              ),
                              if (widget.isDaily) ...[
                                const SizedBox(height: 8),
                                _StatRow(
                                  icon: '🔥',
                                  label: 'Streak',
                                  value: l10n
                                      .t('result_streak_days')
                                      .replaceAll('{n}', '${outcome.streak}'),
                                  valueColor: AppColors.cosmicRed,
                                ),
                              ],
                              if (!widget.isDaily &&
                                  won &&
                                  outcome.endlessRun > 0) ...[
                                const SizedBox(height: 8),
                                _StatRow(
                                  icon: '🎢',
                                  label: 'Endless',
                                  value: '${outcome.endlessRun}',
                                  valueColor: AppColors.cosmicBlue,
                                ),
                              ],
                              if (outcome.rankAfter != null) ...[
                                const SizedBox(height: 8),
                                _StatRow(
                                  icon: '🏅',
                                  label: l10n.t('league'),
                                  value: '#${outcome.rankAfter}',
                                  valueColor: const Color(0xFFF8FAFC),
                                ),
                              ],
                              if (outcome
                                  .unlockedAchievements.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  '${l10n.t('result_achievement')}: ${outcome.unlockedAchievements.join(', ')}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (canRevive && outcome.endlessRun > 0) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n
                                      .t('result_revive_hint')
                                      .replaceAll(
                                        '{n}',
                                        '${outcome.endlessRun}',
                                      ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.cosmicGold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionButton(
                                      label: '📖 ${l10n.t('result_learn')}',
                                      primary: false,
                                      onPressed: widget.onLearn,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ActionButton(
                                      label: _primaryLabel(l10n),
                                      primary: true,
                                      danger: !won,
                                      onPressed: _primaryAction,
                                    ),
                                  ),
                                ],
                              ),
                              if (canRevive) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: _ActionButton(
                                    label: l10n.t('result_revive_ad'),
                                    primary: true,
                                    accent: AppColors.cosmicGold,
                                    onPressed: widget.onReviveWithAd,
                                  ),
                                ),
                              ] else if (widget.onEndAd != null && !_endAdClaimed) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: _ActionButton(
                                    label: l10n.t('result_end_ad'),
                                    primary: true,
                                    accent: AppColors.cosmicGold,
                                    onPressed: _offerEndAd,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionButton(
                                      label: l10n.t('result_share'),
                                      primary: false,
                                      onPressed: _share,
                                    ),
                                  ),
                                  if (!widget.isDaily) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ActionButton(
                                        label: l10n.t('home'),
                                        primary: false,
                                        onPressed: widget.onHome,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _ShimmerHeadline extends StatelessWidget {
  const _ShimmerHeadline({
    required this.text,
    required this.tick,
    required this.won,
  });

  final String text;
  final Animation<double> tick;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final colors = won
        ? AppColors.cosmicShimmer.colors
        : const [
            AppColors.cosmicRed,
            Color(0xFFE67E22),
            Color(0xFFC0392B),
            AppColors.cosmicRed,
          ];
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: colors,
              begin: Alignment(-1.4 + tick.value * 2.8, 0),
              end: Alignment(0.2 + tick.value * 2.8, 0),
            ).createShader(bounds);
          },
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.cosmicGreen.withValues(alpha: 0.22),
            AppColors.cosmicTeal.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppColors.cosmicGreen.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cosmicGreen.withValues(alpha: 0.25),
            blurRadius: 22,
          ),
        ],
      ),
      child: Text(
        word,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: Color(0xFFF0FDF4),
        ),
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({
    required this.label,
    required this.word,
    required this.meaning,
  });

  final String label;
  final String word;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.cosmicGreen.withValues(alpha: 0.12),
            AppColors.cosmicTeal.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.cosmicGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word,
            style: const TextStyle(
              color: AppColors.cosmicGreen,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 3,
              shadows: [
                Shadow(color: Color(0x992ECC71), blurRadius: 18),
              ],
            ),
          ),
          if (meaning.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.borderTick,
    required this.won,
    required this.child,
  });

  final Animation<double> borderTick;
  final bool won;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: borderTick,
      builder: (context, _) {
        final shift = borderTick.value * 6;
        final colors = won
            ? const [
                AppColors.cosmicGreen,
                AppColors.cosmicTeal,
                AppColors.cosmicBlue,
                AppColors.cosmicPurple,
                AppColors.cosmicGold,
                AppColors.cosmicGreen,
              ]
            : const [
                AppColors.cosmicRed,
                Color(0xFFC0392B),
                Color(0xFFE67E22),
                AppColors.cosmicRed,
              ];
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(-1 + shift, -1),
              end: Alignment(1 + shift, 1),
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: (won ? AppColors.cosmicGreen : AppColors.cosmicRed)
                    .withValues(alpha: won ? 0.28 : 0.3),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                  color: Color(0xF20F172A),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x80334155),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              shadows: [
                Shadow(
                  color: valueColor.withValues(alpha: 0.45),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.primary,
    required this.onPressed,
    this.accent,
    this.danger = false,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;
  final Color? accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      final colors = accent != null
          ? [accent!, const Color(0xFFE67E22)]
          : danger
              ? const [AppColors.cosmicRed, Color(0xFFC0392B)]
              : const [AppColors.cosmicGreen, AppColors.cosmicTeal];
      final glow = accent ?? (danger ? AppColors.cosmicRed : AppColors.cosmicGreen);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.42),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: danger || accent != null
                      ? Colors.white
                      : const Color(0xFF0A0E1A),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFCBD5E1),
        side: const BorderSide(color: Color(0x3394A3B8)),
        backgroundColor: const Color(0xCC1E293B),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.drift,
    required this.size,
    required this.round,
    required this.color,
    required this.delay,
    required this.duration,
    required this.spins,
  });

  final double x;
  final double drift;
  final double size;
  final bool round;
  final Color color;
  final double delay;
  final double duration;
  final double spins;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.bits, required this.progress});

  final List<_Particle> bits;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final local = ((progress - b.delay) / b.duration).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dx = b.x * size.width + b.drift * size.width * local;
      final dy = -20 + local * (size.height + 40);
      final opacity = (1 - local).clamp(0.0, 1.0) * (b.spins > 0 ? 1 : 0.85);
      final paint = Paint()..color = b.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      if (b.spins > 0) {
        canvas.rotate(local * b.spins * pi * 2);
      }
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: b.size,
              height: b.size * 1.3,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
