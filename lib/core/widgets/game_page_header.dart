import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/injection.dart';

/// Home control shown to the left of a page title. Always opens `/home`.
class HomeTitleButton extends StatelessWidget {
  const HomeTitleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CosmicGlassIconButton(
      icon: Icons.home_rounded,
      tooltip: sl<L10n>().t('home'),
      onPressed: () => context.go('/home'),
    );
  }
}

/// Close control for in-game chrome. Opens `/home` with no confirm dialog.
class CloseTitleButton extends StatelessWidget {
  const CloseTitleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CosmicGlassIconButton(
      icon: Icons.close_rounded,
      tooltip: sl<L10n>().t('home'),
      onPressed: () => context.go('/home'),
    );
  }
}

/// Settings-style page chrome: shimmer title with a leading control on the left.
class GamePageHeader extends StatelessWidget {
  const GamePageHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.titleExtra,
    this.bottomSpacing = 18,
    this.fontSize = 28,
  });

  final String title;
  /// Defaults to [HomeTitleButton]. Pass [CloseTitleButton] on the game screen.
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleExtra;
  final double bottomSpacing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            leading ?? const HomeTitleButton(),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: ShimmerTitle(
                      text: title,
                      fontSize: fontSize,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  if (titleExtra != null) ...[
                    const SizedBox(width: 8),
                    titleExtra!,
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (bottomSpacing > 0) SizedBox(height: bottomSpacing),
      ],
    );
  }
}
