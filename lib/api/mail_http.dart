import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/core/mail/mail_template.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _random = Random.secure();

Future<void> migrateMail(Connection db) async {
  await db.execute('''
    create table if not exists mail_templates (
      id text primary key,
      subject text not null,
      html_body text not null,
      text_body text not null
    )
  ''');
  await db.execute('''
    create table if not exists password_resets (
      email text primary key,
      code_hash text not null,
      expires_at timestamptz not null
    )
  ''');
  await db.execute(
    Sql.named('''
      insert into mail_templates (id, subject, html_body, text_body)
      values ('bilgi_reset', @subject, @html, @text)
      on conflict (id) do nothing
    '''),
    parameters: {
      'subject': MailTemplate.reset.subject,
      'html': MailTemplate.reset.htmlBody,
      'text': MailTemplate.reset.textBody,
    },
  );
}

void mountMailApi(Router router, Connection db) {
  router
    ..post('/v1/bilgi/password-reset', (request) => _sendReset(request, db))
    ..post('/v1/bilgi/password-reset/confirm', (request) => _confirmReset(request, db))
    ..get('/v1/admin/mail-template', (request) => _readTemplate(request, db))
    ..put('/v1/admin/mail-template', (request) => _writeTemplate(request, db))
    ..post('/v1/admin/mail-test', (request) => _sendTest(request, db));
}

Future<Response> _sendReset(Request request, Connection db) async {
  final body = await readJson(request);
  final email = _email(body['email']);
  if (email == null) return jsonResponse({'error': 'Geçerli bir e-posta yaz.'}, status: 400);
  final code = _code();
  final sent = await _deliver(db, email: email, code: code);
  if (sent != null) return jsonResponse({'error': 'E-posta gönderilemedi.'}, status: 502);
  await db.execute(
    Sql.named('''
      insert into password_resets (email, code_hash, expires_at)
      values (@email, @hash, now() + interval '30 minutes')
      on conflict (email) do update
      set code_hash = excluded.code_hash, expires_at = excluded.expires_at
    '''),
    parameters: {'email': email, 'hash': _hash(email, code)},
  );
  return jsonResponse({'ok': true, 'message': 'Sıfırlama kodu e-postana gönderildi.'});
}

Future<Response> _confirmReset(Request request, Connection db) async {
  final body = await readJson(request);
  final email = _email(body['email']);
  final code = '${body['code'] ?? ''}'.trim();
  if (email == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
    return jsonResponse({'error': 'Kod geçersiz.'}, status: 400);
  }
  final rows = await db.execute(
    Sql.named('''
      select code_hash from password_resets
      where email = @email and expires_at > now()
    '''),
    parameters: {'email': email},
  );
  if (rows.isEmpty || rows.first[0] != _hash(email, code)) {
    return jsonResponse({'error': 'Kod geçersiz veya süresi dolmuş.'}, status: 400);
  }
  await db.execute(
    Sql.named('delete from password_resets where email = @email'),
    parameters: {'email': email},
  );
  return jsonResponse({'ok': true});
}

Future<Response> _readTemplate(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final template = await _template(db);
  return jsonResponse(template.toJson());
}

Future<Response> _writeTemplate(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final template = MailTemplate.fromJson(body);
  if (template.subject.trim().isEmpty ||
      (!template.htmlBody.contains('{{code}}') && !template.textBody.contains('{{code}}'))) {
    return jsonResponse({'error': 'Konu boş olamaz. Şablon {{code}} içermeli.'}, status: 400);
  }
  await db.execute(
    Sql.named('''
      insert into mail_templates (id, subject, html_body, text_body)
      values ('bilgi_reset', @subject, @html, @text)
      on conflict (id) do update
      set subject = excluded.subject, html_body = excluded.html_body, text_body = excluded.text_body
    '''),
    parameters: {
      'subject': template.subject.trim(),
      'html': template.htmlBody,
      'text': template.textBody,
    },
  );
  return jsonResponse({'ok': true});
}

Future<Response> _sendTest(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final email = _email(body['to']);
  if (email == null) return jsonResponse({'error': 'Geçerli bir e-posta yaz.'}, status: 400);
  final error = await _deliver(db, email: email, code: '123456');
  if (error != null) return jsonResponse({'error': error}, status: 502);
  return jsonResponse({'ok': true, 'message': 'Deneme maili gönderildi.'});
}

Future<MailTemplate> _template(Connection db) async {
  final rows = await db.execute(
    "select subject, html_body, text_body from mail_templates where id = 'bilgi_reset'",
  );
  if (rows.isEmpty) return MailTemplate.reset;
  return MailTemplate(
    subject: rows.first[0] as String,
    htmlBody: rows.first[1] as String,
    textBody: rows.first[2] as String,
  );
}

Future<String?> _deliver(Connection db, {required String email, required String code}) async {
  final key = Platform.environment['SMTP2GO_API_KEY'] ?? '';
  if (key.isEmpty) return 'SMTP2GO anahtarı yok.';
  final sender = Platform.environment['SMTP2GO_SENDER'] ?? 'Luno Bilgi <noreply@onyapp.app>';
  final filled = (await _template(db)).apply(code: code, email: email);
  final response = await http.post(
    Uri.parse('https://api.smtp2go.com/v3/email/send'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'api_key': key,
      'to': [email],
      'sender': sender,
      'subject': filled.subject,
      'html_body': filled.htmlBody,
      'text_body': filled.textBody,
    }),
  );
  try {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map && decoded['data'] is Map) {
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final succeeded = data['succeeded'];
      final failed = data['failed'];
      if (succeeded is int && succeeded > 0 && (failed == null || failed == 0)) return null;
      final error = data['error'];
      if (error != null) return 'SMTP2GO: $error';
    }
  } catch (_) {}
  return 'SMTP2GO yanıtı: ${response.statusCode}';
}

String? _email(Object? value) {
  if (value is! String) return null;
  final email = value.trim().toLowerCase();
  if (!_emailRe.hasMatch(email)) return null;
  return email;
}

String _code() => List.generate(6, (_) => _random.nextInt(10)).join();

String _hash(String email, String code) => sha256.convert(utf8.encode('$email:$code')).toString();
