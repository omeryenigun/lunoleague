import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/language_switch_button.dart';
import 'package:kelimelig/features/profile/presentation/avatar_pick.dart';
import 'package:kelimelig/injection.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  String? _avatar;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xB30F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.cosmicGreen.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.cosmicBlue.withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cosmicGreen, width: 1.6),
      ),
    );
  }

  Future<void> _choosePhoto() async {
    final encoded = await pickAvatarBase64(context);
    if (encoded == null || !mounted) return;
    setState(() => _avatar = encoded);
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(UserMessages.nicknameShort)),
      );
      return;
    }
    final cubit = context.read<AuthCubit>();
    await cubit.registerEmail(
      email: _email.text,
      password: _password.text,
      displayName: name,
      avatar: _avatar,
    );
    if (!mounted) return;
    if (cubit.state.error != null || cubit.state.user == null) return;
    await cubit.finishOnboarding();
    if (!mounted || cubit.state.error != null) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final avatar = _avatar;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
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
                            context.go('/login');
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
                    l10n.t('register_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color(0xFFF0FDF4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: InkWell(
                      onTap: state.loading ? null : _choosePhoto,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF1E293B),
                        backgroundImage: avatar == null
                            ? null
                            : MemoryImage(avatarBytes(avatar)!),
                        child: avatar == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 28)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('add_photo'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('photo_crop_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: _field(l10n.t('nickname')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: _field(l10n.t('email_label')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: _field(l10n.t('password_label')).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
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
                    label: l10n.t('email_register'),
                    showArrow: false,
                    onPressed: state.loading ? null : _register,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: state.loading
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/login');
                            }
                          },
                    child: Text(l10n.t('already_have_account')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
