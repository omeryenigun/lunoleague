import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/core/widgets/midnight_countdown.dart';
import 'package:kelimelig/features/game/cubit/game_cubit.dart';
import 'package:kelimelig/features/game/presentation/widgets/guess_board.dart';
import 'package:kelimelig/features/game/presentation/widgets/result_screen.dart';
import 'package:kelimelig/features/match/presentation/match_result_screen.dart';
import 'package:kelimelig/features/game/presentation/widgets/turkish_keyboard.dart';
import 'package:kelimelig/features/word_book/presentation/word_card_screen.dart';
import 'package:kelimelig/injection.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.type});

  final GameType type;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameCubit(sl(), type)..start(),
      child: GameView(type: type),
    );
  }
}

class GameView extends StatelessWidget {
  const GameView({super.key, required this.type});

  final GameType type;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listenWhen: (p, c) =>
          p.error != c.error ||
          (p.session?.outcome == null && c.session?.outcome != null),
      listener: (context, state) async {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
        final outcome = state.session?.outcome;
        if (outcome != null) {
          sl<HapticManager>().success();
          final audio = sl<AudioManager>();
          if (audio.enabled) {
            final steps = state.session?.wordLength ?? 5;
            await Future<void>.delayed(Duration(milliseconds: 150 * steps));
          }
          if (!context.mounted) return;
          if (outcome.won) {
            await audio.win();
          } else {
            await audio.lose();
          }
        }
      },
      builder: (context, state) {
        final session = state.session;
        final outcome = session?.outcome;
        if (outcome != null && session != null) {
          if (type == GameType.duel || type == GameType.room) {
            return MatchResultScreen(
              kind: type == GameType.room ? 'room' : 'duel',
            );
          }
          return ResultScreen(
            outcome: outcome,
            guesses: session.guesses,
            maxAttempts: session.maxAttempts,
            isDaily: type == GameType.daily,
            onHome: () => context.go('/home'),
            onLearn: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordCardScreen(outcome: outcome),
                ),
              );
            },
            onReplay: () {
              if (context.mounted) context.read<GameCubit>().start();
            },
            onReviveWithAd: null,
            onEndAd: null,
          );
        }

        final l10n = sl<L10n>();
        final title = switch (type) {
          GameType.daily => l10n.t('daily_mode'),
          GameType.endless => l10n.t('endless'),
          GameType.duel => l10n.t('duel_title'),
          GameType.room => l10n.t('room_title'),
        };
        return Scaffold(
          backgroundColor: AppColors.cosmicBg,
          body: CosmicBackdrop(
            child: SafeArea(
              child: state.loading || session == null
                  ? state.errorCode == 'DAILY_DONE'
                      ? SizedBox.expand(
                          child: _DailyClosed(onHome: () => context.go('/home')),
                        )
                      : Center(
                          child: Text(
                            state.error ?? l10n.t('loading'),
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              CosmicGlassIconButton(
                                icon: Icons.chevron_left_rounded,
                                onPressed: () => context.go('/home'),
                              ),
                              Expanded(
                                child: ShimmerTitle(
                                  text: title,
                                  fontSize: 22,
                                ),
                              ),
                              if (!session.isFinished)
                                _UntilStart(
                                  startedAt: session.startedAt,
                                  waiting: (seconds) => Text(
                                    '$seconds',
                                    style: const TextStyle(
                                      color: AppColors.cosmicTeal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                                  ),
                                  ready: _PlayClock(startedAt: session.startedAt),
                                ),
                              const SizedBox(width: 8),
                              _AttemptPill(
                                current: session.currentAttempt,
                                max: session.maxAttempts,
                              ),
                            ],
                          ),
                        ),
                        if (session.isFinished)
                          _FinishedSummary(
                            won: session.solved == true,
                            lost: session.solved == false,
                            answer: session.answer,
                          ),
                        if (session.definitionHint != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Text(
                              session.definitionHint!,
                              style: const TextStyle(
                                color: AppColors.cosmicGold,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: GuessBoard(
                                wordLength: session.wordLength,
                                maxAttempts: session.maxAttempts,
                                guesses: session.guesses,
                                currentInput: state.input,
                                revealed: session.revealedLetters,
                                animateLast: state.flipping ||
                                    session.guesses.isNotEmpty,
                              ),
                            ),
                          ),
                        ),
                        if (!session.isFinished)
                          _UntilStart(
                            startedAt: session.startedAt,
                            waiting: (seconds) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              child: Text(
                                '${l10n.t('match_starts')}  $seconds',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            ready: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Row(
                              children: [
                                _HintChip(
                                  label: l10n.t('hint_letter').replaceAll('💡 ', ''),
                                  onTap: () => context
                                      .read<GameCubit>()
                                      .hint(HintLevel.letter),
                                ),
                                const SizedBox(width: 10),
                                _HintChip(
                                  label: l10n.t('hint_meaning').replaceAll('💡 ', ''),
                                  onTap: () => context
                                      .read<GameCubit>()
                                      .hint(HintLevel.meaning),
                                ),
                                const Spacer(),
                                _CoinDisplay(coins: state.coins),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: TurkishKeyboard(
                              locale: state.gameLocale,
                              states: session.keyboard,
                              onLetter: (l) {
                                sl<AudioManager>().keyPress();
                                sl<HapticManager>().light();
                                context.read<GameCubit>().tapLetter(l);
                              },
                              onEnter: () => context.read<GameCubit>().submit(),
                              onBackspace: () =>
                                  context.read<GameCubit>().backspace(),
                            ),
                          ),
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

class _UntilStart extends StatefulWidget {
  const _UntilStart({
    required this.startedAt,
    required this.waiting,
    required this.ready,
  });

  final DateTime startedAt;
  final Widget Function(int seconds) waiting;
  final Widget ready;

  @override
  State<_UntilStart> createState() => _UntilStartState();
}

class _UntilStartState extends State<_UntilStart> {
  static const _countdown = Duration(seconds: 15);
  Timer? _timer;

  Duration get _left => widget.startedAt.difference(DateTime.now());

  bool get _holding {
    final left = _left;
    return left > Duration.zero && left <= _countdown;
  }

  @override
  void initState() {
    super.initState();
    if (_holding) {
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_holding) {
          _timer?.cancel();
          _timer = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_holding) {
      final seconds = _left.inMilliseconds <= 0 ? 0 : (_left.inSeconds + 1);
      return widget.waiting(seconds.clamp(1, 9));
    }
    return widget.ready;
  }
}

class _FinishedSummary extends StatelessWidget {
  const _FinishedSummary({
    required this.won,
    required this.lost,
    required this.answer,
  });

  final bool won;
  final bool lost;
  final String? answer;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final color = won ? AppColors.cosmicGreen : AppColors.cosmicRed;
    final title = won
        ? l10n.t('result_win_title')
        : lost
            ? l10n.t('result_lose_title')
            : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          if (title != null)
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0.6,
              ),
            ),
          if (answer != null && answer!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.t('result_answer_label'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              answer!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyClosed extends StatelessWidget {
  const _DailyClosed({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CosmicGlassIconButton(
              icon: Icons.chevron_left_rounded,
              onPressed: onHome,
            ),
          ),
          const Spacer(),
          Text(
            l10n.t('daily_done'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF0FDF4),
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const MidnightCountdown(),
          const SizedBox(height: 10),
          Text(
            l10n.t('daily_next_midnight'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PlayClock extends StatefulWidget {
  const _PlayClock({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_PlayClock> createState() => _PlayClockState();
}

class _PlayClockState extends State<_PlayClock> {
  Timer? _timer;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = widget.startedAt.isAfter(now) ? now : widget.startedAt;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_anchor).inSeconds;
    final total = elapsed < 0 ? 0 : elapsed;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x991E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x2694A3B8)),
      ),
      child: Text(
        '$minutes:$seconds',
        style: const TextStyle(
          color: Color(0xFFF0FDF4),
          fontWeight: FontWeight.w800,
          fontSize: 15,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AttemptPill extends StatelessWidget {
  const _AttemptPill({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x991E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x2694A3B8)),
      ),
      child: Text.rich(
        TextSpan(
          text: '$current / ',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          children: [
            TextSpan(
              text: '$max',
              style: const TextStyle(
                color: AppColors.cosmicGreen,
                shadows: [Shadow(color: Color(0x992ECC71), blurRadius: 10)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cosmicGold,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinDisplay extends StatelessWidget {
  const _CoinDisplay({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.cosmicGold, Color(0xFFE67E22)],
            ),
            boxShadow: [
              BoxShadow(color: Color(0x99F1C40F), blurRadius: 12),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🪙', style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 6),
        Text(
          '$coins',
          style: const TextStyle(
            color: AppColors.cosmicGold,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            shadows: [Shadow(color: Color(0x80F1C40F), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}
