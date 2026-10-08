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
/// [onPaper] her ara kayıtta çağrılır; hata kağıdı silmez, dönüşteki error durum yazar.
Future<({List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares, String? error})>
    bilgiGenerateDailyPaper({
  required String day,
  required List<String> avoidFacts,
  Future<void> Function(List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares, String message)? onPaper,
}) async {
  final key = Platform.environment['OPENAI_API_KEY'] ?? '';
  if (key.isEmpty) {
    return (questions: <Map<String, dynamic>>[], spares: <Map<String, dynamic>>[], error: 'Günlük üretim anahtarı yok.');
  }
  final model = (Platform.environment['BILGI_DAILY_MODEL'] ?? _dailyModelFallback).trim();
  final avoid = <String>{
    for (final fact in avoidFacts)
      if (bilgiDailyFold(_questionOf(fact)).isNotEmpty) bilgiDailyFold(_questionOf(fact)),
  };
  final shown = avoidFacts.take(240).map((fact) => fact.trim()).where((fact) => fact.isNotEmpty).join('\n');
  final deadline = DateTime.now().add(const Duration(minutes: 7));
  final usedModel = model.isEmpty ? _dailyModelFallback : model;
  var tail = Future<void>.value();
  Future<void> emit(List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares, String message) {
    final sink = onPaper;
    if (sink == null) return Future<void>.value();
    tail = tail.then((_) async {
      try {
        await sink(
          [for (final row in questions) Map<String, dynamic>.from(row)],
          [for (final row in spares) Map<String, dynamic>.from(row)],
          message,
        );
      } catch (_) {}
    });
    return tail;
  }

  final first = await _complete(
    key: key,
    model: usedModel,
    instruction: _instruction,
    source: 'Gün: $day\nBu olguları tekrarlama. Her satır soru ve doğru cevaptır.\n$shown',
    timeout: const Duration(seconds: 90),
  );
  var parsed = bilgiDailyPaperFromModel(first.text, day: day, avoid: avoid);
  if (parsed.questions.length < 20 && _room(deadline, const Duration(seconds: 200))) {
    final previous = first.text ?? '';
    final repair = await _complete(
      key: key,
      model: usedModel,
      instruction: _instruction,
      source: 'Gün: $day\n'
          'Önceki JSON reddedildi: ${parsed.error}\n'
          'Aynı kağıdı düzelt. Soru sayısını ve olguları koru. Yalnız düzeltilmiş JSON döndür.\n'
          '${previous.length > 48000 ? previous.substring(0, 48000) : previous}',
      timeout: const Duration(seconds: 70),
      temperature: 0.2,
    );
    if (repair.text != null) {
      final next = bilgiDailyPaperFromModel(repair.text, day: day, avoid: avoid);
      if (next.questions.length > parsed.questions.length) parsed = next;
    }
  }
  if (parsed.questions.isEmpty) {
    final reason = first.error ?? parsed.error ?? 'Üretim kurallara uymadı.';
    return (questions: <Map<String, dynamic>>[], spares: <Map<String, dynamic>>[], error: reason);
  }
  await emit(parsed.questions, parsed.spares, 'Türkçe kağıt yazıldı');
  if (parsed.questions.length < 20) {
    return (
      questions: parsed.questions,
      spares: parsed.spares,
      error: parsed.error ?? 'Kağıt 20 soru olmalı.',
    );
  }
  if (!_room(deadline, const Duration(seconds: 20))) {
    return (questions: parsed.questions, spares: parsed.spares, error: null);
  }
  final split = parsed.questions.length;
  final translated = await _translateRows(
    [...parsed.questions, ...parsed.spares],
    deadline,
    onRows: (rows, message) => emit(rows.sublist(0, split), rows.sublist(split), message),
  );
  return (
    questions: translated.rows.sublist(0, split),
    spares: translated.rows.sublist(split),
    error: null,
  );
}

bool _room(DateTime deadline, Duration need) => deadline.isAfter(DateTime.now().add(need));

Future<({List<Map<String, dynamic>> rows, String? error})> _translateRows(
  List<Map<String, dynamic>> rows,
  DateTime deadline, {
  Future<void> Function(List<Map<String, dynamic>> rows, String message)? onRows,
}) async {
  final out = [for (final row in rows) Map<String, dynamic>.from(row)];
  Future<void> publish() async {
    final sink = onRows;
    if (sink == null) return;
    final done = out.where((row) => row['translations'] != null).length;
    try {
      await sink([for (final row in out) Map<String, dynamic>.from(row)], 'Çevriliyor $done/${out.length}');
    } catch (_) {}
  }

  Future<void> run(List<int> ids) async {
    var cursor = 0;
    Future<void> worker() async {
      while (_room(deadline, const Duration(seconds: 8))) {
        final place = cursor;
        if (place >= ids.length) return;
        cursor += 1;
        final index = ids[place];
        final row = out[index];
        final options = [for (final option in row['options'] as List) '$option'];
        final translated = await bilgiTranslateTrivia(
          text: '${row['text']}',
          options: options,
          explanation: '${row['explanation']}',
          hint: '${row['hint']}',
          timeout: const Duration(seconds: 30),
        );
        if (translated.translations != null) {
          out[index]['translations'] = translated.translations;
          await publish();
        }
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
  }

  await run([for (var i = 0; i < out.length; i++) i]);
  final failed = [for (var i = 0; i < out.length; i++) if (out[i]['translations'] == null) i];
  if (failed.isNotEmpty && _room(deadline, const Duration(seconds: 35))) await run(failed);
  if (out.any((row) => row['translations'] == null)) {
    final late = !_room(deadline, const Duration(seconds: 1));
    return (
      rows: out,
      error: late ? 'Günlük üretim süreye sığmadı.' : 'Tercüme eksik geldi.',
    );
  }
  return (rows: out, error: null);
}

Future<({String? text, String? error})> _complete({
  required String key,
  required String model,
  required String instruction,
  required String source,
  Duration timeout = const Duration(seconds: 90),
  double temperature = 0.5,
  int maxTokens = 16000,
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
            'temperature': temperature,
            'max_tokens': maxTokens,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': instruction},
              {'role': 'user', 'content': source},
            ],
          }),
        )
        .timeout(timeout);
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

Amaç sıradan ezber değildir. Soru eğlenceli ve espirili olabilir. İşaretlenen cevap yine de gerçek bir olgudur. Cevabı öğrenen kişi bunu bir arkadaşına anlatabilmelidir. Başkent, en büyük okyanus, suyun formülü gibi klasik soruları yazma.

Kağıt tam 20 soru. Zorluk sırası birebir şöyle olsun:
kolay, orta, kolay, orta, orta, zor, orta, kolay, orta, zor, efsane, orta, kolay, zor, orta, kolay, orta, zor, kolay, efsane
Aynı konu art arda en fazla 2 soru gelsin.

Yedek tam 11 soru, sıraya girmez. Zorluk sırası:
kolay, kolay, kolay, orta, orta, orta, zor, zor, zor, efsane, efsane

Her soru:
{"text":"","options":["","","",""],"correct":0,"difficulty":"kolay","topic":"","hint":"","explanation":""}

Kurallar:
- correct 0, 1, 2 veya 3. Her zorlukta doğru şık A, B, C, D diye sırayla dönsün. Aynı harf bir zorlukta diğerinden en fazla 1 fazla olsun.
- correct ile işaretlenen şık, o sorunun gerçek ve tek doğru cevabıdır.
- Diğer üç şık aynı soruya ait gerçek ama yanlış alternatiflerdir. Uydurma, geyik ya da gerçek dışı cümle yazılmaz. "Deniz suyu soğuktur, bu yüzden susatır" gibi bir şık yazılmaz.
- Dört şık birbirinden farklı olsun.
- Tek net cevap. Tanıma göre değişen, tarihsiz rekor, "en çok", günü olmayan güncel sayı ve tartışmalı iddia yazma. Emin olunmayan olguyu yazma.
- hint, doğru şıkkı anlatan başka bir cümledir. Doğru şıkkın kelimeleri ipucunda geçmesin. Açıklamanın aynısı olmasın. 4 ile 500 karakter.
- explanation tek öğretici cümledir.
- topic kısa konu adıdır: tarih, bilim, uzay, doğa, insan, sanat, sinema, müzik, spor, yemek, icat, günlük yaşam gibi.
- Kağıt ve yedek birlikte aynı kişiyi, olayı veya olguyu tekrarlamaz.
- Efsane, ansiklopedik niş ayrıntı değildir. Öğrenilince yerine oturan ayırt edici bir olgudur.

JSON biçimi: {"questions":[...20...],"spares":[...11...]}
''';
