import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

const _kBg = Color(0xFF0D1117);
const _kPanel = Color(0xFF161B22);
const _kLine = Color(0xFF21262D);
const _kMuted = Color(0xFF8B949E);
const _kText = Color(0xFFE6EDF3);
const _kGold = Color(0xFFF7B733);
const _kGreen = Color(0xFF238636);
const _kGreenLine = Color(0xFF2EA043);

class MarathonScreen extends StatefulWidget {
  const MarathonScreen({super.key});

  @override
  State<MarathonScreen> createState() => _MarathonScreenState();
}

class _MarathonScreenState extends State<MarathonScreen> {
  MarathonSnapshot? _snap;
  UserEntity? _user;
  var _loading = true;
  var _busy = false;
  LeagueTier? _open;
  var _span = _MarathonSpan.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final server = sl<GameServer>();
    final snap = await server.marathonSnapshot();
    final user = await server.currentUser();
    if (!mounted) return;
    setState(() {
      _snap = snap;
      _user = user;
      _loading = false;
      _open ??= snap.leagues
          .firstWhere(
            (row) => row.current,
            orElse: () => snap.leagues.first,
          )
          .league;
    });
  }

  MarathonLeagueStatus? get _selected {
    final leagues = _snap?.leagues;
    if (leagues == null || leagues.isEmpty || _open == null) return null;
    for (final row in leagues) {
      if (row.league == _open) return row;
    }
    return null;
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

  String _continueLabel(L10n l10n, MarathonLeagueStatus? mine) {
    final state = mine?.state;
    if (state == MarathonRunState.running ||
        state == MarathonRunState.paused) {
      return l10n.t('marathon_resume');
    }
    final ended = (mine?.played ?? 0) > 0 || (mine?.best ?? 0) > 0;
    if (state == MarathonRunState.none && ended) {
      return l10n.t('marathon_new');
    }
    return l10n.t('marathon_start');
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
    final selected = _selected;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: _loading || _snap == null
            ? const Center(
                child: CircularProgressIndicator(color: _kGold),
              )
            : Column(
                children: [
                  _TopBar(
                    title: l10n.t('endless'),
                    continueLabel: _continueLabel(l10n, mine),
                    endLabel: l10n.t('marathon_end'),
                    stateLabel: switch (mine?.state) {
                      MarathonRunState.running =>
                        l10n.t('marathon_state_running'),
                      MarathonRunState.paused =>
                        l10n.t('marathon_state_paused'),
                      _ => null,
                    },
                    paused: mine?.state == MarathonRunState.paused,
                    busy: _busy,
                    onContinue: _continue,
                    onEnd: _end,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              for (final row in _snap!.leagues) ...[
                                if (row != _snap!.leagues.first)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: _LeagueTab(
                                    row: row,
                                    selected: _open == row.league,
                                    locale: l10n.id,
                                    onTap: () =>
                                        setState(() => _open = row.league),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              for (final span in _MarathonSpan.values) ...[
                                if (span != _MarathonSpan.values.first)
                                  const SizedBox(width: 6),
                                Expanded(
                                  child: _TimePill(
                                    label: l10n.t(span.labelKey),
                                    selected: _span == span,
                                    onTap: () => setState(() => _span = span),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (selected != null)
                          _BoardSection(
                            row: selected,
                            span: _span,
                            playerName: _user?.displayName ?? l10n.t('guest'),
                            placeInvite: mine == null ||
                                    mine.state == MarathonRunState.none
                                ? l10n.t('marathon_take_place')
                                : null,
                          ),
                        const SizedBox(height: 16),
                        const _RulesCard(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.continueLabel,
    required this.endLabel,
    required this.stateLabel,
    required this.paused,
    required this.busy,
    required this.onContinue,
    required this.onEnd,
  });

  final String title;
  final String continueLabel;
  final String endLabel;
  final String? stateLabel;
  final bool paused;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final status = stateLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GamePageHeader(title: title, bottomSpacing: 12),
          _ContinueButton(
            label: continueLabel,
            busy: busy,
            onPressed: onContinue,
          ),
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(
                color: _kGold,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          if (paused) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: busy ? null : onEnd,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE6EDF3),
                side: const BorderSide(color: Color(0xFF30363D)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                endLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
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
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFD7B8FF), Color(0xFFB794F6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC4A1FF).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
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
      ),
    );
  }
}

enum _MarathonSpan {
  week('marathon_week'),
  month('marathon_month'),
  year('marathon_year'),
  all('marathon_all');

  const _MarathonSpan(this.labelKey);
  final String labelKey;
}

class _LeagueTab extends StatelessWidget {
  const _LeagueTab({
    required this.row,
    required this.selected,
    required this.locale,
    required this.onTap,
  });

  final MarathonLeagueStatus row;
  final bool selected;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _LeagueTabStyle.of(row.league);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: style.active,
                  )
                : null,
            color: selected ? null : _kPanel,
            border: Border.all(
              color: selected ? style.border : _kLine,
            ),
          ),
          child: Column(
            children: [
              Text(row.league.symbol, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                row.league.labelFor(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? style.fg : _kText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueTabStyle {
  const _LeagueTabStyle({
    required this.active,
    required this.border,
    required this.fg,
  });

  final List<Color> active;
  final Color border;
  final Color fg;

  static _LeagueTabStyle of(LeagueTier league) => switch (league) {
        LeagueTier.bronze => const _LeagueTabStyle(
            active: [Color(0xFF8B5A2B), Color(0xFFCD7F32)],
            border: Color(0xFFCD7F32),
            fg: Color(0xFFFFFFFF),
          ),
        LeagueTier.silver => const _LeagueTabStyle(
            active: [Color(0xFF6B7280), Color(0xFFC0C0C0)],
            border: Color(0xFFC0C0C0),
            fg: Color(0xFF111111),
          ),
        LeagueTier.gold => const _LeagueTabStyle(
            active: [Color(0xFFB8860B), Color(0xFFFFD700)],
            border: Color(0xFFFFD700),
            fg: Color(0xFF111111),
          ),
      };
}

class _TimePill extends StatelessWidget {
  const _TimePill({
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
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _kGreen : _kPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kGreenLine : _kLine),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFFFFFFFF) : _kMuted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.row,
    required this.span,
    required this.playerName,
    this.placeInvite,
  });

  final MarathonLeagueStatus row;
  final _MarathonSpan span;
  final String playerName;
  final String? placeInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final board = _fillMarathonDisplayBoard(
      league: row.league,
      span: span,
      playerName: playerName,
      playerScore: switch (span) {
        _MarathonSpan.week => row.weekBest,
        _MarathonSpan.month => row.monthBest,
        _MarathonSpan.year => row.yearBest,
        _MarathonSpan.all => row.best,
      },
      apiRows: switch (span) {
        _MarathonSpan.week => row.weekBoard,
        _MarathonSpan.month => row.monthBoard,
        _MarathonSpan.year => row.yearBoard,
        _MarathonSpan.all => row.allBoard,
      },
    );
    final top3 = board.take(3).toList();
    final rest = board.skip(3).toList();
    final me = board.where((row) => row.player.isMe).firstOrNull;
    final list = [
      if (me != null && me.rank <= 3) me,
      ...rest,
    ];
    final invite = placeInvite;
    return Column(
      children: [
        if (invite != null && invite.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              invite,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kGold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        _Podium(top: top3),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _kPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kLine),
            ),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: _kLine),
                  _RankRow(
                    entry: list[i],
                    subtitle: l10n
                        .t('marathon_series_sub')
                        .replaceAll('{n}', '${list[i].player.score}'),
                    youLabel: l10n.t('marathon_you'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<_RankedPlayer> top;

  @override
  Widget build(BuildContext context) {
    _RankedPlayer? at(int rank) {
      for (final row in top) {
        if (row.rank == rank) return row;
      }
      return top.length >= rank ? top[rank - 1] : null;
    }

    final second = at(2);
    final first = at(1);
    final third = at(3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumItem(
              entry: second,
              place: 2,
              height: 70,
              colors: const [Color(0xFFE0E0E0), Color(0xFF909090)],
              ring: const Color(0xFFC0C0C0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumItem(
              entry: first,
              place: 1,
              height: 90,
              colors: const [Color(0xFFFFD700), Color(0xFFB8860B)],
              ring: const Color(0xFFFFD700),
              glow: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumItem(
              entry: third,
              place: 3,
              height: 55,
              colors: const [Color(0xFFCD7F32), Color(0xFF8B5A2B)],
              ring: const Color(0xFFCD7F32),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.entry,
    required this.place,
    required this.height,
    required this.colors,
    required this.ring,
    this.glow = false,
  });

  final _RankedPlayer? entry;
  final int place;
  final double height;
  final List<Color> colors;
  final Color ring;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final player = entry?.player;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kPanel,
            border: Border.all(color: ring, width: 3),
            boxShadow: glow
                ? const [
                    BoxShadow(color: Color(0x80FFD700), blurRadius: 16),
                  ]
                : null,
          ),
          child: Text(
            _initial(player?.name ?? '?'),
            style: const TextStyle(
              color: _kText,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          player?.name ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${player?.score ?? 0}',
          style: const TextStyle(color: _kMuted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
          child: Text(
            '$place',
            style: const TextStyle(
              color: Color(0x99000000),
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.subtitle,
    required this.youLabel,
  });

  final _RankedPlayer entry;
  final String subtitle;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    final me = entry.player.isMe;
    final name = me ? '${entry.player.name}  · $youLabel' : entry.player.name;
    return Container(
      decoration: me
          ? const BoxDecoration(
              color: Color(0x1F2EA043),
              border: Border(
                left: BorderSide(color: _kGreenLine, width: 3),
              ),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF21262D),
            ),
            child: Text(
              _initial(entry.player.name),
              style: const TextStyle(
                color: _kText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: me ? const Color(0xFF4ADE80) : _kText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${entry.player.score}',
            style: const TextStyle(
              color: _kGold,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  static const _keys = [
    'marathon_rule_league',
    'marathon_rule_no_reset',
    'marathon_rule_miss',
    'marathon_rule_ad',
    'marathon_rule_end',
    'marathon_rule_ranks',
    'marathon_rule_tie',
    'marathon_rule_continue',
    'marathon_rule_view',
    'marathon_rule_points',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kLine),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('marathon_rules_title'),
                style: const TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              for (final key in _keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(color: _kGold, height: 1.4),
                      ),
                      Expanded(
                        child: Text(
                          l10n.t(key),
                          style: const TextStyle(
                            color: _kMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kSeedNames = [
  'Ahmet', 'Zeynep', 'Mert', 'Elif', 'Can', 'Selin', 'Burak', 'Ayşe',
  'Emre', 'Deniz', 'Kerem', 'Ece', 'Onur', 'İrem', 'Yusuf', 'Naz',
  'Barış', 'Sude', 'Kaan', 'Melis', 'Cem', 'Duru', 'Eren', 'Ada',
  'Arda', 'Defne', 'Berk', 'Lara', 'Kuzey', 'Nehir', 'Alp', 'Yağmur',
  'Mira', 'Tuna', 'Ela', 'Atlas', 'Lina', 'Rüzgar', 'Asya', 'Doruk',
  'Nil', 'Çınar', 'Azra', 'Umut', 'Okan', 'İpek', 'Bora', 'Sena',
  'Taner', 'Gökçe', 'Ozan', 'Eylül', 'Aylin', 'Serkan', 'Ceren', 'Hakan',
  'Pelin', 'Yiğit', 'Esra', 'Kaanalp',
];

class _BoardPlayer {
  const _BoardPlayer({
    required this.name,
    required this.score,
    required this.isMe,
  });

  final String name;
  final int score;
  final bool isMe;
}

class _RankedPlayer {
  const _RankedPlayer({required this.rank, required this.player});

  final int rank;
  final _BoardPlayer player;
}

List<_RankedPlayer> _fillMarathonDisplayBoard({
  required LeagueTier league,
  required _MarathonSpan span,
  required String playerName,
  required int playerScore,
  required List<MarathonBoardPlayer> apiRows,
}) {
  final used = <String>{};
  final raw = <_BoardPlayer>[];

  void add(_BoardPlayer player) {
    final key = player.name.trim().toLowerCase();
    if (key.isEmpty) return;
    if (player.isMe) {
      raw.removeWhere(
        (row) => row.isMe || row.name.trim().toLowerCase() == key,
      );
      used.remove(key);
    } else if (used.contains(key)) {
      return;
    }
    used.add(key);
    raw.add(player);
  }

  for (final row in apiRows) {
    add(
      _BoardPlayer(
        name: row.displayName,
        score: row.score,
        isMe: row.isCurrentUser,
      ),
    );
  }
  if (!raw.any((row) => row.isMe)) {
    add(
      _BoardPlayer(
        name: playerName,
        score: playerScore,
        isMe: true,
      ),
    );
  }

  for (final name in _kSeedNames) {
    if (raw.length >= 50) break;
    add(
      _BoardPlayer(
        name: name,
        score: _seedScore(league, span, name),
        isMe: false,
      ),
    );
  }

  raw.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
    return a.name.compareTo(b.name);
  });

  final ranked = <_RankedPlayer>[];
  for (var i = 0; i < raw.length; i++) {
    final rank = i > 0 && raw[i].score == raw[i - 1].score
        ? ranked[i - 1].rank
        : i + 1;
    ranked.add(_RankedPlayer(rank: rank, player: raw[i]));
  }
  return ranked;
}

int _seedScore(LeagueTier league, _MarathonSpan span, String name) {
  final rnd = math.Random(Object.hash(league.name, span.name, name));
  final (floor, spread) = switch (span) {
    _MarathonSpan.week => (1, 36),
    _MarathonSpan.month => (4, 72),
    _MarathonSpan.year => (10, 140),
    _MarathonSpan.all => (16, 220),
  };
  return floor + rnd.nextInt(spread);
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}
