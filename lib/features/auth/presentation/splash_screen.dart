import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.loading && !c.loading,
      listener: (context, state) async {
        if (!sl<L10n>().chosen) {
          context.go('/language');
          return;
        }
        if (state.user == null) {
          await context.read<AuthCubit>().anonymous();
        }
        if (context.mounted) context.go('/home');
      },
      child: const Scaffold(
        backgroundColor: AppColors.cosmicBg,
        body: CosmicBackdrop(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameLogo(size: 180),
                SizedBox(height: 12),
                _SplashTagline(),
                SizedBox(height: 28),
                CircularProgressIndicator(color: AppColors.cosmicGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashTagline extends StatelessWidget {
  const _SplashTagline();

  @override
  Widget build(BuildContext context) {
    return Text(
      sl<L10n>().t('tagline'),
      style: const TextStyle(color: Color(0xFF94A3B8)),
    );
  }
}
