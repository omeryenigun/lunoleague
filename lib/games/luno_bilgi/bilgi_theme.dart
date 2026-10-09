import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BilgiColors {
  static const primary = Color(0xFF6C3CE9);
  static const primaryLight = Color(0xFF8B5CF6);
  static const secondary = Color(0xFF00D9C0);
  static const bg = Color(0xFF0F0E1A);
  static const sidebar = Color(0xFF15132A);
  static const card = Color(0xFF1A1830);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA09CB8);
  static const error = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFB800);
  static const accent = Color(0xFFFF6B9D);
  static const info = Color(0xFF3B82F6);
}

const bilgiRadius = 16.0;

class BilgiChrome extends StatelessWidget {
  const BilgiChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BilgiColors.bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _BilgiBackdrop(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _BilgiBackdrop extends StatelessWidget {
  const _BilgiBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0E14), Color(0xFF2A1B3D)],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -80,
          child: _BilgiGlow(color: Color(0xFF7B61FF), size: 250, opacity: 0.25),
        ),
        Positioned(
          bottom: 50,
          right: -80,
          child: _BilgiGlow(color: Color(0xFFE91E63), size: 300, opacity: 0.18),
        ),
      ],
    );
  }
}

class _BilgiGlow extends StatelessWidget {
  const _BilgiGlow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class BilgiTopBar extends StatelessWidget {
  const BilgiTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.onHome,
    this.leading,
    this.trailing,
    this.titleAlign = TextAlign.left,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final Widget? leading;
  final Widget? trailing;
  final TextAlign titleAlign;

  @override
  Widget build(BuildContext context) {
    final mark = leading ??
        const Image(
          image: AssetImage('assets/images/luno_bilgi_logo.png'),
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        );
    final back = onBack ?? onHome;
    final leftTitle = titleAlign == TextAlign.left || titleAlign == TextAlign.start;
    final titleSlot = Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: leftTitle ? Alignment.centerLeft : Alignment.center,
        child: BilgiHeaderTitle(title, align: leftTitle ? TextAlign.left : TextAlign.center),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            if (back != null) ...[
              _IconButton(icon: Icons.arrow_back_rounded, onTap: back),
              const SizedBox(width: 6),
            ],
            mark,
            const SizedBox(width: 10),
            titleSlot,
            if (trailing != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gold title for Bilgi page headers, matching the home brand.
class BilgiHeaderTitle extends StatelessWidget {
  const BilgiHeaderTitle(this.text, {super.key, this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
        height: 1,
        color: const Color(0xFFFFD76A),
        shadows: const [Shadow(color: Color(0xFF8A4B00), offset: Offset(0, 2), blurRadius: 0)],
      ),
    );
  }
}

class BilgiStatChip extends StatelessWidget {
  const BilgiStatChip({super.key, required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$icon $value', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class BilgiPrimaryButton extends StatelessWidget {
  const BilgiPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.verticalPadding = 18,
    this.horizontalPadding = 20,
    this.fill,
    this.minHeight,
    this.green = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double verticalPadding;
  final double horizontalPadding;

  /// Solid color when [onTap] is null. Defaults to [BilgiColors.card].
  final Color? fill;

  /// When set, the button is at least this tall and the label is centered.
  /// Play-screen Devam passes the answer-row min height so the two stay equal.
  final double? minHeight;

  /// Green fill for start actions. Other primaries use the gold fill.
  final bool green;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = green ? const Color(0xFF22C55E) : const Color(0xFFFFC83D);
    final labelColor = enabled ? (green ? Colors.white : const Color(0xFF3A2200)) : Colors.white;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? ink : (fill ?? const Color(0xFF3C1468)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFC83D), width: enabled ? 2 : 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: minHeight == null
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: verticalPadding),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16, color: labelColor),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight!),
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16, color: labelColor),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BilgiColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class BilgiBottomNav extends StatelessWidget {
  const BilgiBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.home = 'Ana Sayfa',
    this.play = 'Bilgini Sına',
    this.league = 'Lig',
    this.profile = 'Profil',
    this.shop = 'Mağaza',
  });

  final String current;
  final ValueChanged<String> onSelect;
  final String home;
  final String play;
  final String league;
  final String profile;
  final String shop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12081F),
        border: Border(top: BorderSide(color: Color(0x33FFC83D))),
      ),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Row(
        children: [
          _Nav('home', '🏠', home, current, onSelect),
          _Nav('play', '🧠', play, current, onSelect),
          _Nav('league', '🏆', league, current, onSelect),
          _Nav('profile', '👤', profile, current, onSelect),
          _Nav('shop', '🛒', shop, current, onSelect),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav(this.id, this.icon, this.label, this.current, this.onSelect);

  final String id;
  final String icon;
  final String label;
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = current == id;
    final color = active ? const Color(0xFFFFD76A) : const Color(0xFF8E84A8);
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 3,
                width: 36,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFFC83D) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                ),
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 20, height: 1))),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(fontSize: 10, height: 1.15, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
