import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

/// Clash Royale–style opening language picker (mock colors/layout).
const _bg = Color(0xFF0B1120);
const _green = Color(0xFF2ECC71);
const _greenSoft = Color(0xFF1ABC9C);
const _blue = Color(0xFF3498DB);
const _purple = Color(0xFF9B59B6);
const _slate = Color(0xFF1A2336);
const _slateBorder = Color(0xFF2A3548);
const _muted = Color(0xFF94A3B8);
const _amberTop = Color(0xFFFBBF24);
const _amberMid = Color(0xFFF59E0B);
const _amberBot = Color(0xFFD97706);
const _amberShadow = Color(0xFF92400E);

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
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = sl<L10n>();
      if (l10n.chosen) return;
      final code = View.of(context).platformDispatcher.locale.languageCode;
      l10n.preview(GameLocale.known(code) ? code : 'tr');
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
    final cubit = context.read<AuthCubit>();
    if (cubit.state.user == null) {
      await cubit.anonymous();
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<L10n>(),
      builder: (context, _) {
        final l10n = sl<L10n>();
        final selected = l10n.id;
        return Scaffold(
          backgroundColor: _bg,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              color: _bg,
              gradient: RadialGradient(
                center: Alignment(0, -0.95),
                radius: 1.15,
                colors: [Color(0x332ECC71), Color(0x000B1120)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-1.05, 0.1),
                      radius: 1.05,
                      colors: [Color(0x403498DB), Color(0x000B1120)],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1.05, 0.15),
                      radius: 1.0,
                      colors: [Color(0x38E11D48), Color(0x000B1120)],
                    ),
                  ),
                ),
                SafeArea(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Column(
                          children: [
                            if (widget.fromSettings)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed: () => context.go('/settings'),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 28,
                                  ),
                                ),
                              ),
                            const _Header(),
                            const SizedBox(height: 14),
                            Text(
                              l10n.t('choose_language'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.t('choose_language_sub'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: GameLocale.all.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      mainAxisExtent: 46,
                                    ),
                                itemBuilder: (context, index) {
                                  final locale = GameLocale.all[index];
                                  return _LangChip(
                                    locale: locale,
                                    selected: selected == locale.id,
                                    onTap: () => sl<L10n>().preview(locale.id),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AmberContinueButton(
                              label: l10n.t('continue'),
                              onPressed: _continue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GameLogo(size: 56),
        const SizedBox(height: 6),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6EE7B7), _green, _greenSoft],
          ).createShader(bounds),
          child: const Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
              height: 1.05,
              shadows: [Shadow(color: Color(0x662ECC71), blurRadius: 16)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Icon(Icons.public, size: 22, color: Color(0xFF7DD3FC)),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final GameLocale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColors = selected
        ? const [_green, _greenSoft]
        : const [_blue, _purple];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x332ECC71)
                : _slate.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _green : _slateBorder,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _green.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: badgeColors,
                  ),
                ),
                child: Text(
                  locale.id.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locale.nativeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: selected ? Colors.white : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: selected ? _green : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmberContinueButton extends StatefulWidget {
  const _AmberContinueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_AmberContinueButton> createState() => _AmberContinueButtonState();
}

class _AmberContinueButtonState extends State<_AmberContinueButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? 2.0 : 6.0;
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              _setPressed(false);
              widget.onPressed?.call();
            },
      onTapCancel: widget.onPressed == null ? null : () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        height: 54 + depth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _amberShadow,
              offset: Offset(0, depth),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_amberTop, _amberMid, _amberBot],
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(color: const Color(0x66FFF7ED), width: 1),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF1A1205),
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
