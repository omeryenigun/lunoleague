import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

/// Time left until the next Istanbul midnight, when the shared paper turns over.
Duration bilgiContestRemaining(DateTime now) {
  final wall = bilgiIstanbulWall(now);
  final next = DateTime(wall.year, wall.month, wall.day).add(const Duration(days: 1));
  final left = next.difference(wall);
  if (left.isNegative) return Duration.zero;
  return left;
}

String bilgiContestClock(Duration left) {
  final hours = left.inHours.toString().padLeft(2, '0');
  final minutes = left.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = left.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Finished runs take their rank and replace the seed in that slot.
/// The board stays at [bilgiLeagueRealLimit]. Empty slots keep that rank's seed at score 0.
List<BilgiBoardEntry> bilgiDailyBoard(List<BilgiBoardEntry> real) {
  final ranked = [for (final row in real) if (!row.seed && !row.id.startsWith('seed-')) row]
    ..sort((a, b) => b.score.compareTo(a.score));
  final seeds = bilgiSeedBoard();
  final board = <BilgiBoardEntry>[];
  for (var i = 0; i < bilgiLeagueRealLimit; i++) {
    if (i < ranked.length) {
      final row = ranked[i];
      board.add(
        BilgiBoardEntry(
          id: row.id,
          name: row.name,
          avatar: row.avatar,
          score: row.score,
          seed: false,
          city: row.city,
          rank: i + 1,
        ),
      );
      continue;
    }
    if (i >= seeds.length) break;
    final seed = seeds[i];
    board.add(
      BilgiBoardEntry(
        id: seed.id,
        name: seed.name,
        avatar: seed.avatar,
        score: 0,
        seed: true,
        rank: i + 1,
      ),
    );
  }
  return board;
}

class BilgiContestProgress {
  const BilgiContestProgress({
    required this.index,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.streak,
    required this.finished,
  });

  final int index;
  final int score;
  final int correct;
  final int wrong;
  final int streak;
  final bool finished;

  factory BilgiContestProgress.fromMap(Map<String, dynamic> map) {
    return BilgiContestProgress(
      index: bilgiInt(map['index'], 0),
      score: bilgiInt(map['score'], 0),
      correct: bilgiInt(map['correct'], 0),
      wrong: bilgiInt(map['wrong'], 0),
      streak: bilgiInt(map['streak'], 0),
      finished: map['finished'] == true,
    );
  }
}

class BilgiContestPaper {
  const BilgiContestPaper({
    required this.day,
    required this.questions,
    required this.joined,
    required this.ranking,
    this.title = '',
    this.spares = const [],
    this.me,
  });

  final String day;
  final String title;
  final List<BilgiQuestion> questions;
  final List<BilgiQuestion> spares;
  final int joined;
  final List<BilgiBoardEntry> ranking;
  final BilgiContestProgress? me;

  String get phase {
    final mine = me;
    if (mine == null) return 'new';
    if (mine.finished) return 'done';
    return 'open';
  }
}

class BilgiContestDay {
  const BilgiContestDay({
    required this.day,
    required this.title,
    required this.count,
    required this.locked,
    this.aiStatus = '',
    this.aiMessage = '',
    this.aiLastOkAt = '',
  });

  final String day;
  final String title;
  final int count;
  final bool locked;
  final String aiStatus;
  final String aiMessage;
  final String aiLastOkAt;
}

class BilgiContestMonth {
  const BilgiContestMonth({required this.month, required this.days});

  final String month;
  final List<BilgiContestDay> days;
}

class BilgiContestAdminResult {
  const BilgiContestAdminResult({this.month, this.error});

  final BilgiContestMonth? month;
  final String? error;
}

class BilgiContestDayPaper {
  const BilgiContestDayPaper({
    required this.day,
    required this.title,
    required this.locked,
    required this.questions,
    this.spares = const [],
    this.error,
  });

  final String day;
  final String title;
  final bool locked;
  final List<BilgiQuestion> questions;
  final List<BilgiQuestion> spares;
  final String? error;
}

class BilgiContestApi {
  static Future<BilgiContestPaper?> load(String userId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/contest').replace(
        queryParameters: {if (userId.trim().isNotEmpty) 'userId': userId.trim()},
      );
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _paper(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<BilgiContestPaper?> save({
    required String userId,
    required String username,
    required String avatar,
    required int index,
    required int score,
    required int correct,
    required int wrong,
    required int streak,
    required bool finished,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/contest'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'userId': userId,
          'username': username,
          'avatar': avatar,
          'index': index,
          'score': score,
          'correct': correct,
          'wrong': wrong,
          'streak': streak,
          'finished': finished,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _paper(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<BilgiContestAdminResult> adminLoad(String token, String month) {
    return _admin(
      http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-contest').replace(queryParameters: {'month': month}),
        headers: {'authorization': 'Bearer $token'},
      ),
    );
  }

  static Future<BilgiContestAdminResult> adminSave(
    String token, {
    String month = '',
    String day = '',
    String? title,
    bool rebuild = false,
  }) {
    return _admin(
      http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-contest'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          if (month.isNotEmpty) 'month': month,
          if (day.isNotEmpty) 'day': day,
          'title': ?title,
          if (rebuild) 'rebuild': true,
        }),
      ),
    );
  }

  static Future<BilgiContestDayPaper> adminPaper(String token, String day) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-contest').replace(queryParameters: {'day': day}),
        headers: {'authorization': 'Bearer $token'},
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const BilgiContestDayPaper(day: '', title: '', locked: false, questions: [], error: 'Sorular yüklenemedi.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BilgiContestDayPaper(
          day: day,
          title: '',
          locked: false,
          questions: const [],
          error: '${decoded['error'] ?? 'Sorular yüklenemedi.'}',
        );
      }
      final questions = <BilgiQuestion>[
        for (final item in (decoded['questions'] as List? ?? const []))
          if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
      ];
      final spares = <BilgiQuestion>[
        for (final item in (decoded['spares'] as List? ?? const []))
          if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
      ];
      return BilgiContestDayPaper(
        day: '${decoded['day'] ?? day}',
        title: '${decoded['title'] ?? ''}'.trim(),
        locked: decoded['locked'] == true,
        questions: questions,
        spares: spares,
      );
    } catch (_) {
      return BilgiContestDayPaper(day: day, title: '', locked: false, questions: const [], error: 'Sorular yüklenemedi.');
    }
  }

  static Future<BilgiContestAdminResult> adminClearDay(String token, String day) {
    return _admin(
      http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-contest'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'day': day, 'clear': true}),
      ),
    );
  }

  static Future<BilgiContestAdminResult> adminSaveQuestions(
    String token,
    String day,
    List<BilgiQuestion> questions, {
    List<BilgiQuestion> spares = const [],
  }) {
    return _admin(
      http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-contest'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'day': day,
          'questions': [for (final question in questions) question.toMap()],
          'spares': [for (final question in spares) question.toMap()],
        }),
      ),
    );
  }

  static Future<BilgiContestAdminResult> _admin(Future<http.Response> call) async {
    try {
      final response = await call;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const BilgiContestAdminResult(error: 'Günlük oyun yüklenemedi.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return BilgiContestAdminResult(error: '${decoded['error'] ?? 'Günlük oyun yüklenemedi.'}');
      }
      final days = <BilgiContestDay>[
        for (final item in (decoded['days'] as List? ?? const []))
          if (item is Map)
            BilgiContestDay(
              day: '${item['day'] ?? ''}',
              title: '${item['title'] ?? ''}'.trim(),
              count: bilgiInt(item['count'], 0),
              locked: item['locked'] == true,
              aiStatus: '${item['aiStatus'] ?? ''}',
              aiMessage: '${item['aiMessage'] ?? ''}',
              aiLastOkAt: '${item['aiLastOkAt'] ?? ''}',
            ),
      ];
      return BilgiContestAdminResult(
        month: BilgiContestMonth(month: '${decoded['month'] ?? ''}', days: days),
      );
    } catch (_) {
      return const BilgiContestAdminResult(error: 'Günlük oyun yüklenemedi.');
    }
  }

  static BilgiContestPaper _paper(Map<String, dynamic> map) {
    final questions = <BilgiQuestion>[
      for (final item in (map['questions'] as List? ?? const []))
        if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
    ];
    final spares = <BilgiQuestion>[
      for (final item in (map['spares'] as List? ?? const []))
        if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
    ];
    final ranking = <BilgiBoardEntry>[
      for (final item in (map['ranking'] as List? ?? const []))
        if (item is Map)
          BilgiBoardEntry(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? ''}',
            avatar: '${item['avatar'] ?? '😎'}',
            score: bilgiInt(item['score'], 0),
            seed: item['seed'] == true,
            city: '${item['city'] ?? ''}',
            rank: bilgiInt(item['rank'], 0),
          ),
    ];
    final meRaw = map['me'];
    final rawTitle = '${map['title'] ?? ''}'.trim();
    return BilgiContestPaper(
      day: '${map['day'] ?? ''}',
      title: rawTitle.length > 40 ? rawTitle.substring(0, 40) : rawTitle,
      questions: questions,
      spares: spares,
      joined: bilgiInt(map['joined'], 0),
      ranking: ranking,
      me: meRaw is Map ? BilgiContestProgress.fromMap(Map<String, dynamic>.from(meRaw)) : null,
    );
  }
}
