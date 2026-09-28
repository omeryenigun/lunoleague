import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/rewarded_ad_flow.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

const _bg = Color(0xFF071018);
const _gold = Color(0xFFFBBF24);
const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF4ADE80);
const _muted = Color(0xFFB8C3D6);
const _hint = Color(0xFF64748B);

class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen>
    with SingleTickerProviderStateMixin {
  UserEntity? _user;
  List<DailyRewardSpec> _cycle = AppConfig.defaults().dailyRewardCycle;
  var _loading = true;
  var _busy = false;
  String? _error;
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final server = sl<GameServer>();
    final user = await server.currentUser();
    final config = await server.getConfig();
    if (!mounted) return;
    setState(() {
      _user = user;
      _cycle = config.dailyRewardCycle.isEmpty
          ? AppConfig.defaults().dailyRewardCycle
          : config.dailyRewardCycle;
      _loading = false;
    });
  }

  bool _claimedToday(UserEntity user) => user.lastRewardDate == DateKeys.dayKey();

  int _through(UserEntity user) {
    final cycle = user.rewardCycleDay.clamp(1, 7);
    if (_claimedToday(user) && cycle == 1) return 7;
    return cycle - 1;
  }

  int _shownDay(UserEntity user) => user.rewardCycleDay.clamp(1, 7);

  DailyRewardSpec _spec(int day) {
    for (final item in _cycle) {
      if (item.day == day) return item;
    }
    return DailyRewardSpec(day: day);
  }

  Future<void> _claim() async {
    final user = _user;
    if (user == null || _busy || _claimedToday(user)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _motion.repeat();
    try {
      final started = DateTime.now();
      await sl<GameServer>().claimDailyReward();
      const minShow = Duration(milliseconds: 1100);
      final left = minShow - DateTime.now().difference(started);
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (!mounted) return;
      await context.read<AuthCubit>().refreshUser();
      final next = await sl<GameServer>().currentUser();
      _motion.stop();
      await _motion.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _user = next;
        _busy = false;
      });
    } catch (e) {
      _motion.stop();
      _motion.value = 0;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppFailure ? e.message : 'Bir sorun oluştu. Lütfen tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final user = _user;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : user == null
            ? const Center(child: Text('Günlük ödül açılamadı.', style: TextStyle(color: _muted)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  GamePageHeader(title: l10n.t('daily_reward_title')),
                  _Series(through: _through(user)),
                  const SizedBox(height: 28),
                  Text(
                    _claimedToday(user)
                        ? l10n.t('daily_reward_tomorrow')
                        : l10n.t('daily_reward_today'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _hint,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RewardStage(
                    prizes: _prizes(l10n, _spec(_shownDay(user))),
                    gathering: _busy ? _motion : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
                  ],
                  const SizedBox(height: 16),
                  _ClaimButton(
                    claimed: _claimedToday(user),
                    busy: _busy,
                    label: _trUpper(
                      _claimedToday(user)
                          ? l10n.t('daily_reward_taken')
                          : l10n.t('daily_reward_claim'),
                    ),
                    onPressed: _claim,
                  ),
                  const SizedBox(height: 16),
                  const _AdCoinBanner(),
                ],
              ),
      ),
    );
  }

  List<_Prize> _prizes(L10n l10n, DailyRewardSpec spec) {
    final prizes = <_Prize>[];
    if (spec.coins > 0) {
      prizes.add(_Prize(
        icon: Icons.attach_money_rounded,
        glow: const Color(0xFFF5A623),
        amount: '${spec.coins}',
        caption: _trUpper(l10n.t('daily_reward_coins').replaceAll('{n}', '').trim()),
      ));
    }
    if (spec.hintLevel1 > 0) {
      prizes.add(_Prize(
        icon: Icons.abc_rounded,
        glow: const Color(0xFF60A5FA),
        amount: '${spec.hintLevel1}',
        caption: _trUpper(l10n.t('daily_reward_hint1')),
      ));
    }
    if (spec.hintLevel2 > 0) {
      prizes.add(_Prize(
        icon: Icons.menu_book_rounded,
        glow: const Color(0xFFC084FC),
        amount: '${spec.hintLevel2}',
        caption: _trUpper(l10n.t('daily_reward_hint2')),
      ));
    }
    if (spec.shield > 0) {
      prizes.add(_Prize(
        icon: Icons.shield_rounded,
        glow: const Color(0xFF4ADE80),
        amount: '${spec.shield}',
        caption: _trUpper(l10n.t('daily_reward_shield')),
      ));
    }
    if (prizes.isEmpty) {
      prizes.add(_Prize(
        icon: Icons.card_giftcard_rounded,
        glow: _amber,
        amount: '${spec.day}',
        caption: _trUpper(l10n.t('daily_reward_sub').replaceAll('{n}', '').trim()),
      ));
    }
    return prizes;
  }
}

String _trUpper(String value) =>
    value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

class _Prize {
  const _Prize({
    required this.icon,
    required this.glow,
    required this.amount,
    required this.caption,
  });

  final IconData icon;
  final Color glow;
  final String amount;
  final String caption;
}

class _Series extends StatelessWidget {
  const _Series({required this.through});

  final int through;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Row(
      children: [
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              color: day == 1
                                  ? Colors.transparent
                                  : (day - 1 <= through ? _green : const Color(0xFF3A4454)),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: day == 7
                                  ? Colors.transparent
                                  : (day <= through ? _green : const Color(0xFF3A4454)),
                            ),
                          ),
                        ],
                      ),
                      _DayNode(day: day, claimed: day <= through),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _trUpper(l10n.t('daily_reward_sub').replaceAll('{n}', '$day')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: day <= through ? _green : const Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayNode extends StatelessWidget {
  const _DayNode({required this.day, required this.claimed});

  final int day;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    final size = claimed ? 32.0 : 26.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: claimed ? const Color(0xFF3DDC84) : const Color(0xFF2C3544),
        boxShadow: claimed
            ? const [BoxShadow(color: Color(0x883DDC84), blurRadius: 12)]
            : null,
      ),
      child: claimed
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : Text(
              '$day',
              style: const TextStyle(
                color: Color(0xFF9AA3B2),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
    );
  }
}

class _RewardStage extends StatelessWidget {
  const _RewardStage({required this.prizes, required this.gathering});

  final List<_Prize> prizes;
  final Animation<double>? gathering;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A3544)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < prizes.length; i++) ...[
            if (i > 0) const SizedBox(height: 22),
            _PrizeMark(prize: prizes[i]),
          ],
          if (gathering != null) ...[
            const SizedBox(height: 8),
            _GatherMotion(
              animation: gathering!,
              icons: [for (final prize in prizes) prize.icon],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrizeMark extends StatelessWidget {
  const _PrizeMark({required this.prize});

  final _Prize prize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(prize.glow, Colors.white, 0.35)!,
                prize.glow,
              ],
            ),
            boxShadow: [
              BoxShadow(color: prize.glow.withValues(alpha: 0.55), blurRadius: 28),
            ],
          ),
          child: Icon(prize.icon, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          prize.amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          prize.caption,
          style: const TextStyle(
            color: Color(0xFF9AA3B2),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.claimed,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool claimed;
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1B2430),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3544)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF9AA3B2), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9AA3B2),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _amber,
        disabledBackgroundColor: const Color(0xFF1B2430),
        foregroundColor: const Color(0xFF1C1917),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.1),
      ),
    );
  }
}

class _GatherMotion extends StatelessWidget {
  const _GatherMotion({required this.animation, required this.icons});

  final Animation<double> animation;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    final marks = icons.isEmpty ? const [Icons.card_giftcard_rounded] : icons;
    return SizedBox(
      height: 92,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeIn.transform(animation.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < marks.length; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos((i / marks.length) * math.pi * 2 - math.pi / 2) * 78 * (1 - t),
                    math.sin((i / marks.length) * math.pi * 2 - math.pi / 2) * 28 * (1 - t),
                  ),
                  child: Opacity(
                    opacity: (1 - t * 0.15).clamp(0.2, 1),
                    child: Transform.scale(
                      scale: 1.15 - (0.55 * t),
                      child: Icon(marks[i], color: _gold, size: 28),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdCoinBanner extends StatefulWidget {
  const _AdCoinBanner();

  @override
  State<_AdCoinBanner> createState() => _AdCoinBannerState();
}

class _AdCoinBannerState extends State<_AdCoinBanner> {
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
      SnackBar(content: Text(coins == 0 ? UserMessages.adUnavailable : '+$coins coin')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final amount = _reward ?? 15;
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _busy ? null : _watch,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x66F59E0B)),
          ),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: _gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('home_ad_title'),
                      style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      l10n.t('home_ad_sub').replaceAll('{n}', '$amount'),
                      style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [_amber, Color(0xFFD97706)]),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1C1917)),
                        )
                      : Text(
                          l10n.t('home_ad_watch'),
                          style: const TextStyle(
                            color: Color(0xFF1C1917),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
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
