import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/match/presentation/rival_notice_host.dart';
import 'package:kelimelig/injection.dart';

class MatchResultScreen extends StatefulWidget {
  const MatchResultScreen({super.key, required this.kind});

  final String kind;

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  MatchSnapshot? _snap;
  String? _me;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final server = sl<GameServer>();
    final user = await server.currentUser();
    try {
      final snap = await server.matchSnapshot(widget.kind);
      if (!mounted) return;
      final waiting = snap.rows.any((r) => !r.finished);
      setState(() {
        _me = user?.id;
        _snap = snap;
      });
      if (!waiting) _timer?.cancel();
    } catch (_) {
      if (!mounted) return;
      setState(() => _me = user?.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final snap = _snap;
    final me = snap?.rows.where((r) => r.userId == _me).firstOrNull;
    final waiting = snap == null || snap.rows.any((r) => !r.finished);
    final won = me != null && me.solved && me.rank == 1 && !waiting;
    final title = waiting
        ? l10n.t('duel_waiting')
        : won
            ? l10n.t('result_win_title')
            : l10n.t('result_lose_title');
    final titleColor = waiting
        ? const Color(0xFFF8FAFC)
        : won
            ? AppColors.cosmicGreen
            : AppColors.cosmicRed;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              RivalNoticeHost(kind: widget.kind),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              if (snap != null)
                for (final row in snap.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RowTile(row: row),
                  ),
              const SizedBox(height: 18),
              CosmicGlassCard(
                onTap: () => context.go(widget.kind == 'room' ? '/room' : '/duel'),
                colors: const [
                  AppColors.cosmicBlue,
                  AppColors.cosmicTeal,
                  AppColors.cosmicBlue,
                ],
                child: Center(
                  child: Text(
                    l10n.t('result_retry'),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CosmicGlassCard(
                onTap: () => context.go('/home'),
                child: Center(
                  child: Text(
                    l10n.t('home'),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w800,
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

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final MatchRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final color = !row.finished
        ? const Color(0xFF94A3B8)
        : row.solved
            ? AppColors.cosmicGreen
            : AppColors.cosmicRed;
    final state = !row.finished
        ? l10n.t('match_playing')
        : row.left
            ? l10n.t('match_timeout')
            : row.solved
                ? l10n.t('match_solved')
                : l10n.t('match_failed');
    final seconds = (row.millis / 1000).toStringAsFixed(1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                row.rank == 0 ? '–' : '${row.rank}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$state · ${row.guesses} ${l10n.t('match_guesses')} · ${seconds}s',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
