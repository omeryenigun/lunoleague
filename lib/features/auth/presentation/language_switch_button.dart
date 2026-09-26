import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

Future<void> showLanguageSwitchDialog(
  BuildContext context, {
  bool leaveGame = false,
  VoidCallback? onChanged,
}) async {
  final l10n = sl<L10n>();
  final current = l10n.id;
  var selected = current;
  final picked = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: AppColors.surface,
            title: Text(l10n.t('lang_switch_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('lang_switch_body'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selected = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final locale in GameLocale.all)
                        RadioListTile<String>(
                          value: locale.id,
                          activeColor: AppColors.cosmicGreen,
                          contentPadding: EdgeInsets.zero,
                          title: Text(locale.nativeName),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.t('lang_switch_cancel')),
              ),
              FilledButton(
                onPressed: selected == current
                    ? null
                    : () => Navigator.of(dialogContext).pop(selected),
                child: Text(l10n.t('lang_switch_confirm')),
              ),
            ],
          );
        },
      );
    },
  );
  if (picked == null || picked == current || !context.mounted) return;

  await l10n.select(sl<GameServer>(), picked);
  if (!context.mounted) return;
  await context.read<AuthCubit>().bootstrap();
  onChanged?.call();
  if (leaveGame && context.mounted) context.go('/home');
}

class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({
    super.key,
    this.leaveGame = false,
    this.onChanged,
    this.cosmic = false,
  });

  final bool leaveGame;
  final VoidCallback? onChanged;
  final bool cosmic;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    if (!cosmic) {
      return IconButton.filledTonal(
        tooltip: l10n.t('lang_switch_tooltip'),
        onPressed: () => showLanguageSwitchDialog(
          context,
          leaveGame: leaveGame,
          onChanged: onChanged,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          foregroundColor: AppColors.textSecondary,
        ),
        icon: const Icon(Icons.language_rounded),
      );
    }
    return IconButton(
      tooltip: l10n.t('lang_switch_tooltip'),
      onPressed: () => showLanguageSwitchDialog(
        context,
        leaveGame: leaveGame,
        onChanged: onChanged,
      ),
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF94A3B8),
      ),
      icon: const Icon(Icons.language_rounded),
    );
  }
}
