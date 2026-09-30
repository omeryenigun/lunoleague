import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

class BilgiActiveSet {
  const BilgiActiveSet({required this.categories, required this.subs});

  final Set<String> categories;
  final Set<String> subs;

  static BilgiActiveSet? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    return BilgiActiveSet(
      categories: _keys(decoded['categories']),
      subs: _keys(decoded['subs']),
    );
  }

  static Set<String> _keys(Object? raw) {
    if (raw is! List) return const {};
    return {for (final item in raw) '$item'.trim()}.where((item) => item.isNotEmpty).toSet();
  }
}

class BilgiBankCounts {
  const BilgiBankCounts({required this.categories, required this.subs, required this.slices});

  final Map<String, int> categories;
  final Map<String, int> subs;
  final Map<String, int> slices;

  int pool(String categoryId, String sub, String difficulty) {
    final diff = difficulty == 'hepsi' ? '' : difficulty;
    if (diff.isEmpty) {
      if (sub.isEmpty) return categories[categoryId] ?? 0;
      return subs['$categoryId|$sub'] ?? 0;
    }
    if (sub.isEmpty) return slices['$categoryId||$diff'] ?? 0;
    return slices['$categoryId|$sub|$diff'] ?? 0;
  }

  static BilgiBankCounts? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    return BilgiBankCounts(
      categories: _ints(decoded['categories']),
      subs: _ints(decoded['subs']),
      slices: _ints(decoded['slices']),
    );
  }

  static Map<String, int> _ints(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final count = value is int ? value : (value is num ? value.toInt() : null);
      if (count == null || count <= 0) continue;
      out['${entry.key}'] = count;
    }
    return out;
  }
}

class BilgiQuestionApi {
  static Future<Map<String, String>> loadLabels() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/labels'));
      if (response.statusCode != 200) return const {};
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['labels'] is! List) return const {};
      final out = <String, String>{};
      for (final item in decoded['labels'] as List) {
        if (item is! Map) continue;
        final locale = '${item['locale'] ?? ''}'.trim();
        final scope = '${item['scope'] ?? ''}'.trim();
        final key = '${item['key'] ?? ''}'.trim();
        final label = '${item['label'] ?? ''}'.trim();
        if (locale.isEmpty || scope.isEmpty || key.isEmpty || label.isEmpty) continue;
        out['$locale|$scope|$key'] = label;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<({Map<String, BilgiTranslation> translations, String? error})> translateQuestion(
    String token, {
    required String text,
    required List<String> options,
    required String explanation,
    List<String>? locales,
  }) async {
    final wanted = locales ?? bilgiExtraLocales(null);
    if (wanted.isEmpty) return (translations: <String, BilgiTranslation>{}, error: null);
    final decoded = await _translate(token, {
      'kind': 'question',
      'text': text,
      'options': options,
      'explanation': explanation,
      'locales': wanted,
    });
    if (decoded.error != null) return (translations: <String, BilgiTranslation>{}, error: decoded.error);
    final raw = decoded.body?['translations'];
    if (raw is! Map) return (translations: <String, BilgiTranslation>{}, error: 'Tercüme okunamadı.');
    final out = <String, BilgiTranslation>{};
    for (final id in wanted) {
      final row = BilgiTranslation.fromMap(raw[id]);
      if (row == null || !bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) {
        return (translations: <String, BilgiTranslation>{}, error: 'Tercüme eksik geldi.');
      }
      out[id] = row;
    }
    return (translations: out, error: null);
  }

  static Future<({Map<String, String> names, String? error})> translateName(
    String token,
    String text, {
    List<String>? locales,
  }) async {
    final wanted = locales ?? bilgiExtraLocales(null);
    if (wanted.isEmpty) return (names: <String, String>{}, error: null);
    final decoded = await _translate(token, {'kind': 'name', 'text': text, 'locales': wanted});
    if (decoded.error != null) return (names: <String, String>{}, error: decoded.error);
    final raw = decoded.body?['names'];
    if (raw is! Map) return (names: <String, String>{}, error: 'Tercüme okunamadı.');
    final out = <String, String>{};
    for (final id in wanted) {
      final label = '${raw[id] ?? ''}'.trim();
      if (label.isEmpty) return (names: <String, String>{}, error: 'Tercüme eksik geldi.');
      out[id] = label;
    }
    return (names: out, error: null);
  }

  static Future<({Map<String, dynamic>? body, String? error})> _translate(String token, Map<String, Object> body) async {
    if (token.isEmpty) return (body: null, error: 'Yönetici oturumu gerekli.');
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-translate'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return (body: null, error: 'Tercüme okunamadı.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (body: null, error: '${decoded['error'] ?? 'Tercüme yapılamadı.'}');
      }
      return (body: Map<String, dynamic>.from(decoded), error: null);
    } catch (_) {
      return (body: null, error: 'Tercüme servisi yanıt vermedi.');
    }
  }

  static Future<String?> saveLabels(String token, List<Map<String, String>> rows) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-labels'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'labels': rows}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Adlar kaydedilemedi.';
    } catch (_) {
      return 'Adlar kaydedilemedi.';
    }
  }

  static Future<BilgiActiveSet?> loadActive() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/active'));
      if (response.statusCode != 200) return null;
      return BilgiActiveSet.fromJson(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> setActive(
    String token, {
    required String kind,
    required String key,
    required bool active,
  }) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-active'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'kind': kind, 'key': key, 'active': active}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Kategori kaydedilemedi.';
    } catch (_) {
      return 'Kategori kaydedilemedi.';
    }
  }

  static Future<BilgiBankCounts?> loadCounts() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/questions/counts'));
      if (response.statusCode != 200) return null;
      return BilgiBankCounts.fromJson(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
  }

  static Future<List<BilgiQuestion>?> draw({
    required String categoryId,
    required String subcategory,
    required String difficulty,
    required int count,
    required List<String> exclude,
    required String locale,
  }) async {
    final taken = count < 1 ? 1 : (count > 51 ? 51 : count);
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/questions/draw').replace(
      queryParameters: {
        'category': categoryId,
        'sub': subcategory,
        'difficulty': difficulty,
        'count': '$taken',
        if (exclude.isNotEmpty) 'exclude': exclude.join(','),
        if (locale.trim().isNotEmpty) 'locale': locale.trim(),
      },
    );
    return _load(uri.toString(), const {});
  }

  static Future<List<BilgiQuestion>?> daily({required String locale}) {
    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/questions/daily').replace(
      queryParameters: {if (locale.trim().isNotEmpty) 'locale': locale.trim()},
    );
    return _load(uri.toString(), const {});
  }

  static Future<List<BilgiQuestion>?> loadApproved() {
    return _load('${ApiConfig.baseUrl}/v1/bilgi/questions', const {});
  }

  static Future<List<BilgiQuestion>?> loadAll(String token) {
    if (token.isEmpty) return Future.value(null);
    return _load('${ApiConfig.baseUrl}/v1/admin/bilgi-questions', {
      'authorization': 'Bearer $token',
    });
  }

  static Future<String?> save(String token, List<BilgiQuestion> questions) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    if (questions.isEmpty) return null;
    for (var i = 0; i < questions.length; i += 400) {
      final end = i + 400 > questions.length ? questions.length : i + 400;
      final error = await _put(token, questions.sublist(i, end));
      if (error != null) return error;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> loadCatalog() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/catalog'));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['authoritative'] != true) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<({String? id, String? error})> saveCategory(
    String token, {
    String id = '',
    required String name,
    required String emoji,
    required String group,
    String addSub = '',
    String renameFrom = '',
    String renameTo = '',
    String subEmoji = '',
    List<String>? locales,
  }) async {
    if (token.isEmpty) return (id: null, error: 'Yönetici oturumu gerekli.');
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-categories'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          if (id.trim().isNotEmpty) 'id': id.trim(),
          'name': name,
          'emoji': emoji,
          'group': group,
          if (addSub.trim().isNotEmpty) 'addSub': addSub.trim(),
          if (renameFrom.trim().isNotEmpty)
            'renameSub': {'from': renameFrom.trim(), 'to': renameTo.trim(), 'emoji': subEmoji.trim()},
          'locales': ?locales,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (id: null, error: _error(response.body) ?? 'Kategori kaydedilemedi.');
      }
      final decoded = jsonDecode(response.body);
      final saved = decoded is Map ? '${decoded['id'] ?? ''}'.trim() : '';
      return (id: saved.isEmpty ? null : saved, error: null);
    } catch (_) {
      return (id: null, error: 'Kategori kaydedilemedi.');
    }
  }

  static Future<String?> setPopular(String token, {required String id, required bool popular}) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-categories/popular'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'id': id, 'popular': popular}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Kategori kaydedilemedi.';
    } catch (_) {
      return 'Kategori kaydedilemedi.';
    }
  }

  static Future<String?> deleteCategory(String token, String id) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    return _delete('${ApiConfig.baseUrl}/v1/admin/bilgi-categories/${Uri.encodeComponent(id.trim())}', token, 'Kategori silinemedi.');
  }

  static Future<String?> deleteSubcategory(String token, String categoryId, String name) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    final url =
        '${ApiConfig.baseUrl}/v1/admin/bilgi-categories/${Uri.encodeComponent(categoryId.trim())}/subs/${Uri.encodeComponent(name.trim())}';
    return _delete(url, token, 'Alt kategori silinemedi.');
  }

  static Future<String?> _delete(String url, String token, String fallback) async {
    try {
      final response = await http.delete(Uri.parse(url), headers: {'authorization': 'Bearer $token'});
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<String?> delete(String token, String id) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    final key = id.trim();
    if (key.isEmpty) return 'Soru bulunamadı.';
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-questions/${Uri.encodeComponent(key)}'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Soru silinemedi.';
    } catch (_) {
      return 'Soru silinemedi.';
    }
  }

  static Future<List<BilgiQuestion>?> _load(String url, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['questions'] is! List) return null;
      return [
        for (final item in decoded['questions'] as List)
          if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _put(String token, List<BilgiQuestion> questions) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-questions'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'questions': [for (final question in questions) question.toMap()],
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Sorular kaydedilemedi.';
    } catch (_) {
      return 'Sorular kaydedilemedi.';
    }
  }

  static String? _error(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) return '${decoded['error']}';
    } catch (_) {}
    return null;
  }
}
