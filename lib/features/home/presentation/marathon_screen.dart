import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class MarathonScreen extends StatefulWidget {
  const MarathonScreen({super.key});

  @override
  State<MarathonScreen> createState() => _MarathonScreenState();
}

class _MarathonScreenState extends State<MarathonScreen> {
  MarathonSnapshot? _snap;
  var _loading = true;
  var _busy = false;
  LeagueTier? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await sl<GameServer>().marathonSnapshot();
    if (!mounted) return;
    setState(() {
      _snap = snap;
      _loading = false;
      _open ??= snap.leagues
          .firstWhere(
            (row) => row.current,
            orElse: () => snap.leagues.first,
          )
          .league;
    });
  }

  MarathonLeagueStatus? get _current {
    final leagues = _snap?.leagues;
    if (leagues == null || leagues.isEmpty) return null;
    return leagues.firstWhere(
      (row) => row.current,
      orElse: () => leagues.first,
    );
  }

  Future<void> _continue() async {
    final mine = _current;
    if (mine == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (mine.state == MarathonRunState.paused) {
        final resumed = await _resumePaused();
        if (!resumed) return;
      }
      if (!mounted) return;
      await context.push('/game/endless');
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _resumePaused() async {
    final l10n = sl<L10n>();
    final user = await sl<GameServer>().currentUser();
    if (!mounted) return false;
    if (kIsWeb || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('marathon_ad_web'))),
      );
      return false;
    }
    final shown = await AdService().showRewarded(user.id);
    if (!shown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('marathon_ad_failed'))),
        );
      }
      return false;
    }
    await sl<GameServer>().restoreEndlessRunAfterAd();
    return true;
  }

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await sl<GameServer>().endEndlessRun();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final mine = _current;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(l10n.t('endless')),
      ),
      body: CosmicBackdrop(
        child: _loading || _snap == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _ContinueButton(
                    label: l10n.t('marathon_continue'),
                    busy: _busy,
                    onPressed: _continue,
                  ),
                  if (mine?.state == MarathonRunState.paused) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : _end,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE9D5FF),
                        side: const BorderSide(color: Color(0xFFC4A1FF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        l10n.t('marathon_end'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  for (final row in _snap!.leagues) ...[
                    _LeagueRow(
                      row: row,
                      localeId: l10n.id,
                      open: _open == row.league,
                      onTap: () => setState(() {
                        _open = _open == row.league ? null : row.league;
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFD7B8FF), Color(0xFFB794F6)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1028),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.row,
    required this.localeId,
    required this.open,
    required this.onTap,
  });

  final MarathonLeagueStatus row;
  final String localeId;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final state = switch (row.state) {
      MarathonRunState.running => l10n.t('marathon_state_running'),
      MarathonRunState.paused => l10n.t('marathon_state_paused'),
      MarathonRunState.none => l10n.t('marathon_state_none'),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: row.current ? const Color(0xFFC4A1FF) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    row.league.symbol,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.league.labelFor(localeId),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        state,
                        style: const TextStyle(
                          color: Color(0xFFC4A1FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _Stat(label: l10n.t('marathon_series'), value: '${row.series}'),
                  _Stat(label: l10n.t('marathon_best'), value: '${row.best}'),
                  _Stat(label: l10n.t('marathon_played'), value: '${row.played}'),
                  _Stat(
                    label: l10n.t('marathon_week'),
                    value: _place(row.weekRank, row.weekBest),
                  ),
                  _Stat(
                    label: l10n.t('marathon_month'),
                    value: _place(row.monthRank, row.monthBest),
                  ),
                  _Stat(
                    label: l10n.t('marathon_year'),
                    value: _place(row.yearRank, row.yearBest),
                  ),
                  _Stat(
                    label: l10n.t('marathon_all'),
                    value: _place(row.rank, row.best),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _place(int? rank, int best) {
  if (rank == null) return '—';
  return '#$rank · $best';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC4A1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
