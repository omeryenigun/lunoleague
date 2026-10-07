import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';

const _langBg = Color(0xFF16082C);
const _langGold = Color(0xFFFFC83D);
const _langGoldText = Color(0xFFFFD76A);
const _langInk = Color(0xFF3A2500);
const _langSelected = Color(0xFFFFC83D);
const _langDim = Color(0xFF2A0E48);

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
    final title = bilgiT(selected, 'game_name');
    final international = bilgiT('en', 'game_name');
    final continueLabel = bilgiT(selected, 'continue');
    final continueEn = bilgiT('en', 'continue');
    return ColoredBox(
      color: _langBg,
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.nunito(
                              color: _langGoldText,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              height: 1.05,
                              shadows: const [
                                Shadow(color: Color(0xFF8A4B00), offset: Offset(0, 2), blurRadius: 0),
                              ],
                            ),
                          ),
                        ),
                        if (title != international) ...[
                          const SizedBox(height: 6),
                          Text(
                            international,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: _langGoldText.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          width: 88,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _langGold,
                            borderRadius: BorderRadius.circular(2),
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
                  _GoldContinueButton(
                    label: continueLabel,
                    subtitle: continueLabel == continueEn ? null : continueEn,
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

  @override
  Widget build(BuildContext context) {
    final fill = selected ? _langSelected : _langDim;
    return AnimatedScale(
      scale: selected ? 1.01 : 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _langGold, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _langInk : _langGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    locale.id.toUpperCase(),
                    style: GoogleFonts.nunito(
                      color: selected ? _langGold : _langInk,
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
                    style: GoogleFonts.nunito(
                      color: selected ? _langInk : Colors.white,
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
                        color: selected ? _langInk : _langGold,
                      ),
                      child: Icon(Icons.check, size: 14, color: selected ? _langGold : _langInk),
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

class _GoldContinueButton extends StatelessWidget {
  const _GoldContinueButton({
    required this.label,
    required this.onPressed,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _langGold,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0xFFD08A12), blurRadius: 0, offset: Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: _langInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: _langInk.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
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
