import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/match/match_copy.dart';
import 'package:kelimelig/injection.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  MatchSnapshot? _snap;
  String? _error;
  Timer? _timer;
  var _searching = false;

  @override
  void initState() {
    super.initState();
    _seek();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_searching) {
      unawaited(sl<GameServer>().duelCancel());
    }
    super.dispose();
  }

  Future<void> _seek() async {
    setState(() => _error = null);
    try {
      final snap = await sl<GameServer>().duelSeek();
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _searching = snap.status == 'searching';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = matchErrorText(sl<L10n>(), e);
        _searching = false;
      });
    }
  }

  Future<void> _poll() async {
    if (_snap != null && _snap!.status != 'searching') return;
    try {
      final snap = await sl<GameServer>().duelPoll();
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _searching = snap.status == 'searching';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = matchErrorText(sl<L10n>(), e);
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final snap = _snap;
    final ready = snap != null && snap.ready;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  CosmicGlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.t('duel_title'),
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                l10n.t('duel_sub'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.cosmicRed, fontSize: 16),
                )
              else if (ready)
                Text(
                  '${l10n.t('duel_found')}${snap.opponentName == null ? '' : '\n${snap.opponentName}'}',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.cosmicTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.t('duel_searching'),
                        style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 16),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              if (ready)
                _MatchButton(
                  label: l10n.t('duel_start'),
                  onTap: () => context.push('/game/duel'),
                )
              else if (_error != null)
                _MatchButton(label: l10n.t('duel_start'), onTap: _seek)
              else
                _MatchButton(
                  label: l10n.t('duel_cancel'),
                  onTap: () => context.go('/home'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchButton extends StatelessWidget {
  const _MatchButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicGlassCard(
      onTap: onTap,
      colors: const [
        AppColors.cosmicBlue,
        AppColors.cosmicTeal,
        AppColors.cosmicBlue,
      ],
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
