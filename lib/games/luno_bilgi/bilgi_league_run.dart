import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

const bilgiResumableModes = {'lig', 'hizli', 'klasik', 'sakin', 'maraton'};

bool bilgiLeagueResumable(String modeId) => bilgiResumableModes.contains(modeId);

class BilgiLeagueOpen {
  const BilgiLeagueOpen({
    required this.modeId,
    required this.categoryId,
    required this.difficulty,
    required this.subcategory,
    required this.questions,
    required this.index,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.streak,
    required this.jokersUsed,
    required this.doubleLeft,
    required this.hidden,
    required this.hint,
    this.spare,
  });

  final String modeId;
  final String categoryId;
  final String difficulty;
  final String subcategory;
  final List<BilgiQuestion> questions;
  final int index;
  final int score;
  final int correct;
  final int wrong;
  final int streak;
  final int jokersUsed;
  final int doubleLeft;
  final List<int> hidden;
  final String hint;
  final BilgiQuestion? spare;
}

class BilgiLeagueRunLoad {
  const BilgiLeagueRunLoad({required this.ok, this.run});

  final bool ok;
  final BilgiLeagueOpen? run;
}

class BilgiLeagueRunApi {
  static Future<BilgiLeagueRunLoad> load(String userId, String categoryId, String modeId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/league-run').replace(
          queryParameters: {'userId': userId, 'categoryId': categoryId, 'modeId': modeId},
        ),
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) return const BilgiLeagueRunLoad(ok: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const BilgiLeagueRunLoad(ok: false);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const BilgiLeagueRunLoad(ok: false);
      return BilgiLeagueRunLoad(ok: true, run: _run(decoded['run']));
    } catch (_) {
      return const BilgiLeagueRunLoad(ok: false);
    }
  }

  static Future<bool> save(BilgiRound round, {required bool finished, bool fresh = false}) async {
    try {
      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/league-run'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'userId': round.userId,
          'modeId': round.modeId,
          'categoryId': round.categoryId,
          'difficulty': round.difficulty,
          'subcategory': round.subcategory,
          'questions': [for (final question in round.questions) question.toMap()],
          if (round.spare != null) 'spare': round.spare!.toMap(),
          'index': round.index,
          'score': round.score,
          'correct': round.correct,
          'wrong': round.wrong,
          'streak': round.streak,
          'jokersUsed': round.jokersUsed,
          'doubleLeft': round.doubleLeft,
          'hidden': round.hidden,
          'hint': round.hint,
          'finished': finished || round.finished,
          'fresh': fresh,
        }),
      )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      if (finished || round.finished) return true;
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['run'] is Map;
    } catch (_) {
      return false;
    }
  }

  static BilgiLeagueOpen? _run(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final questions = <BilgiQuestion>[
      for (final item in (map['questions'] as List? ?? const []))
        if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
    ];
    if (questions.isEmpty) return null;
    final index = bilgiInt(map['index'], 0);
    if (index >= questions.length) return null;
    final spareRaw = map['spare'];
    return BilgiLeagueOpen(
      modeId: '${map['modeId'] ?? ''}',
      categoryId: '${map['categoryId'] ?? ''}',
      difficulty: '${map['difficulty'] ?? ''}',
      subcategory: '${map['subcategory'] ?? ''}',
      questions: questions,
      index: index,
      score: bilgiInt(map['score'], 0),
      correct: bilgiInt(map['correct'], 0),
      wrong: bilgiInt(map['wrong'], 0),
      streak: bilgiInt(map['streak'], 0),
      jokersUsed: bilgiInt(map['jokersUsed'], 0),
      doubleLeft: bilgiInt(map['doubleLeft'], 0),
      hidden: [for (final item in (map['hidden'] as List? ?? const [])) bilgiInt(item, -1)].where((item) => item >= 0).toList(),
      hint: '${map['hint'] ?? ''}',
      spare: spareRaw is Map ? BilgiQuestion.fromMap(Map<String, dynamic>.from(spareRaw)) : null,
    );
  }
}
