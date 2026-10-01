import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/language_switch_button.dart';
import 'package:kelimelig/injection.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
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
    _email.dispose();
    _password.dispose();
    _enter.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
    );
  }

  Future<void> _afterLogin() async {
    final cubit = context.read<AuthCubit>();
    if (cubit.state.error != null || cubit.state.user == null) return;
    await cubit.finishOnboarding();
    if (!mounted || cubit.state.error != null) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _signInEmail() async {
    final cubit = context.read<AuthCubit>();
    await cubit.signInEmail(
      email: _email.text,
      password: _password.text,
    );
    await _afterLogin();
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                        l10n.t('sign_in_title'),
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
                        controller: _email,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: _fieldDecoration(l10n.t('email_label')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: _fieldDecoration(l10n.t('password_label'))
                            .copyWith(
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      CosmicContinueButton(
                        label: l10n.t('sign_in_title'),
                        showArrow: false,
                        onPressed: state.loading ? null : _signInEmail,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: state.loading ? null : () => context.push('/register'),
                        child: Text(l10n.t('email_register')),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFF334155))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              l10n.t('or_divider'),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFF334155))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: state.loading
                            ? null
                            : () async {
                                await context.read<AuthCubit>().google();
                                await _afterLogin();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF0FDF4),
                          side: BorderSide(
                            color:
                                AppColors.cosmicGreen.withValues(alpha: 0.5),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(l10n.t('google')),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: state.loading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.t('apple_soon'))),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF0FDF4),
                          side: BorderSide(
                            color: AppColors.cosmicGreen.withValues(alpha: 0.5),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(l10n.t('apple')),
                      ),
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
