import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/device_link.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/widgets/game_boot_progress.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  var _starting = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final online = await sl<DeviceLink>().refresh();
    if (!mounted) return;
    if (!online) {
      context.go('/home');
      return;
    }
    setState(() => _starting = true);
    await context.read<AuthCubit>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => previous.loading && !current.loading,
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
      child: Scaffold(
        backgroundColor: AppColors.cosmicBg,
        body: CosmicBackdrop(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameLogo(size: 180),
                const SizedBox(height: 12),
                const _SplashTagline(),
                if (_starting) ...[
                  const SizedBox(height: 28),
                  const GameBootProgress(),
                ],
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
