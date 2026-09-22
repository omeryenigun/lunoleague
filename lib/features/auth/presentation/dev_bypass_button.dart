import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class DevBypassButton extends StatelessWidget {
  const DevBypassButton({
    super.key,
    this.displayName,
    this.resolveName,
    this.onDone,
    this.primary = false,
  });

  final String? displayName;
  final String Function()? resolveName;
  final VoidCallback? onDone;
  final bool primary;

  static bool get enabled => AppConstants.allowDevAuthBypass;

  AuthCubit? _cubitOf(BuildContext context) {
    try {
      return context.read<AuthCubit>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(BuildContext context) async {
    final raw = resolveName?.call() ?? displayName;
    final typed = raw?.trim();
    final name = (typed != null && typed.length >= 2) ? typed : null;
    final cubit = _cubitOf(context);
    if (cubit != null) {
      await cubit.devBypass(displayName: name);
    } else {
      await sl<GameServer>().signInWithGoogle(
        displayName: name ?? 'Test Oyuncu',
      );
    }
    if (context.mounted) onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    if (_cubitOf(context) != null) {
      return BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => _body(context, state.loading),
      );
    }
    return _body(context, false);
  }

  Widget _body(BuildContext context, bool loading) {
    final l10n = sl<L10n>();
    if (primary) {
      return Column(
        children: [
          CosmicContinueButton(
            label: l10n.t('dev_login'),
            onPressed: loading ? null : () => _run(context),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('dev_login_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      );
    }
    return FilledButton.tonal(
      onPressed: loading ? null : () => _run(context),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cosmicGreen.withValues(alpha: 0.16),
        foregroundColor: AppColors.cosmicGreen,
      ),
      child: Text(l10n.t('dev_upgrade')),
    );
  }
}
