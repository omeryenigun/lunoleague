import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/features/profile/presentation/avatar_pick.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserEntity> _future = sl<GameServer>().profile();

  void _reload() {
    setState(() => _future = sl<GameServer>().profile());
  }

  Future<void> _openLogin() async {
    await context.push('/login');
    if (mounted) {
      await context.read<AuthCubit>().bootstrap();
      _reload();
    }
  }

  Future<void> _openRegister() async {
    await context.push('/register');
    if (mounted) {
      await context.read<AuthCubit>().bootstrap();
      _reload();
    }
  }

  Future<void> _changePhoto() async {
    final encoded = await pickAvatarBase64(context);
    if (encoded == null || !mounted) return;
    try {
      await sl<GameServer>().updateIdentity(avatar: encoded);
      if (mounted) _reload();
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _editIdentity(UserEntity user) async {
    final l10n = sl<L10n>();
    final first = TextEditingController(text: user.firstName ?? '');
    final last = TextEditingController(text: user.lastName ?? '');
    final nick = TextEditingController(text: user.displayName);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.t('first_name')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: last,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.t('last_name')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nick,
                decoration: InputDecoration(labelText: l10n.t('nickname')),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.t('save')),
                ),
              ),
            ],
          ),
        );
      },
    );
    final firstText = first.text;
    final lastText = last.text;
    final nickText = nick.text;
    first.dispose();
    last.dispose();
    nick.dispose();
    if (saved != true || !mounted) return;
    try {
      await sl<GameServer>().updateIdentity(
        firstName: firstText,
        lastName: lastText,
        nickname: nickText,
      );
      if (mounted) _reload();
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthCubit>();
    await auth.google();
    if (!mounted) return;
    final error = auth.state.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    if (auth.state.user?.authProvider != AuthProvider.google) {
      return;
    }
    await auth.finishOnboarding();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.cosmicGreen),
                );
              }
              final u = snap.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      const HomeTitleButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShimmerTitle(
                          text: l10n.t('profile'),
                          fontSize: 28,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: u.isAnonymous ? null : _changePhoto,
                    child: _AvatarRing(
                      avatar: u.avatar,
                      editable: !u.isAnonymous,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    u.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                  if (!u.isAnonymous &&
                      ((u.firstName ?? '').isNotEmpty || (u.lastName ?? '').isNotEmpty)) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!u.isAnonymous)
                    TextButton(
                      onPressed: () => _editIdentity(u),
                      child: Text(l10n.t('edit_profile')),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: u.isAnonymous
                        ? _GuestBadge(label: l10n.t('guest_badge'))
                        : _LeagueBadge(user: u, l10n: l10n),
                  ),
                  if (u.hasWeekTitle) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('week_champion'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.cosmicGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (u.isAnonymous) ...[
                    const SizedBox(height: 18),
                    _ProfileAuthCard(
                      subtitle: l10n.t('profile_login_sub'),
                      signInLabel: l10n.t('sign_in_title'),
                      appleLabel: l10n.t('apple'),
                      googleLabel: l10n.t('google'),
                      orLabel: l10n.t('or_divider'),
                      registerLabel: l10n.t('email_register'),
                      onSignIn: _openLogin,
                      onGoogle: _signInWithGoogle,
                      onRegister: _openRegister,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          icon: '🔥',
                          label: 'Streak',
                          value: '${u.streak} gün',
                          color: AppColors.cosmicRed,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '⭐',
                          label: 'Level',
                          value: '${u.level}',
                          color: AppColors.cosmicGold,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '🪙',
                          label: 'Coin',
                          value: '${u.coin}',
                          color: AppColors.cosmicGold,
                          showDivider: true,
                        ),
                        _StatRow(
                          icon: '🛡️',
                          label: 'Streak kalkanı',
                          value: '${u.shields}',
                          color: AppColors.cosmicBlue,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  if (u.badges.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final b in u.badges)
                          Chip(
                            backgroundColor: const Color(0x991E293B),
                            side: const BorderSide(color: Color(0x2694A3B8)),
                            label: Text(
                              _badgeLabel(b),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _MenuRow(
                          label: '📊 İstatistikler',
                          onTap: () => context.push('/statistics'),
                          showDivider: true,
                        ),
                        _MenuRow(
                          label: '🏁 ${l10n.t('marathon_stats')}',
                          onTap: () => context.push('/marathon'),
                          showDivider: true,
                        ),
                        _MenuRow(
                          label: '🏅 Başarımlar',
                          onTap: () => context.push('/achievements'),
                          showDivider: true,
                        ),
                        _MenuRow(
                          label: '📖 Kelime Defteri',
                          onTap: () => context.push('/word-book'),
                          showDivider: u.isAnonymous,
                        ),
                        if (u.isAnonymous)
                          _MenuRow(
                            label: '🔐 ${l10n.t('login_or_register')}',
                            onTap: _openLogin,
                            showDivider: false,
                          ),
                      ],
                    ),
                  ),
                  if (!u.isAnonymous) ...[
                    const SizedBox(height: 22),
                    OutlinedButton(
                      onPressed: () async {
                        await context.read<AuthCubit>().signOut();
                        if (context.mounted) context.go('/login');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cosmicRed,
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.cosmicRed.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(l10n.t('sign_out')),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _badgeLabel(String id) {
    if (id.startsWith('month_')) return 'Aylık şampiyon';
    return switch (id) {
      'season_legend' => 'Sezon efsanesi',
      'season_epic' => 'Sezon %10',
      'season_play' => 'Sezon katılım',
      'year_honor' => 'Yıllık onur',
      _ => id,
    };
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({this.avatar, this.editable = false});

  final String? avatar;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 108,
        height: 108,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: math.pi,
                  colors: [
                    Color(0xFF4ADE80),
                    Color(0xFF22D3EE),
                    Color(0xFFA855F7),
                    Color(0xFFF59E0B),
                    Color(0xFF4ADE80),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4022C55E),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0E1A),
                ),
                child: Center(child: _avatarFace(avatar)),
              ),
            ),
            if (editable)
              const Positioned(
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF14532D),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: Color(0xFFDCFCE7),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _avatarFace(String? avatar) {
  if (avatar != null && avatar.isNotEmpty) {
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(avatar),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }
  return const Text('👑', style: TextStyle(fontSize: 48));
}

class _GuestBadge extends StatelessWidget {
  const _GuestBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x1FF59E0B),
        border: Border.all(color: const Color(0x80F59E0B)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFBBF24),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _LeagueBadge extends StatelessWidget {
  const _LeagueBadge({required this.user, required this.l10n});

  final UserEntity user;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final leagueColor = AppColors.forLeague(user.currentLeague);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            leagueColor.withValues(alpha: 0.18),
            leagueColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: leagueColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        '${user.currentLeague.symbol} ${user.currentLeague.labelFor(l10n.id).toUpperCase()} ${l10n.t('league').toUpperCase()}',
        style: TextStyle(
          color: leagueColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ProfileAuthCard extends StatelessWidget {
  const _ProfileAuthCard({
    required this.subtitle,
    required this.signInLabel,
    required this.appleLabel,
    required this.googleLabel,
    required this.orLabel,
    required this.registerLabel,
    required this.onSignIn,
    required this.onGoogle,
    required this.onRegister,
  });

  final String subtitle;
  final String signInLabel;
  final String appleLabel;
  final String googleLabel;
  final String orLabel;
  final String registerLabel;
  final VoidCallback onSignIn;
  final VoidCallback onGoogle;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1729),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProfilePrimaryCta(label: signInLabel, onPressed: onSignIn),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: true,
                  child: _ProfileSocialBtn(
                    icon: const Icon(
                      Icons.apple,
                      size: 16,
                      color: Color(0xFFE2E8F0),
                    ),
                    label: appleLabel,
                    foreground: const Color(0xFFE2E8F0),
                    borderColor: const Color(0x40FFFFFF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileSocialBtn(
                  icon: const _GoogleMark(),
                  label: googleLabel,
                  foreground: const Color(0xFF8AB4F8),
                  borderColor: const Color(0x594285F4),
                  onPressed: onGoogle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: ColoredBox(
                  color: Color(0xFF1E293B),
                  child: SizedBox(height: 1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  orLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Expanded(
                child: ColoredBox(
                  color: Color(0xFF1E293B),
                  child: SizedBox(height: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProfileRegisterBtn(label: registerLabel, onPressed: onRegister),
        ],
      ),
    );
  }
}

class _ProfilePrimaryCta extends StatelessWidget {
  const _ProfilePrimaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF22C55E),
            Color(0xFF06B6D4),
            Color(0xFFA855F7),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D22C55E),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSocialBtn extends StatelessWidget {
  const _ProfileSocialBtn({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.borderColor,
    this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color foreground;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131A2B),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRegisterBtn extends StatelessWidget {
  const _ProfileRegisterBtn({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: const Color(0xFF334155),
            radius: 10,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? 5.0 : 3.5;
        final next = math.min(distance + length, metric.length);
        if (draw) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.2, 1.5, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.2, 1.2, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.85, 1.35, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.55, 1.35, false, paint);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width - stroke * 0.15, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: child,
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.showDivider,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 17, shadows: [
                Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
              ])),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0x1494A3B8)),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: const Color(0xFFF1F5F9).withValues(alpha: 0.55),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0x1494A3B8)),
      ],
    );
  }
}

Future<({UserEntity user, HomeSnapshot home, CompetitionSnapshot competition})>
    _loadStats() async {
  final server = sl<GameServer>();
  final user = await server.profile();
  final home = await server.homeSnapshot();
  final competition = await server.competitionSnapshot();
  return (user: user, home: home, competition: competition);
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: GamePageHeader(
                  title: 'İstatistik',
                  bottomSpacing: 0,
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _loadStats(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.cosmicGreen,
                        ),
                      );
                    }
                    final bundle = snap.data!;
                    final u = bundle.user;
                    final lost = u.gamesPlayed - u.gamesWon;
                    final fastest = u.fastestSolveSeconds;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _StatsCompare(bundle: bundle),
                        const SizedBox(height: 16),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🎮',
                              label: 'Toplam oyun',
                              value: '${u.gamesPlayed}',
                              iconColors: const [
                                Color(0x403498DB),
                                Color(0x262980B9),
                              ],
                              iconBorder: const Color(0x663498DB),
                            ),
                            _RichStat(
                              icon: '✅',
                              label: 'Kazanılan',
                              value: '${u.gamesWon}',
                              valueColor: AppColors.cosmicGreen,
                              iconColors: const [
                                Color(0x402ECC71),
                                Color(0x261ABC9C),
                              ],
                              iconBorder: const Color(0x662ECC71),
                            ),
                            _RichStat(
                              icon: '❌',
                              label: 'Kaybedilen',
                              value: '$lost',
                              valueColor: AppColors.cosmicRed,
                              iconColors: const [
                                Color(0x40E74C3C),
                                Color(0x26C0392B),
                              ],
                              iconBorder: const Color(0x66E74C3C),
                            ),
                            _RichStat(
                              icon: '📊',
                              label: 'Kazanma oranı',
                              value:
                                  '%${(u.winRate * 100).toStringAsFixed(0)}',
                              valueColor: AppColors.cosmicTeal,
                              iconColors: const [
                                Color(0x401ABC9C),
                                Color(0x2616A085),
                              ],
                              iconBorder: const Color(0x661ABC9C),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🎯',
                              label: 'Ortalama tahmin',
                              value: u.averageGuesses.toStringAsFixed(1),
                              iconColors: const [
                                Color(0x409B59B6),
                                Color(0x268E44AD),
                              ],
                              iconBorder: const Color(0x669B59B6),
                            ),
                            _RichStat(
                              icon: '⚡',
                              label: 'En hızlı çözüm',
                              value: fastest == null ? '—' : '$fastest sn',
                              valueColor: fastest == null
                                  ? const Color(0xFF475569)
                                  : AppColors.cosmicGold,
                              iconColors: const [
                                Color(0x40F1C40F),
                                Color(0x26E67E22),
                              ],
                              iconBorder: const Color(0x66F1C40F),
                            ),
                            _RichStat(
                              icon: '🏆',
                              label: 'İlk tahminde çözüm',
                              value: '${u.firstGuessWins}',
                              iconColors: const [
                                Color(0x40E67E22),
                                Color(0x26D35400),
                              ],
                              iconBorder: const Color(0x66E67E22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '🔥',
                              label: 'En uzun Daily streak',
                              value: '${u.longestStreak}',
                              valueColor: AppColors.cosmicRed,
                              iconColors: const [
                                Color(0x40E74C3C),
                                Color(0x26C0392B),
                              ],
                              iconBorder: const Color(0x66E74C3C),
                            ),
                            _RichStat(
                              icon: '♾️',
                              label: 'En uzun Kelime Maratonu',
                              value: '${u.endlessBest}',
                              valueColor: const Color(0xFF9B59B6),
                              iconColors: const [
                                Color(0x409B59B6),
                                Color(0x268E44AD),
                              ],
                              iconBorder: const Color(0x669B59B6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          rows: [
                            _RichStat(
                              icon: '📖',
                              label: 'Öğrenilen kelime',
                              value: '${u.wordsLearned}',
                              iconColors: const [
                                Color(0x40FF6B9D),
                                Color(0x26E64C8A),
                              ],
                              iconBorder: const Color(0x66FF6B9D),
                            ),
                            _RichStat(
                              icon: '👑',
                              label: 'Lig birinciliği',
                              value: '${u.leagueWins}',
                              valueColor: AppColors.cosmicGold,
                              iconColors: const [
                                Color(0x40F1C40F),
                                Color(0x26E67E22),
                              ],
                              iconBorder: const Color(0x66F1C40F),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCompare extends StatefulWidget {
  const _StatsCompare({required this.bundle});

  final ({UserEntity user, HomeSnapshot home, CompetitionSnapshot competition})
      bundle;

  @override
  State<_StatsCompare> createState() => _StatsCompareState();
}

enum _StatsSpan { all, today, month, year }

class _StatsCompareState extends State<_StatsCompare> {
  var _span = _StatsSpan.all;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final user = widget.bundle.user;
    final competition = widget.bundle.competition;
    final board = switch (_span) {
      _StatsSpan.month => competition.month,
      _StatsSpan.year => competition.year,
      _ => competition.week,
    };
    final mine = board.where((e) => e.isCurrentUser).firstOrNull;
    final others = board.where((e) => !e.isCurrentUser);
    final average = others.isEmpty
        ? 0
        : others.map((e) => e.points).reduce((a, b) => a + b) / others.length;
    final today = _span == _StatsSpan.today;
    final playedToday = widget.bundle.home.dailyStatus == DailyStatus.completed ||
        widget.bundle.home.dailyIndex > 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3346E8A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatsTab(
                  label: l10n.t('stats_all'),
                  selected: _span == _StatsSpan.all,
                  onTap: () => setState(() => _span = _StatsSpan.all),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_today'),
                  selected: _span == _StatsSpan.today,
                  onTap: () => setState(() => _span = _StatsSpan.today),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_month'),
                  selected: _span == _StatsSpan.month,
                  onTap: () => setState(() => _span = _StatsSpan.month),
                ),
                const SizedBox(width: 8),
                _StatsTab(
                  label: l10n.t('stats_year'),
                  selected: _span == _StatsSpan.year,
                  onTap: () => setState(() => _span = _StatsSpan.year),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(l10n.t('stats_you'), style: _head)),
              Expanded(child: Text(l10n.t('stats_field'), style: _head)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompareTile(
                  value: today
                      ? (playedToday ? l10n.t('stats_daily_done') : '—')
                      : '${mine?.points ?? (_span == _StatsSpan.all ? widget.bundle.home.leaguePoints : 0)}',
                  label: today ? l10n.t('stats_daily') : l10n.t('stats_points'),
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompareTile(
                  value: today
                      ? '—'
                      : (others.isEmpty ? '—' : average.round().toString()),
                  label: l10n.t('stats_avg_points'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompareTile(
                  value: today
                      ? '${user.streak}'
                      : user.averageGuesses.toStringAsFixed(1),
                  label: today ? l10n.t('stats_streak') : l10n.t('stats_avg_guess'),
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompareTile(
                  value: today ? '${user.longestStreak}' : '—',
                  label: today
                      ? l10n.t('stats_best_streak')
                      : l10n.t('stats_avg_guess'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (today)
            const SizedBox.shrink()
          else if (mine == null || board.length < 2)
            Text(
              l10n.t('stats_no_rank'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            _RankBars(
              board: board,
              caption: l10n
                  .t('stats_rank')
                  .replaceAll('{count}', '${board.length}')
                  .replaceAll('{rank}', '${mine.rank}'),
            ),
        ],
      ),
    );
  }
}

const _head = TextStyle(
  color: Color(0xFF94A3B8),
  fontWeight: FontWeight.w700,
  fontSize: 13,
);

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x3346E8A0) : const Color(0x221E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.cosmicGreen : const Color(0x2294A3B8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cosmicGreen : const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CompareTile extends StatelessWidget {
  const _CompareTile({
    required this.value,
    required this.label,
    this.emphasize = false,
  });

  final String value;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.cosmicGreen : const Color(0xFFF8FAFC);
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RankBars extends StatelessWidget {
  const _RankBars({required this.board, required this.caption});

  final List<LeaderboardEntry> board;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ranked = [...board]..sort((a, b) => a.rank.compareTo(b.rank));
    final shown = ranked.length <= 7
        ? ranked
        : _window(ranked);
    final maxPoints = shown.map((e) => e.points).fold<int>(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in shown)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 18 + 70 * (entry.points / maxPoints),
                        decoration: BoxDecoration(
                          color: entry.isCurrentUser
                              ? AppColors.cosmicGreen
                              : const Color(0xFF1E3A34),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          caption,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<LeaderboardEntry> _window(List<LeaderboardEntry> ranked) {
    final index = ranked.indexWhere((e) => e.isCurrentUser);
    final start = (index - 3).clamp(0, ranked.length - 7);
    return ranked.sublist(start, start + 7);
  }
}

class _RichStat {
  const _RichStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColors,
    required this.iconBorder,
    this.valueColor = const Color(0xFFF8FAFC),
  });

  final String icon;
  final String label;
  final String value;
  final List<Color> iconColors;
  final Color iconBorder;
  final Color valueColor;
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.rows});

  final List<_RichStat> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _RichStatRow(stat: rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, color: Color(0x1494A3B8)),
          ],
        ],
      ),
    );
  }
}

class _RichStatRow extends StatelessWidget {
  const _RichStatRow({required this.stat});

  final _RichStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: stat.iconColors,
              ),
              border: Border.all(color: stat.iconBorder),
              boxShadow: [
                BoxShadow(
                  color: stat.iconBorder.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(stat.icon, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stat.label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            stat.value,
            style: TextStyle(
              color: stat.valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              shadows: [
                Shadow(
                  color: stat.valueColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
