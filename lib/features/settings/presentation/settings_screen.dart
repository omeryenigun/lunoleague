import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/rewarded_ad_flow.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/services/motion_manager.dart';
import 'package:kelimelig/core/services/notification_service.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/widgets/game_version_label.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/language_switch_button.dart';
import 'package:kelimelig/injection.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final l10n = sl<L10n>();
    final league = user?.currentLeague ?? LeagueTier.bronze;
    final localeName =
        GameLocale.resolve(user?.locale ?? l10n.id).nativeName;

    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: ShimmerTitle(
                      text: l10n.t('settings'),
                      fontSize: 28,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SettingsAdPanel(),
              const SizedBox(height: 14),
              _SettingsSection(
                label: l10n.t('settings_lang_section'),
                child: InkWell(
                  onTap: () => showLanguageSwitchDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.t('language'),
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          localeName,
                          style: const TextStyle(
                            color: AppColors.cosmicGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                label: l10n.t('difficulty'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('difficulty_sub'),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DifficultyTabs(
                      selected: league,
                      locale: l10n.id,
                      enabled: user != null,
                      onChanged: (picked) async {
                        await sl<GameServer>().setLeague(picked);
                        if (context.mounted) {
                          await context.read<AuthCubit>().bootstrap();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                label: l10n.t('settings_prefs'),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: '🔊 ${l10n.t('sound')}',
                      value: user?.soundOn ?? true,
                      showDivider: true,
                      onChanged: (v) async {
                        sl<AudioManager>().enabled = v;
                        await sl<GameServer>().updateSettings(soundOn: v);
                        if (context.mounted) {
                          context.read<AuthCubit>().bootstrap();
                        }
                      },
                    ),
                    _ToggleRow(
                      label: '📳 ${l10n.t('haptic')}',
                      value: user?.hapticOn ?? true,
                      showDivider: true,
                      onChanged: (v) async {
                        sl<HapticManager>().enabled = v;
                        await sl<GameServer>().updateSettings(hapticOn: v);
                        if (context.mounted) {
                          context.read<AuthCubit>().bootstrap();
                        }
                      },
                    ),
                    _ToggleRow(
                      label: '✨ ${l10n.t('animations')}',
                      value: user?.animationsOn ?? true,
                      showDivider: true,
                      onChanged: (v) async {
                        sl<MotionManager>().enabled = v;
                        await sl<GameServer>().updateSettings(animationsOn: v);
                        if (context.mounted) {
                          context.read<AuthCubit>().bootstrap();
                        }
                      },
                    ),
                    _ToggleRow(
                      label: '🔔 ${l10n.t('notifications')}',
                      value: user?.notificationsOn ?? true,
                      showDivider: false,
                      onChanged: (v) async {
                        await sl<GameServer>().updateSettings(
                          notificationsOn: v,
                        );
                        await sl<NotificationService>().syncSchedule(
                          enabled: v,
                        );
                        if (context.mounted) {
                          context.read<AuthCubit>().bootstrap();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                label: l10n.t('settings_extra'),
                child: Column(
                  children: [
                    _ActionRow(
                      icon: '🛒',
                      label: l10n.t('shop'),
                      trailing: '›',
                      color: AppColors.cosmicGreen,
                      onTap: () => context.go('/shop'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Center(child: GameVersionLabel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAdPanel extends StatefulWidget {
  const _SettingsAdPanel();

  @override
  State<_SettingsAdPanel> createState() => _SettingsAdPanelState();
}

class _SettingsAdPanelState extends State<_SettingsAdPanel> {
  var _busy = false;
  int? _reward;

  @override
  void initState() {
    super.initState();
    sl<GameServer>().getConfig().then((config) {
      if (mounted) setState(() => _reward = config.adCoinReward);
    });
  }

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthCubit>();
    final before = auth.state.user?.coin ?? 0;
    final coins = await collectRewardedAdCoins(
      server: sl<GameServer>(),
      userId: auth.state.user?.id ?? '',
      balanceBefore: before,
    );
    if (!mounted) return;
    await auth.refreshUser();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          coins == 0 ? UserMessages.adUnavailable : '+$coins coin',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final reward = _reward ?? 15;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _watch,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x332A2208), Color(0xFF12160F)],
            ),
            border: Border.all(color: const Color(0x99C6A15A)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2414),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFFFFC107),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('watch_ad'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('settings_ad_sub'),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1408),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFC107),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+$reward',
                              style: const TextStyle(
                                color: Color(0xFFFFC107),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('🪙', style: TextStyle(fontSize: 14)),
                          ],
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DifficultyTabs extends StatelessWidget {
  const _DifficultyTabs({
    required this.selected,
    required this.locale,
    required this.enabled,
    required this.onChanged,
  });

  final LeagueTier selected;
  final String locale;
  final bool enabled;
  final ValueChanged<LeagueTier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x800A0F19),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2694A3B8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < LeagueTier.values.length; i++) ...[
            if (i > 0)
              Container(width: 1.5, height: 48, color: const Color(0x2694A3B8)),
            Expanded(
              child: _DiffTab(
                tier: LeagueTier.values[i],
                locale: locale,
                active: selected == LeagueTier.values[i],
                onTap: enabled
                    ? () => onChanged(LeagueTier.values[i])
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiffTab extends StatelessWidget {
  const _DiffTab({
    required this.tier,
    required this.locale,
    required this.active,
    required this.onTap,
  });

  final LeagueTier tier;
  final String locale;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.cosmicGreen.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tier.symbol, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      tier.labelFor(locale),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppColors.cosmicBg
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (active)
                const Positioned(
                  top: -2,
                  right: 2,
                  child: Text(
                    '✓',
                    style: TextStyle(
                      color: AppColors.cosmicBg,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.showDivider,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                _CosmicSwitch(value: value, onChanged: onChanged),
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

class _CosmicSwitch extends StatelessWidget {
  const _CosmicSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: value
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
                )
              : null,
          color: value ? null : const Color(0x80475565),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.cosmicGreen.withValues(alpha: 0.45),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Colors.white : const Color(0xFF94A3B8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String trailing;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
