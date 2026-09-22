import 'package:flutter/material.dart';
import 'package:kelimelig/admin/screens/game_detail_screen.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameType? _type;
  bool? _won;

  Future<List<AdminGameRecord>> _load() =>
      sl<GameServer>().adminListGames(type: _type, won: _won);

  static String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _duration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}sn';
    return '${m}dk ${s.toString().padLeft(2, '0')}sn';
  }

  List<AdminGameRecord> _sampleGames() {
    final now = DateTime.now();
    final samples = <AdminGameRecord>[
      AdminGameRecord(
        sessionId: 'sample-1',
        userId: 'guest-1',
        displayName: 'Misafir',
        gameType: GameType.daily,
        wordId: 'word_demo_1',
        word: 'KALEM',
        guesses: 4,
        won: true,
        timeSpent: 187,
        hintUsed: false,
        xpEarned: 100,
        coinEarned: 25,
        leaguePoints: 10,
        createdAt: now.subtract(const Duration(hours: 1)),
        startedAt: now.subtract(const Duration(hours: 1, minutes: 3)),
        endedAt: now.subtract(const Duration(hours: 1)),
        isGuest: true,
        isSample: true,
        gameNo: 1001,
      ),
      AdminGameRecord(
        sessionId: 'sample-2',
        userId: 'user-ayse',
        displayName: 'Ayşe K.',
        gameType: GameType.endless,
        wordId: 'word_demo_2',
        word: 'DENIZ',
        guesses: 6,
        won: false,
        timeSpent: 412,
        hintUsed: true,
        xpEarned: 0,
        coinEarned: 5,
        leaguePoints: 0,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        startedAt: now.subtract(const Duration(hours: 2, minutes: 27)),
        endedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        isGuest: false,
        isSample: true,
        gameNo: 1002,
      ),
      AdminGameRecord(
        sessionId: 'sample-3',
        userId: 'guest-2',
        displayName: 'Misafir',
        gameType: GameType.daily,
        wordId: 'word_demo_3',
        word: 'BULUT',
        guesses: 2,
        won: false,
        timeSpent: 95,
        hintUsed: false,
        xpEarned: 0,
        coinEarned: 0,
        leaguePoints: 0,
        createdAt: now.subtract(const Duration(hours: 3)),
        startedAt: now.subtract(const Duration(hours: 3, minutes: 2)),
        endedAt: null,
        inProgress: true,
        isGuest: true,
        isSample: true,
        gameNo: 1003,
      ),
      AdminGameRecord(
        sessionId: 'sample-4',
        userId: 'user-mehmet',
        displayName: 'Mehmet Y.',
        gameType: GameType.daily,
        wordId: 'word_demo_4',
        word: 'ŞEHİR',
        guesses: 3,
        won: true,
        timeSpent: 156,
        hintUsed: false,
        xpEarned: 130,
        coinEarned: 25,
        leaguePoints: 12,
        createdAt: now.subtract(const Duration(hours: 5)),
        startedAt: now.subtract(const Duration(hours: 5, minutes: 3)),
        endedAt: now.subtract(const Duration(hours: 5)),
        isGuest: false,
        isSample: true,
        gameNo: 1004,
      ),
      AdminGameRecord(
        sessionId: 'sample-5',
        userId: 'guest-3',
        displayName: 'Misafir',
        gameType: GameType.endless,
        wordId: 'word_demo_5',
        word: 'YILDIZ',
        guesses: 5,
        won: true,
        timeSpent: 268,
        hintUsed: true,
        xpEarned: 5,
        coinEarned: 3,
        leaguePoints: 4,
        createdAt: now.subtract(const Duration(hours: 8)),
        startedAt: now.subtract(const Duration(hours: 8, minutes: 4)),
        endedAt: now.subtract(const Duration(hours: 8)),
        isGuest: true,
        isSample: true,
        gameNo: 1005,
      ),
      AdminGameRecord(
        sessionId: 'sample-6',
        userId: 'user-zeynep',
        displayName: 'Zeynep A.',
        gameType: GameType.daily,
        wordId: 'word_demo_6',
        word: 'BAHAR',
        guesses: 6,
        won: false,
        timeSpent: 521,
        hintUsed: true,
        xpEarned: 0,
        coinEarned: 5,
        leaguePoints: 0,
        createdAt: now.subtract(const Duration(hours: 12)),
        startedAt: now.subtract(const Duration(hours: 12, minutes: 9)),
        endedAt: now.subtract(const Duration(hours: 12)),
        isGuest: false,
        isSample: true,
        gameNo: 1006,
      ),
      AdminGameRecord(
        sessionId: 'sample-7',
        userId: 'guest-4',
        displayName: 'Misafir',
        gameType: GameType.endless,
        wordId: 'word_demo_7',
        word: 'ORMAN',
        guesses: 1,
        won: false,
        timeSpent: 42,
        hintUsed: false,
        xpEarned: 0,
        coinEarned: 0,
        leaguePoints: 0,
        createdAt: now.subtract(const Duration(hours: 14)),
        startedAt: now.subtract(const Duration(hours: 14, minutes: 1)),
        endedAt: null,
        inProgress: true,
        isGuest: true,
        isSample: true,
        gameNo: 1007,
      ),
      AdminGameRecord(
        sessionId: 'sample-8',
        userId: 'user-can',
        displayName: 'Can D.',
        gameType: GameType.daily,
        wordId: 'word_demo_8',
        word: 'NEHIR',
        guesses: 2,
        won: true,
        timeSpent: 78,
        hintUsed: false,
        xpEarned: 150,
        coinEarned: 25,
        leaguePoints: 15,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        startedAt: now.subtract(const Duration(days: 1, hours: 2, minutes: 1)),
        endedAt: now.subtract(const Duration(days: 1, hours: 2)),
        isGuest: false,
        isSample: true,
        gameNo: 1008,
      ),
      AdminGameRecord(
        sessionId: 'sample-9',
        userId: 'guest-5',
        displayName: 'Misafir',
        gameType: GameType.endless,
        wordId: 'word_demo_9',
        word: 'ÇIÇEK',
        guesses: 4,
        won: false,
        timeSpent: 310,
        hintUsed: false,
        xpEarned: 0,
        coinEarned: 0,
        leaguePoints: 0,
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
        startedAt: now.subtract(const Duration(days: 1, hours: 6, minutes: 5)),
        endedAt: now.subtract(const Duration(days: 1, hours: 6)),
        isGuest: true,
        isSample: true,
        gameNo: 1009,
      ),
      AdminGameRecord(
        sessionId: 'sample-10',
        userId: 'user-ela',
        displayName: 'Ela T.',
        gameType: GameType.daily,
        wordId: 'word_demo_10',
        word: 'GUNES',
        guesses: 5,
        won: true,
        timeSpent: 244,
        hintUsed: true,
        xpEarned: 70,
        coinEarned: 25,
        leaguePoints: 8,
        createdAt: now.subtract(const Duration(days: 2)),
        startedAt: now.subtract(const Duration(days: 2, minutes: 4)),
        endedAt: now.subtract(const Duration(days: 2)),
        isGuest: false,
        isSample: true,
        gameNo: 1010,
      ),
    ];

    return samples.where((g) {
      if (_type != null && g.gameType != _type) return false;
      if (_won != null) {
        if (g.inProgress) return false;
        if (g.won != _won) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Hepsi'),
                selected: _type == null && _won == null,
                onSelected: (_) => setState(() {
                  _type = null;
                  _won = null;
                }),
              ),
              FilterChip(
                label: const Text('Daily'),
                selected: _type == GameType.daily,
                onSelected: (_) => setState(() {
                  _type = GameType.daily;
                  _won = null;
                }),
              ),
              FilterChip(
                label: const Text('Endless'),
                selected: _type == GameType.endless,
                onSelected: (_) => setState(() {
                  _type = GameType.endless;
                  _won = null;
                }),
              ),
              FilterChip(
                label: const Text('Kazandı'),
                selected: _won == true,
                onSelected: (_) => setState(() {
                  _won = true;
                  _type = null;
                }),
              ),
              FilterChip(
                label: const Text('Kaybetti'),
                selected: _won == false,
                onSelected: (_) => setState(() {
                  _won = false;
                  _type = null;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminBody(
            key: ValueKey('$_type-$_won'),
            future: _load(),
            builder: (context, games) {
              final usingSample = games.isEmpty;
              final list = usingSample ? _sampleGames() : games;
              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    'Oyun yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (usingSample)
                    Container(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: const Text(
                        'Örnek gösterim — gerçek oyun kaydı gelince otomatik kalkar',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.surface,
                                ),
                                columnSpacing: 18,
                                columns: const [
                                  DataColumn(label: Text('No')),
                                  DataColumn(label: Text('Tip')),
                                  DataColumn(label: Text('Kelime')),
                                  DataColumn(label: Text('Oyuncu')),
                                  DataColumn(label: Text('Başlangıç')),
                                  DataColumn(label: Text('Bitiş')),
                                  DataColumn(label: Text('Süre')),
                                  DataColumn(
                                    label: Text('Tahmin'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Durum')),
                                ],
                                rows: [
                                  for (var i = 0; i < list.length; i++)
                                    () {
                                      final g = list[i];
                                      final no =
                                          g.gameNo ?? (list.length - i);
                                      final statusColor = g.inProgress
                                          ? AppColors.accent
                                          : (g.won
                                              ? AppColors.accent
                                              : AppColors.danger);
                                      final statusText = g.inProgress
                                          ? 'Devam'
                                          : (g.won ? 'Kazandı' : 'Kaybetti');
                                      return DataRow(
                                        onSelectChanged: (_) {
                                          if (g.isSample) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Örnek kayıt — detay yok. Gerçek oyunlar tıklanınca açılır.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => GameDetailScreen(
                                                sessionId: g.sessionId,
                                              ),
                                            ),
                                          );
                                        },
                                        cells: [
                                          DataCell(
                                            Text(
                                              '#$no',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(g.gameType.name.toUpperCase()),
                                          ),
                                          DataCell(
                                            Text(
                                              g.word,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(g.playerLabel)),
                                          DataCell(
                                            Text(_fmt(g.effectiveStart)),
                                          ),
                                          DataCell(Text(_fmt(g.effectiveEnd))),
                                          DataCell(
                                            Text(_duration(g.timeSpent)),
                                          ),
                                          DataCell(Text('${g.guesses}')),
                                          DataCell(
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
