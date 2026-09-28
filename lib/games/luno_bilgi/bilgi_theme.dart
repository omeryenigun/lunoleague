import 'package:flutter/material.dart';

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
          child: child,
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
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          if (onBack != null)
            _IconButton(icon: Icons.arrow_back, onTap: onBack!)
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          trailing ?? const SizedBox(width: 40),
        ],
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
  const BilgiPrimaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onTap == null
                ? null
                : const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]),
            color: onTap == null ? BilgiColors.card : null,
            borderRadius: BorderRadius.circular(bilgiRadius),
            boxShadow: onTap == null
                ? null
                : const [BoxShadow(color: Color(0x666C3CE9), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(bilgiRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
  const BilgiBottomNav({super.key, required this.current, required this.onSelect});

  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BilgiColors.card,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Nav('home', '🏠', 'Ana Sayfa', current, onSelect),
          _Nav('play', '🎮', 'Oyna', current, onSelect),
          _Nav('league', '🏆', 'Lig', current, onSelect),
          _Nav('profile', '👤', 'Profil', current, onSelect),
          _Nav('shop', '🛒', 'Mağaza', current, onSelect),
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
    final color = active ? BilgiColors.primary : BilgiColors.muted;
    return InkWell(
      onTap: () => onSelect(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
