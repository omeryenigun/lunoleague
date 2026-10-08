import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kelimelig/api/bilgi_translate_http.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';

const _dailyModelFallback = 'gpt-4.1';

String _questionOf(String fact) {
  final cut = fact.indexOf(' => ');
  return cut < 0 ? fact : fact.substring(0, cut);
}

/// Güçlü model Türkçe kağıdı yazar, mevcut çeviri hattı dokuz dili doldurur.
Future<({List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares, String? error})>
    bilgiGenerateDailyPaper({
  required String day,
  required List<String> avoidFacts,
}) async {
  final key = Platform.environment['OPENAI_API_KEY'] ?? '';
  if (key.isEmpty) {
    return (questions: const [], spares: const [], error: 'Günlük üretim anahtarı yok.');
  }
  final model = (Platform.environment['BILGI_DAILY_MODEL'] ?? _dailyModelFallback).trim();
  final avoid = <String>{
    for (final fact in avoidFacts)
      if (bilgiDailyFold(_questionOf(fact)).isNotEmpty) bilgiDailyFold(_questionOf(fact)),
  };
  final shown = avoidFacts.take(240).map((fact) => fact.trim()).where((fact) => fact.isNotEmpty).join('\n');
  var complaint = '';
  for (var attempt = 0; attempt < 2; attempt++) {
    final raw = await _complete(
      key: key,
      model: model.isEmpty ? _dailyModelFallback : model,
      instruction: _instruction,
      source: 'Gün: $day\n'
          'Bu olguları tekrarlama. Her satır soru ve doğru cevaptır.\n'
          '$shown\n'
          '$complaint',
    );
    if (raw.error != null) {
      return (questions: const [], spares: const [], error: raw.error);
    }
    final parsed = bilgiDailyPaperFromModel(raw.text, day: day, avoid: avoid);
    if (parsed.error != null) {
      complaint = 'Önceki çıktı reddedildi: ${parsed.error} Aynı kurallarla yeni bir kağıt yaz.';
      continue;
    }
    final questions = await _translateRows(parsed.questions);
    if (questions.error != null) {
      return (questions: const [], spares: const [], error: questions.error);
    }
    final spares = await _translateRows(parsed.spares);
    if (spares.error != null) {
      return (questions: const [], spares: const [], error: spares.error);
    }
    return (questions: questions.rows, spares: spares.rows, error: null);
  }
  return (questions: const [], spares: const [], error: 'Üretim kurallara uymadı.');
}

Future<({List<Map<String, dynamic>> rows, String? error})> _translateRows(
  List<Map<String, dynamic>> rows,
) async {
  final out = [for (final row in rows) Map<String, dynamic>.from(row)];
  var cursor = 0;
  final failures = <String>[];
  Future<void> worker() async {
    while (failures.isEmpty) {
      final index = cursor;
      if (index >= out.length) return;
      cursor += 1;
      final row = out[index];
      final options = [for (final option in row['options'] as List) '$option'];
      var translated = await bilgiTranslateTrivia(
        text: '${row['text']}',
        options: options,
        explanation: '${row['explanation']}',
        hint: '${row['hint']}',
      );
      if (translated.error != null) {
        translated = await bilgiTranslateTrivia(
          text: '${row['text']}',
          options: options,
          explanation: '${row['explanation']}',
          hint: '${row['hint']}',
        );
      }
      if (translated.translations == null) {
        failures.add(translated.error ?? 'Tercüme eksik geldi.');
        return;
      }
      out[index]['translations'] = translated.translations;
    }
  }

  await Future.wait([worker(), worker(), worker()]);
  if (failures.isNotEmpty) return (rows: const [], error: failures.first);
  return (rows: out, error: null);
}

Future<({String? text, String? error})> _complete({
  required String key,
  required String model,
  required String instruction,
  required String source,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'authorization': 'Bearer $key',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.5,
            'max_tokens': 16000,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': instruction},
              {'role': 'user', 'content': source},
            ],
          }),
        )
        .timeout(const Duration(seconds: 180));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map) {
      return (text: null, error: 'Günlük üretim yanıt vermedi (${response.statusCode}).');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return (text: null, error: 'Günlük üretim okunamadı.');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) return (text: null, error: 'Günlük üretim okunamadı.');
    final content = message['content'];
    final text = content is String ? content.trim() : '';
    if (text.isEmpty) return (text: null, error: 'Günlük üretim okunamadı.');
    return (text: text, error: null);
  } catch (_) {
    return (text: null, error: 'Günlük üretim yanıt vermedi.');
  }
}

const _instruction = '''
Luno Bilgi için bir günlük yarışma kağıdı yaz. Yalnız Türkçe. Çeviri yazma. Yalnız JSON döndür.

Amaç sıradan ezber değildir. Her soru ya yeni bir şey öğretir, ya şaşırtır, ya tahmin ettirir, ya da "bunu kaç kişi bilecek" dedirtir. Cevabı öğrenen kişi bunu bir arkadaşına anlatabilmelidir. Başkent, en büyük okyanus, suyun formülü gibi klasik soruları yazma.

Kağıt 20 soru, oynanış sırasıyla:
- zorluk sayıları: kolay 6, orta 8, zor 4, efsane 2
- ilk 3 soru kolay veya orta
- 20. soru efsane ve günün finali olsun
- diğer efsane 11. sorudan önce gelmesin
- aynı konu art arda en fazla 2 soru
- zorluk dalgalansın; kolayları başa, zorları sona yığma

Yedek 11 soru, sıraya girmez:
- kolay 3, orta 3, zor 3, efsane 2

Her soru:
{"text":"","options":["","","",""],"correct":0,"difficulty":"kolay","topic":"","hint":"","explanation":""}

Kurallar:
- correct 0, 1, 2 veya 3. Her zorluk grubunda doğru şık sayıları en fazla 1 farkla dengeli olsun.
- Dört şık birbirinden farklı ve inandırıcı olsun. Saçma çeldirici yazma.
- Tek net cevap. Tanıma göre değişen, tarihsiz rekor, "en çok", günü olmayan güncel sayı ve tartışmalı iddia yazma. Emin değilsen o soruyu yazma.
- hint, doğru şıkkı anlatan başka bir cümledir. Doğru şıkkın metnini kopyalama. Açıklamanın aynısı olmasın. 4 ile 500 karakter.
- explanation tek öğretici cümledir.
- topic kısa konu adıdır: tarih, bilim, uzay, doğa, insan, sanat, sinema, müzik, spor, yemek, icat, günlük yaşam gibi.
- Kağıt ve yedek birlikte aynı kişiyi, olayı veya olguyu tekrarlamaz.
- Efsane, ansiklopedik niş ayrıntı değildir. Öğrenilince yerine oturan ayırt edici bir olgudur.

JSON biçimi: {"questions":[...20...],"spares":[...11...]}
''';
