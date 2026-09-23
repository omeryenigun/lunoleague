import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/language_switch_button.dart';
import 'package:kelimelig/features/game/presentation/widgets/letter_tile.dart';
import 'package:kelimelig/injection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _touring = false;
  var _step = 0;

  static const _steps = [
    _TourStep('tour_goal_title', 'tour_goal_body', [
      (letter: '?', status: LetterStatus.empty),
      (letter: '?', status: LetterStatus.empty),
      (letter: '?', status: LetterStatus.empty),
      (letter: '?', status: LetterStatus.empty),
      (letter: '?', status: LetterStatus.empty),
    ]),
    _TourStep('tour_green_title', 'tour_green_body', [
      (letter: 'L', status: LetterStatus.correct),
      (letter: 'U', status: LetterStatus.empty),
      (letter: 'N', status: LetterStatus.empty),
      (letter: 'O', status: LetterStatus.empty),
    ]),
    _TourStep('tour_yellow_title', 'tour_yellow_body', [
      (letter: 'A', status: LetterStatus.present),
      (letter: 'L', status: LetterStatus.empty),
      (letter: 'E', status: LetterStatus.empty),
      (letter: 'M', status: LetterStatus.empty),
    ]),
    _TourStep('tour_gray_title', 'tour_gray_body', [
      (letter: 'X', status: LetterStatus.absent),
      (letter: 'Q', status: LetterStatus.empty),
      (letter: 'W', status: LetterStatus.empty),
      (letter: 'Z', status: LetterStatus.empty),
    ]),
    _TourStep('tour_tries_title', 'tour_tries_body', [
      (letter: '1', status: LetterStatus.empty),
      (letter: '2', status: LetterStatus.empty),
      (letter: '3', status: LetterStatus.empty),
      (letter: '4', status: LetterStatus.empty),
      (letter: '5', status: LetterStatus.empty),
      (letter: '6', status: LetterStatus.empty),
    ]),
    _TourStep('tour_daily_title', 'tour_daily_body', [
      (letter: 'D', status: LetterStatus.correct),
      (letter: 'A', status: LetterStatus.present),
      (letter: 'Y', status: LetterStatus.absent),
    ]),
    _TourStep('tour_leagues_title', 'tour_leagues_body', [
      (letter: '🥉', status: LetterStatus.present),
      (letter: '🥈', status: LetterStatus.empty),
      (letter: '🥇', status: LetterStatus.correct),
    ]),
    _TourStep('tour_points_title', 'tour_points_body', [
      (letter: '+', status: LetterStatus.correct),
      (letter: '1', status: LetterStatus.empty),
      (letter: '0', status: LetterStatus.empty),
      (letter: '0', status: LetterStatus.empty),
    ]),
    _TourStep('tour_cycle_title', 'tour_cycle_body', [
      (letter: 'W', status: LetterStatus.correct),
      (letter: 'M', status: LetterStatus.present),
      (letter: 'S', status: LetterStatus.empty),
      (letter: 'Y', status: LetterStatus.absent),
    ]),
    _TourStep('tour_coins_title', 'tour_coins_body', [
      (letter: '🪙', status: LetterStatus.present),
      (letter: 'X', status: LetterStatus.empty),
      (letter: 'P', status: LetterStatus.correct),
    ]),
  ];

  Future<void> _enterGame() async {
    final cubit = context.read<AuthCubit>();
    if (cubit.state.user == null) {
      await cubit.anonymous();
    }
    if (!mounted) return;
    await cubit.finishOnboarding();
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_step >= _steps.length - 1) {
      _enterGame();
      return;
    }
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<L10n>(),
      builder: (context, _) {
        final l10n = sl<L10n>();
        return Scaffold(
          backgroundColor: AppColors.cosmicBg,
          body: CosmicBackdrop(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _touring ? _tour(l10n) : _intro(l10n),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _intro(L10n l10n) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: LanguageSwitchButton(cosmic: true),
        ),
        const Spacer(),
        const ShimmerTitle(),
        const SizedBox(height: 16),
        Text(
          l10n.t('onboarding_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF94A3B8),
            height: 1.45,
          ),
        ),
        const Spacer(),
        CosmicContinueButton(
          label: l10n.t('start'),
          showArrow: false,
          onPressed: () => setState(() {
            _touring = true;
            _step = 0;
          }),
        ),
      ],
    );
  }

  Widget _tour(L10n l10n) {
    final step = _steps[_step];
    final last = _step == _steps.length - 1;
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: LanguageSwitchButton(cosmic: true),
        ),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Column(
            key: ValueKey(_step),
            children: [
              _DemoRow(tiles: step.tiles),
              const SizedBox(height: 28),
              Text(
                l10n.t(step.titleKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t(step.bodyKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF94A3B8),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _steps.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: i == _step ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _step
                      ? AppColors.cosmicGreen
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CosmicContinueButton(
                label: last ? l10n.t('tour_play') : l10n.t('next'),
                showArrow: false,
                onPressed: _next,
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _enterGame,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              child: Text(
                l10n.t('skip'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TourStep {
  const _TourStep(this.titleKey, this.bodyKey, this.tiles);
  final String titleKey;
  final String bodyKey;
  final List<({String letter, LetterStatus status})> tiles;
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.tiles});

  final List<({String letter, LetterStatus status})> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          LetterTile(
            letter: tiles[i].letter,
            status: tiles[i].status,
            size: 52,
            flip: true,
            delay: Duration(milliseconds: 70 * i),
          ),
        ],
      ],
    );
  }
}
