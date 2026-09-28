import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/rewarded_ad_flow.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/core/widgets/midnight_countdown.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/game/cubit/game_cubit.dart';
import 'package:kelimelig/features/game/presentation/widgets/daily_result_standings.dart';
import 'package:kelimelig/features/game/presentation/widgets/guess_board.dart';
import 'package:kelimelig/features/game/presentation/widgets/result_screen.dart';
import 'package:kelimelig/features/match/presentation/match_result_screen.dart';
import 'package:kelimelig/features/match/presentation/rival_notice_host.dart';
import 'package:kelimelig/features/game/presentation/widgets/turkish_keyboard.dart';
import 'package:kelimelig/features/word_book/presentation/word_card_screen.dart';
import 'package:kelimelig/injection.dart';

Future<void> _openNewDaily(BuildContext context) async {
  final player = await sl<GameServer>().currentUser();
  if (player == null || !context.mounted) return;
  final opened = await confirmAndOpenNextDaily(
    context: context,
    server: sl<GameServer>(),
    userId: player.id,
  );
  if (!context.mounted || !opened) return;
  context.read<GameCubit>().start();
}

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
        if (session != null &&
            (type == GameType.duel || type == GameType.room) &&
            (outcome != null || session.isFinished)) {
          return MatchResultScreen(
            kind: type == GameType.room ? 'room' : 'duel',
          );
        }
        if (outcome != null && session != null && type != GameType.daily) {
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
            dailyIndex: session.dailyIndex,
            onOpenNextDaily: session.dailyIndex < AppConstants.maxDailySlots
                ? () => _openNewDaily(context)
                : null,
            onReviveWithAd: null,
            onEndAd: null,
          );
        }

        final l10n = sl<L10n>();
        final finishedDaily = type == GameType.daily && session?.isFinished == true;
        final title = switch (type) {
          GameType.daily => l10n.t('daily_header'),
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
                          child: const _DailyClosed(),
                        )
                      : Center(
                          child: Text(
                            state.error ?? l10n.t('loading'),
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                  : Column(
                      children: [
                        if (type == GameType.duel || type == GameType.room)
                          RivalNoticeHost(
                            kind: type == GameType.room ? 'room' : 'duel',
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: GamePageHeader(
                            title: title,
                            bottomSpacing: 0,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                    ready: _PlayClock(
                                      startedAt: session.startedAt,
                                    ),
                                  ),
                                if (type == GameType.daily) ...[
                                  const SizedBox(width: 8),
                                  _DailyIndexBadge(index: session.dailyIndex),
                                ],
                                const SizedBox(width: 8),
                                _AttemptPill(
                                  current: session.currentAttempt,
                                  max: session.maxAttempts,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (finishedDaily)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _FinishedSummary(
                                    won: session.solved == true,
                                    lost: session.solved == false,
                                    answer: session.answer,
                                  ),
                                  if (session.dailyIndex <
                                      AppConstants.maxDailySlots)
                                    const Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(20, 10, 20, 0),
                                      child: _ContinueDailyButton(),
                                    ),
                                  if (session.definitionHint != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        8,
                                        20,
                                        0,
                                      ),
                                      child: Text(
                                        session.definitionHint!,
                                        style: const TextStyle(
                                          color: AppColors.cosmicGold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  Padding(
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
                                      currentAttempt: session.currentAttempt,
                                      animateLast: state.flipping ||
                                          session.guesses.isNotEmpty,
                                    ),
                                  ),
                                  _FinishedActions(session: session),
                                  DailyResultStandings(
                                    wordId: session.wordId.isNotEmpty
                                        ? session.wordId
                                        : (session.outcome?.wordId ?? ''),
                                    playerWon: session.solved == true,
                                    playerGuesses: session.guesses.isEmpty
                                        ? session.currentAttempt
                                        : session.guesses.length,
                                    seedKey:
                                        '${session.wordId}_${session.dailyIndex}_${state.locale}',
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                        if (session.isFinished) ...[
                          _FinishedSummary(
                            won: session.solved == true,
                            lost: session.solved == false,
                            answer: session.answer,
                          ),
                          if (type == GameType.daily &&
                              session.dailyIndex < AppConstants.maxDailySlots)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                              child: const _ContinueDailyButton(),
                            ),
                        ],
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
                                currentAttempt: session.currentAttempt,
                                animateLast: state.flipping ||
                                    session.guesses.isNotEmpty,
                              ),
                            ),
                          ),
                        ),
                        if (session.isFinished)
                          _FinishedActions(session: session)
                        else
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
                                  onTap: () => _confirmLetterHint(context, l10n),
                                ),
                                const SizedBox(width: 10),
                                _HintChip(
                                  label: l10n.t('hint_meaning').replaceAll('💡 ', ''),
                                  onTap: () => _confirmMeaningHint(context, l10n),
                                ),
                                const SizedBox(width: 10),
                                const _WatchAdChip(),
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

class _FinishedActions extends StatelessWidget {
  const _FinishedActions({required this.session});

  final GameSessionView session;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final won = session.solved == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.push('/statistics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF0FDF4),
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(
                  color: AppColors.cosmicBlue.withValues(alpha: 0.55),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.t('game_stats')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => shareFinishedBoard(
                l10n: l10n,
                won: won,
                word: session.answer ?? '',
                guesses: session.guesses,
                used: session.currentAttempt,
                maxAttempts: session.maxAttempts,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cosmicGreen,
                foregroundColor: const Color(0xFF0A0E1A),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.t('result_share')),
            ),
          ),
        ],
      ),
    );
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

class _ContinueDailyButton extends StatefulWidget {
  const _ContinueDailyButton();

  @override
  State<_ContinueDailyButton> createState() => _ContinueDailyButtonState();
}

class _ContinueDailyButtonState extends State<_ContinueDailyButton> {
  var _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _openNewDaily(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFD7B8FF), Color(0xFFB794F6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC4A1FF).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _busy ? null : _press,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                sl<L10n>().t('daily_continue_ad'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1A1028),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyIndexBadge extends StatelessWidget {
  const _DailyIndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final label = '$index';
    final size = label.length > 1 ? 34.0 : 28.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00FFAA), AppColors.cosmicTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFAA).withValues(alpha: 0.4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.cosmicBg,
          fontWeight: FontWeight.w900,
          fontSize: label.length > 1 ? 13 : 15,
          height: 1,
        ),
      ),
    );
  }
}

class _DailyClosed extends StatelessWidget {
  const _DailyClosed();

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: const HomeTitleButton(),
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

class _WatchAdChip extends StatefulWidget {
  const _WatchAdChip();

  @override
  State<_WatchAdChip> createState() => _WatchAdChipState();
}

class _WatchAdChipState extends State<_WatchAdChip> {
  var _busy = false;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final cubit = context.read<GameCubit>();
    final auth = context.read<AuthCubit>();
    final before = cubit.state.coins;
    final added = await collectRewardedAdCoins(
      server: sl<GameServer>(),
      userId: auth.state.user?.id ?? '',
      balanceBefore: before,
    );
    if (!mounted) return;
    final now = (await sl<GameServer>().currentUser())?.coin ?? before;
    cubit.setCoins(now);
    await auth.refreshUser();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added == 0 ? UserMessages.adUnavailable : '+$added coin'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HintChip(
      icon: '▶',
      label: sl<L10n>().t('game_ad'),
      onTap: _busy ? null : _watch,
    );
  }
}

Future<void> _confirmLetterHint(BuildContext context, L10n l10n) async {
  final session = context.read<GameCubit>().state.session;
  if (session == null || session.isFinished) return;
  final server = sl<GameServer>();
  final config = await server.getConfig();
  final user = await server.currentUser();
  if (user == null || !context.mounted) return;
  final free = user.freeHint1 > 0;
  final cost = config.hint1Cost;
  if (!free && user.coin < cost) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(UserMessages.insufficientCoins)),
    );
    return;
  }
  final moves = session.letterHintsOnRow >= 1;
  final message = free
      ? l10n.t(moves ? 'hint_letter_free' : 'hint_letter_stay_free')
      : l10n
          .t(moves ? 'hint_letter_confirm' : 'hint_letter_stay')
          .replaceAll('{n}', '$cost');
  final ok = await _askHint(
    context,
    message: message,
    cancel: l10n.t('hint_cancel'),
    confirm: l10n.t('hint_confirm'),
  );
  if (ok && context.mounted) {
    await context.read<GameCubit>().hint(HintLevel.letter);
  }
}

Future<void> _confirmMeaningHint(BuildContext context, L10n l10n) async {
  final session = context.read<GameCubit>().state.session;
  if (session == null || session.isFinished) return;
  final server = sl<GameServer>();
  final config = await server.getConfig();
  final user = await server.currentUser();
  if (user == null || !context.mounted) return;
  final free = user.freeHint2 > 0;
  final cost = config.hint2Cost;
  if (!free && user.coin < cost) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(UserMessages.insufficientCoins)),
    );
    return;
  }
  final message = free
      ? l10n.t('hint_meaning_free')
      : l10n.t('hint_meaning_confirm').replaceAll('{n}', '$cost');
  final ok = await _askHint(
    context,
    message: message,
    cancel: l10n.t('hint_dismiss'),
    confirm: l10n.t('hint_accept'),
  );
  if (ok && context.mounted) {
    await context.read<GameCubit>().hint(HintLevel.meaning);
  }
}

Future<bool> _askHint(
  BuildContext context, {
  required String message,
  required String cancel,
  required String confirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      content: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.cosmicGreen),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.label,
    required this.onTap,
    this.icon = '💡',
  });

  final String icon;

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
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
