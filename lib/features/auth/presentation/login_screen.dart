import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/dev_bypass_button.dart';
import 'package:kelimelig/features/auth/presentation/language_switch_button.dart';
import 'package:kelimelig/injection.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
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
    _name.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _afterLogin() async {
    final cubit = context.read<AuthCubit>();
    if (_name.text.trim().length >= 2) {
      await cubit.setName(_name.text.trim());
    }
    await cubit.finishOnboarding();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error!)),
                    );
                  }
                },
                builder: (context, state) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/onboarding');
                              }
                            },
                            icon: const Icon(Icons.chevron_left, size: 28),
                          ),
                          const Spacer(),
                          const LanguageSwitchButton(cosmic: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const ShimmerTitle(fontSize: 36),
                      const SizedBox(height: 10),
                      Text(
                        l10n.t('login'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFFF0FDF4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('login_lead'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: l10n.t('username'),
                          hintText: 'Ömer veya WordMaster42',
                          filled: true,
                          fillColor: const Color(0xB30F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.cosmicGreen.withValues(alpha: 0.35),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.cosmicBlue.withValues(alpha: 0.28),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.cosmicGreen,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (DevBypassButton.enabled) ...[
                        DevBypassButton(
                          primary: true,
                          resolveName: () => _name.text,
                          onDone: _afterLogin,
                        ),
                        const SizedBox(height: 16),
                      ],
                      CosmicContinueButton(
                        label: l10n.t('google'),
                        showArrow: false,
                        onPressed: state.loading
                            ? null
                            : () async {
                                await context.read<AuthCubit>().google();
                                await _afterLogin();
                              },
                      ),
                      if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: state.loading
                              ? null
                              : () async {
                                  await context.read<AuthCubit>().apple();
                                  await _afterLogin();
                                },
                          child: Text(l10n.t('apple')),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: state.loading
                            ? null
                            : () async {
                                await context.read<AuthCubit>().anonymous();
                                await _afterLogin();
                              },
                        child: Text(l10n.t('guest_continue')),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? l10n.t('login_hint_ios')
                            : l10n.t('login_hint_android'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
