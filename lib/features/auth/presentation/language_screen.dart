import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = sl<L10n>();
      if (l10n.chosen) return;
      final code = View.of(context).platformDispatcher.locale.languageCode;
      l10n.preview(code == 'en' ? 'en' : 'tr');
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = sl<L10n>();
    if (!l10n.chosen) {
      await l10n.select(sl<GameServer>(), l10n.id);
    }
    if (!mounted) return;
    if (widget.fromSettings) {
      await context.read<AuthCubit>().bootstrap();
      if (mounted) context.go('/home');
      return;
    }
    final user = context.read<AuthCubit>().state.user;
    if (user == null || !user.onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<L10n>(),
      builder: (context, _) {
        final l10n = sl<L10n>();
        final selected = l10n.id;
        return Scaffold(
          backgroundColor: AppColors.cosmicBg,
          body: CosmicBackdrop(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      children: [
                        if (widget.fromSettings)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => context.go('/settings'),
                              icon: const Icon(Icons.chevron_left, size: 28),
                            ),
                          ),
                        const Spacer(),
                        const ShimmerTitle(),
                        const SizedBox(height: 10),
                        Container(
                          width: 88,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.cosmicGreen,
                                AppColors.cosmicTeal,
                                AppColors.cosmicBlue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cosmicGreen.withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _SpinningGlobe(),
                        const SizedBox(height: 10),
                        _Heading(text: l10n.t('choose_language')),
                        const SizedBox(height: 10),
                        Text(
                          l10n.t('choose_language_sub'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        for (final locale in GameLocale.all) ...[
                          _LangCard(
                            locale: locale,
                            selected: selected == locale.id,
                            onTap: () => sl<L10n>().preview(locale.id),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Spacer(),
                        CosmicContinueButton(
                          label: l10n.t('continue'),
                          showArrow: false,
                          onPressed: _continue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFF0FDF4), Color(0xFFA7F3D0), Color(0xFF67E8F9)],
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _SpinningGlobe extends StatefulWidget {
  const _SpinningGlobe();

  @override
  State<_SpinningGlobe> createState() => _SpinningGlobeState();
}

class _SpinningGlobeState extends State<_SpinningGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: const Text('🌐', style: TextStyle(fontSize: 28)),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final GameLocale locale;
  final bool selected;
  final VoidCallback onTap;

  bool get _tr => locale.id == 'tr';

  @override
  Widget build(BuildContext context) {
    final accent = _tr ? AppColors.cosmicGreen : AppColors.cosmicBlue;
    final badge = _tr
        ? const [AppColors.cosmicGreen, AppColors.cosmicTeal]
        : const [AppColors.cosmicBlue, AppColors.cosmicPurple];
    return AnimatedScale(
      scale: selected ? 1.01 : 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: const Color(0xB30F172A),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.35),
                width: selected ? 2.2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: selected ? 0.28 : 0.1),
                  blurRadius: selected ? 22 : 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: badge),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Text(
                    locale.id.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.cosmicBg,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.nativeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        locale.englishName,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.elasticOut,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: badge),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, size: 16, color: AppColors.cosmicBg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
