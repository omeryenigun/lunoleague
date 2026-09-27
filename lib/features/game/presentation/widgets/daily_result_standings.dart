import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

const _kPanel = Color(0xFF161B22);
const _kLine = Color(0xFF21262D);
const _kMuted = Color(0xFF8B949E);
const _kText = Color(0xFFE6EDF3);
const _kGold = Color(0xFFF7B733);
const _kGreenLine = Color(0xFF2EA043);

const _kSeedFirst = [
  'Ahmet', 'Zeynep', 'Mert', 'Elif', 'Can', 'Selin', 'Burak', 'Ayşe',
  'Emre', 'Deniz', 'Kerem', 'Ece', 'Onur', 'İrem', 'Yusuf', 'Naz',
  'Barış', 'Sude', 'Kaan', 'Melis', 'Cem', 'Duru', 'Eren', 'Ada',
  'Arda', 'Defne', 'Berk', 'Lara', 'Kuzey', 'Nehir', 'Alp', 'Yağmur',
  'Mira', 'Tuna', 'Ela', 'Atlas', 'Lina', 'Rüzgar', 'Asya', 'Doruk',
  'Nil', 'Çınar', 'Azra', 'Umut', 'Okan', 'İpek', 'Bora', 'Sena',
  'Taner', 'Gökçe', 'Ozan', 'Eylül', 'Aylin', 'Serkan', 'Ceren', 'Hakan',
];

const _kSeedLast = [
  'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Aydın', 'Öztürk',
  'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Koç', 'Kurt', 'Özdemir',
  'Aksoy', 'Yıldız', 'Polat', 'Acar', 'Çetin', 'Erdem',
];

class DailyBoardPlayer {
  const DailyBoardPlayer({
    required this.name,
    required this.guesses,
    required this.won,
    required this.isMe,
  });

  final String name;
  final int guesses;
  final bool won;
  final bool isMe;
}

class DailyRankedPlayer {
  const DailyRankedPlayer({required this.rank, required this.player});

  final int rank;
  final DailyBoardPlayer player;
}

/// Each word becomes its first letter plus `**`. "Selim Yılmaz" → "S** Y**".
String maskPlayerName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '**';
  return parts.map((part) => '${part[0].toUpperCase()}**').join(' ');
}

String dailyBoardDisplayName(DailyBoardPlayer player) =>
    player.isMe ? player.name : maskPlayerName(player.name);

int? dailyGuessesFromScore(String score) {
  final trimmed = score.trim();
  if (trimmed.isEmpty || trimmed == '—') return null;
  return int.tryParse(trimmed);
}

/// Pads official daily rows with client-side seeds. Does not write to storage.
List<DailyRankedPlayer> fillDailyDisplayBoard({
  required List<ResultPlace> apiRows,
  required String playerName,
  required bool playerWon,
  required int playerGuesses,
  required String seedKey,
}) {
  final used = <String>{};
  final raw = <DailyBoardPlayer>[];

  void add(DailyBoardPlayer player) {
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
    final guesses = dailyGuessesFromScore(row.score);
    add(
      DailyBoardPlayer(
        name: row.displayName,
        guesses: guesses ?? 99,
        won: guesses != null,
        isMe: row.isCurrentUser,
      ),
    );
  }
  if (!raw.any((row) => row.isMe)) {
    add(
      DailyBoardPlayer(
        name: playerName,
        guesses: playerGuesses,
        won: playerWon,
        isMe: true,
      ),
    );
  }

  if (!raw.any((row) => !row.isMe)) {
    for (final name in _seedNames()) {
      if (raw.length >= 50) break;
      final (won, guesses) = _seedResult(seedKey, name);
      add(
        DailyBoardPlayer(
          name: name,
          guesses: guesses,
          won: won,
          isMe: false,
        ),
      );
    }
  }

  raw.sort((a, b) {
    if (a.won != b.won) return a.won ? -1 : 1;
    if (a.won) {
      final byGuess = a.guesses.compareTo(b.guesses);
      if (byGuess != 0) return byGuess;
    }
    if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
    return a.name.compareTo(b.name);
  });

  final ranked = <DailyRankedPlayer>[];
  for (var i = 0; i < raw.length; i++) {
    final same = i > 0 &&
        raw[i].won == raw[i - 1].won &&
        raw[i].guesses == raw[i - 1].guesses;
    ranked.add(
      DailyRankedPlayer(
        rank: same ? ranked[i - 1].rank : i + 1,
        player: raw[i],
      ),
    );
  }
  return ranked;
}

List<String> _seedNames() {
  final names = <String>[];
  for (var i = 0; i < 50; i++) {
    names.add(
      '${_kSeedFirst[i % _kSeedFirst.length]} '
      '${_kSeedLast[i % _kSeedLast.length]}',
    );
  }
  return names;
}

(bool, int) _seedResult(String seedKey, String name) {
  final rnd = math.Random(Object.hash(seedKey, name));
  if (rnd.nextInt(100) < 8) {
    return (false, 6);
  }
  const bag = [1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5, 6];
  return (true, bag[rnd.nextInt(bag.length)]);
}

class DailyResultStandings extends StatefulWidget {
  const DailyResultStandings({
    super.key,
    required this.wordId,
    required this.playerWon,
    required this.playerGuesses,
    this.seedKey,
  });

  final String wordId;
  final bool playerWon;
  final int playerGuesses;
  final String? seedKey;

  @override
  State<DailyResultStandings> createState() => _DailyResultStandingsState();
}

class _DailyResultStandingsState extends State<DailyResultStandings> {
  var _loading = true;
  List<DailyRankedPlayer> _board = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DailyResultStandings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId ||
        oldWidget.playerWon != widget.playerWon ||
        oldWidget.playerGuesses != widget.playerGuesses) {
      _load();
    }
  }

  Future<void> _load() async {
    final l10n = sl<L10n>();
    List<ResultPlace> rows = const [];
    try {
      if (widget.wordId.isNotEmpty) {
        rows = await sl<GameServer>().resultBoard(
          type: GameType.daily,
          wordId: widget.wordId,
        );
      }
    } catch (_) {}
    final user = await sl<GameServer>().currentUser();
    if (!mounted) return;
    setState(() {
      _board = fillDailyDisplayBoard(
        apiRows: rows,
        playerName: user?.displayName ?? l10n.t('guest'),
        playerWon: widget.playerWon,
        playerGuesses: widget.playerGuesses,
        seedKey: widget.seedKey ?? widget.wordId,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _kGold,
            ),
          ),
        ),
      );
    }
    if (_board.isEmpty) return const SizedBox.shrink();
    final top3 = _board.take(3).toList();
    final rest = _board.skip(3).toList();
    final me = _board.where((row) => row.player.isMe).firstOrNull;
    final list = [
      if (me != null && me.rank <= 3) me,
      ...rest,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
      child: Column(
        children: [
          Text(
            l10n.t('result_board'),
            style: const TextStyle(
              color: _kMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          _DailyPodium(top: top3),
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
                    _DailyRankRow(
                      entry: list[i],
                      youLabel: l10n.t('marathon_you'),
                      guessLabel: l10n.t('match_guesses'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPodium extends StatelessWidget {
  const _DailyPodium({required this.top});

  final List<DailyRankedPlayer> top;

  @override
  Widget build(BuildContext context) {
    DailyRankedPlayer? at(int rank) {
      for (final row in top) {
        if (row.rank == rank) return row;
      }
      return top.length >= rank ? top[rank - 1] : null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _DailyPodiumItem(
              entry: at(2),
              place: 2,
              height: 70,
              colors: const [Color(0xFFE0E0E0), Color(0xFF909090)],
              ring: const Color(0xFFC0C0C0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DailyPodiumItem(
              entry: at(1),
              place: 1,
              height: 90,
              colors: const [Color(0xFFFFD700), Color(0xFFB8860B)],
              ring: const Color(0xFFFFD700),
              glow: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DailyPodiumItem(
              entry: at(3),
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

class _DailyPodiumItem extends StatelessWidget {
  const _DailyPodiumItem({
    required this.entry,
    required this.place,
    required this.height,
    required this.colors,
    required this.ring,
    this.glow = false,
  });

  final DailyRankedPlayer? entry;
  final int place;
  final double height;
  final List<Color> colors;
  final Color ring;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final player = entry?.player;
    final label = player == null ? '—' : dailyBoardDisplayName(player);
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
            _initial(label),
            style: const TextStyle(
              color: _kText,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
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
          _scoreText(player),
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

class _DailyRankRow extends StatelessWidget {
  const _DailyRankRow({
    required this.entry,
    required this.youLabel,
    required this.guessLabel,
  });

  final DailyRankedPlayer entry;
  final String youLabel;
  final String guessLabel;

  @override
  Widget build(BuildContext context) {
    final me = entry.player.isMe;
    final shown = dailyBoardDisplayName(entry.player);
    final name = me ? '$shown  · $youLabel' : shown;
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
              _initial(shown),
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
                  entry.player.won
                      ? '${entry.player.guesses} $guessLabel'
                      : '—',
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _scoreText(entry.player),
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

String _scoreText(DailyBoardPlayer? player) {
  if (player == null) return '—';
  return player.won ? '${player.guesses}' : '—';
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}
