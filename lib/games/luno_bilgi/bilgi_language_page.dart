import 'package:flutter/material.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';

/// Bilgi language picker. Locale is saved only on the Bilgi profile.
class BilgiLanguagePage extends StatefulWidget {
  const BilgiLanguagePage({
    super.key,
    required this.selectedId,
    required this.fromSettings,
    required this.onPreview,
    required this.onConfirm,
    this.onBack,
  });

  final String selectedId;
  final bool fromSettings;
  final ValueChanged<String> onPreview;
  final VoidCallback onConfirm;
  final VoidCallback? onBack;

  @override
  State<BilgiLanguagePage> createState() => _BilgiLanguagePageState();
}

class _BilgiLanguagePageState extends State<BilgiLanguagePage>
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
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedId;
    return ColoredBox(
      color: BilgiColors.bg,
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
                        onPressed: widget.onBack,
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 28,
                          color: BilgiColors.text,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 36),
                        // Same path as _BilgiLogo in bilgi_screen.dart.
                        // errorBuilder hides Flutter's red asset error (e.g.
                        // stale web AssetManifest.bin.json) so the page stays clean.
                        Center(
                          child: Image.asset(
                            'assets/images/luno_bilgi_logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            semanticLabel: bilgiT(selected, 'game_name'),
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 72, height: 72),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ShimmerTitle(
                          text: bilgiT('tr', 'game_name'),
                          fontSize: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bilgiT('en', 'game_name'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BilgiColors.text.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 88,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                BilgiColors.primary,
                                BilgiColors.secondary,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SpinningGlobe(),
                        const SizedBox(height: 18),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: GameLocale.all.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 58,
                          ),
                          itemBuilder: (context, index) {
                            final locale = GameLocale.all[index];
                            return _LangCard(
                              locale: locale,
                              selected: selected == locale.id,
                              onTap: () => widget.onPreview(locale.id),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  CosmicContinueButton(
                    label: bilgiT('tr', 'continue'),
                    subtitle: bilgiT('en', 'continue'),
                    showArrow: false,
                    onPressed: widget.onConfirm,
                  ),
                ],
              ),
            ),
          ),
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
    return Center(
      child: RotationTransition(
        turns: _spin,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text('🌐', style: TextStyle(fontSize: 26)),
          ),
        ),
      ),
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
    final accent = _tr ? BilgiColors.secondary : BilgiColors.primary;
    final badge = _tr
        ? const [BilgiColors.secondary, BilgiColors.info]
        : const [BilgiColors.primary, BilgiColors.primaryLight];
    return AnimatedScale(
      scale: selected ? 1.01 : 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
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
                      color: BilgiColors.bg,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locale.nativeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BilgiColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
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
                      width: 22,
                      height: 22,
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
                      child: const Icon(Icons.check, size: 14, color: BilgiColors.bg),
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
