import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const adminPage = '''
<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Luno League yönetici</title>
  <style>
    body { font-family: sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; }
    main { max-width: 420px; margin: 48px auto; padding: 24px; }
    h1 { font-size: 22px; margin: 0 0 8px; }
    p { color: #94a3b8; }
    label { display: block; margin: 12px 0 4px; font-size: 13px; }
    input { width: 100%; box-sizing: border-box; padding: 10px; border-radius: 8px; border: 1px solid #334155; background: #111827; color: inherit; }
    main.wide { max-width: 920px; }
    button { margin-top: 16px; padding: 10px 14px; border: 0; border-radius: 8px; background: #22c55e; color: #052e16; font-weight: 700; cursor: pointer; }
    button.ghost { margin-top: 0; background: transparent; color: #e2e8f0; border: 1px solid #334155; }
    .ok { color: #86efac; }
    .err { color: #f87171; }
    .bar { display: flex; align-items: center; gap: 12px; }
    .bar span { color: #94a3b8; flex: 1; }
    nav { display: flex; flex-wrap: wrap; gap: 8px; margin: 16px 0; }
    nav button { margin-top: 0; background: #1e293b; color: #e2e8f0; }
    nav button.on { background: #22c55e; color: #052e16; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 8px 4px; border-bottom: 1px solid #1e293b; font-size: 13px; }
    input[type="checkbox"] { width: auto; }
  </style>
</head>
<body>
<main id="shell">
  <h1 id="title">Luno League yönetici</h1>
  <p id="lead">Yükleniyor…</p>
  <form id="form" hidden>
    <label>E-posta</label>
    <input id="email" type="email" autocomplete="username" required>
    <label>Şifre</label>
    <input id="password" type="password" autocomplete="current-password" minlength="8" required>
    <div id="again" hidden>
      <label>Şifre tekrar</label>
      <input id="password2" type="password" autocomplete="new-password" minlength="8">
    </div>
    <div class="err" id="error"></div>
    <button id="submit" type="submit">Giriş</button>
  </form>
  <section id="app" hidden>
    <div class="bar">
      <strong>Luno League</strong>
      <span id="who"></span>
      <button id="logout" class="ghost" type="button">Çıkış</button>
    </div>
    <nav id="nav">
      <button type="button" data-tab="overview">Özet</button>
      <button type="button" data-tab="settings">Ayarlar</button>
      <button type="button" data-tab="shop">Mağaza</button>
      <button type="button" data-tab="words">Kelimeler</button>
      <button type="button" data-tab="daily">Daily</button>
    </nav>
    <div id="panel"></div>
    <p class="ok" id="saved"></p>
    <p class="err" id="panelError"></p>
  </section>
</main>
<script>
const tokenKey = 'lunoAdminToken';
const emailKey = 'lunoAdminEmail';
const form = document.getElementById('form');
const lead = document.getElementById('lead');
const error = document.getElementById('error');
const app = document.getElementById('app');
const shell = document.getElementById('shell');
const title = document.getElementById('title');
let needsSetup = false;
let content = null;
let tab = 'overview';
const settingsFields = [
  ['dailyWinXp', 'Daily XP'],
  ['dailyWinXpWithHint', 'İpuçlu Daily XP'],
  ['perfectBonusXp', 'Mükemmel bonus XP'],
  ['noHintBonusXp', 'İpuçsuz bonus XP'],
  ['endlessXp', 'Endless XP'],
  ['endlessCoins', 'Endless coin'],
  ['dailyWinCoins', 'Daily kazanma coin'],
  ['dailyLoseCoins', 'Daily kayıp coin'],
  ['hint1Cost', 'İpucu 1 maliyeti'],
  ['hint2Cost', 'İpucu 2 maliyeti'],
  ['adCoinReward', 'Reklam coin']
];

async function api(path, options) {
  const headers = { 'content-type': 'application/json' };
  const token = sessionStorage.getItem(tokenKey);
  if (token) headers.authorization = 'Bearer ' + token;
  const response = await fetch(path, Object.assign({ headers }, options || {}));
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || 'İstek başarısız');
  return body;
}

function showLogin() {
  app.hidden = true;
  shell.classList.remove('wide');
  title.hidden = false;
  lead.hidden = false;
  lead.textContent = needsSetup
    ? 'İlk yönetici hesabını sen oluştur. Hazır şifre yok.'
    : 'E-posta ve şifre ile gir.';
  document.getElementById('again').hidden = !needsSetup;
  document.getElementById('password').autocomplete = needsSetup ? 'new-password' : 'current-password';
  document.getElementById('submit').textContent = needsSetup ? 'Hesabı oluştur' : 'Giriş';
  form.hidden = false;
}

function logout() {
  sessionStorage.removeItem(tokenKey);
  sessionStorage.removeItem(emailKey);
  content = null;
  error.textContent = '';
  showLogin();
}

function note(parent, text) {
  const p = document.createElement('p');
  p.textContent = text;
  parent.append(p);
}

function render() {
  const panel = document.getElementById('panel');
  panel.innerHTML = '';
  document.getElementById('saved').textContent = '';
  document.getElementById('panelError').textContent = '';
  document.querySelectorAll('#nav button').forEach((button) => {
    button.classList.toggle('on', button.dataset.tab === tab);
  });
  if (tab === 'overview') renderOverview(panel);
  else if (tab === 'settings') renderSettings(panel);
  else if (tab === 'shop') renderShop(panel);
  else if (tab === 'words') renderWords(panel);
  else renderDaily(panel);
}

function renderOverview(panel) {
  const config = content.config || {};
  const lines = [
    ['Daily XP', config.dailyWinXp],
    ['Daily coin', config.dailyWinCoins],
    ['Mağaza ürünü', (content.shop || []).length],
    ['Kelime', (content.words || []).length],
    ['Daily', (content.daily || []).length]
  ];
  for (const line of lines) {
    note(panel, line[0] + ': ' + (line[1] == null ? '-' : line[1]));
  }
  note(panel, 'Kaydedilen ayar ve mağaza, telefonda sonraki açılışta güncellenir.');
}

function renderSettings(panel) {
  const config = content.config || {};
  for (const field of settingsFields) {
    const label = document.createElement('label');
    label.textContent = field[1];
    const input = document.createElement('input');
    input.id = 'cfg-' + field[0];
    input.type = 'number';
    input.value = config[field[0]] == null ? '' : String(config[field[0]]);
    panel.append(label, input);
  }
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Kaydet';
  button.onclick = saveSettings;
  panel.append(button);
}

function renderShop(panel) {
  const table = document.createElement('table');
  const head = document.createElement('tr');
  for (const name of ['Ürün', 'Coin', 'Kalkan', 'TL', 'USD', 'Aktif']) {
    const th = document.createElement('th');
    th.textContent = name;
    head.append(th);
  }
  table.append(head);
  for (const item of content.shop || []) {
    const tr = document.createElement('tr');
    tr.dataset.id = item.id;
    const idCell = document.createElement('td');
    idCell.textContent = item.id;
    tr.append(idCell);
    tr.append(shopInput('coins', item.coins));
    tr.append(shopInput('shields', item.shields));
    tr.append(shopInput('priceTry', item.priceTry, 'text'));
    tr.append(shopInput('priceUsd', item.priceUsd, 'text'));
    const active = document.createElement('td');
    const box = document.createElement('input');
    box.type = 'checkbox';
    box.className = 'shop-active';
    box.checked = item.active !== false;
    active.append(box);
    tr.append(active);
    table.append(tr);
  }
  panel.append(table);
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Kaydet';
  button.onclick = saveShop;
  panel.append(button);
}

function shopInput(name, value, type) {
  const td = document.createElement('td');
  const input = document.createElement('input');
  input.className = 'shop-' + name;
  input.type = type || 'number';
  input.value = value == null ? '' : String(value);
  td.append(input);
  return td;
}

function renderWords(panel) {
  const words = content.words || [];
  if (!words.length) {
    note(panel, 'Canlı kelime listesi boş. Telefondaki kelimeler durur.');
    return;
  }
  for (const word of words) {
    note(panel, (word.word || word.id || '') + ' · ' + (word.language || ''));
  }
}

function renderDaily(panel) {
  const daily = content.daily || [];
  if (!daily.length) {
    note(panel, 'Canlı daily listesi boş. Telefondaki günlük oyun durur.');
    return;
  }
  for (const item of daily) {
    note(panel, (item.date || '') + ' · ' + (item.language || 'tr') + ' · ' + (item.league || ''));
  }
}

async function saveSettings() {
  document.getElementById('panelError').textContent = '';
  document.getElementById('saved').textContent = '';
  const config = Object.assign({}, content.config || {});
  for (const field of settingsFields) {
    const value = Number(document.getElementById('cfg-' + field[0]).value);
    if (!Number.isFinite(value)) {
      document.getElementById('panelError').textContent = field[1] + ' sayı olmalı.';
      return;
    }
    config[field[0]] = value;
  }
  try {
    await api('/v1/admin/content/config', { method: 'PUT', body: JSON.stringify(config) });
    content.config = config;
    document.getElementById('saved').textContent = 'Ayarlar kaydedildi.';
  } catch (e) {
    document.getElementById('panelError').textContent = e.message;
  }
}

async function saveShop() {
  document.getElementById('panelError').textContent = '';
  document.getElementById('saved').textContent = '';
  const next = [];
  for (const row of document.querySelectorAll('#panel tr[data-id]')) {
    const current = (content.shop || []).find((item) => item.id === row.dataset.id) || { id: row.dataset.id };
    const coins = Number(row.querySelector('.shop-coins').value);
    const shields = Number(row.querySelector('.shop-shields').value);
    if (!Number.isFinite(coins) || !Number.isFinite(shields)) {
      document.getElementById('panelError').textContent = 'Coin ve kalkan sayı olmalı.';
      return;
    }
    next.push(Object.assign({}, current, {
      coins: coins,
      shields: shields,
      priceTry: row.querySelector('.shop-priceTry').value,
      priceUsd: row.querySelector('.shop-priceUsd').value,
      active: row.querySelector('.shop-active').checked
    }));
  }
  try {
    await api('/v1/admin/content/shop', { method: 'PUT', body: JSON.stringify(next) });
    content.shop = next;
    document.getElementById('saved').textContent = 'Mağaza kaydedildi.';
  } catch (e) {
    document.getElementById('panelError').textContent = e.message;
  }
}

async function enter() {
  await api('/v1/admin/users');
  content = await api('/v1/games/luno_league/bootstrap');
  form.hidden = true;
  title.hidden = true;
  lead.hidden = true;
  app.hidden = false;
  shell.classList.add('wide');
  document.getElementById('who').textContent = sessionStorage.getItem(emailKey) || '';
  render();
}

form.onsubmit = async (event) => {
  event.preventDefault();
  error.textContent = '';
  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;
  const password2 = document.getElementById('password2').value;
  if (needsSetup && password !== password2) {
    error.textContent = 'Şifreler aynı değil.';
    return;
  }
  try {
    const path = needsSetup ? '/v1/admin/setup' : '/v1/admin/login';
    const body = await api(path, { method: 'POST', body: JSON.stringify({ email, password }) });
    sessionStorage.setItem(tokenKey, body.token);
    sessionStorage.setItem(emailKey, body.email || email);
    document.getElementById('password').value = '';
    await enter();
  } catch (e) {
    error.textContent = e.message;
  }
};

document.getElementById('logout').onclick = logout;
document.querySelectorAll('#nav button').forEach((button) => {
  button.onclick = () => {
    tab = button.dataset.tab;
    render();
  };
});

(async () => {
  const status = await api('/v1/admin/status');
  needsSetup = status.needsSetup === true;
  const token = sessionStorage.getItem(tokenKey);
  if (token && !needsSetup) {
    try {
      await enter();
      return;
    } catch (_) {
      sessionStorage.removeItem(tokenKey);
    }
  }
  showLogin();
})();
</script>
</body>
</html>
''';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _random = Random.secure();

void mountAdmin(Router router, Connection db) {
  router
    ..get('/admin', (_) => Response.ok(
          adminPage,
          headers: {
            'content-type': 'text/html; charset=utf-8',
            'cache-control': 'no-store',
          },
        ))
    ..get('/v1/admin/status', (_) async {
      final count = await _count(db);
      return _json({'needsSetup': count == 0});
    })
    ..post('/v1/admin/setup', (request) async {
      if (await _count(db) != 0) {
        return _error(409, 'Yönetici hesabı zaten var.');
      }
      final body = await _body(request);
      final email = _email(body['email']);
      final password = _password(body['password']);
      if (email == null || password == null) {
        return _error(400, 'Geçerli e-posta ve en az 8 karakterlik şifre gerekli.');
      }
      final account = await _insert(db, email, password);
      final token = await _session(db, account.id);
      return _json({'token': token, 'id': account.id, 'email': account.email});
    })
    ..post('/v1/admin/login', (request) async {
      final body = await _body(request);
      final email = _email(body['email']);
      final password = body['password'];
      if (email == null || password is! String) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      final rows = await db.execute(
        Sql.named(
          'select id, password_hash, salt, status from admin_users where email = @email',
        ),
        parameters: {'email': email},
      );
      if (rows.isEmpty) return _error(401, 'E-posta veya şifre hatalı.');
      final id = rows.first[0] as String;
      final expected = rows.first[1] as String;
      final salt = rows.first[2] as String;
      final status = rows.first.toList().length > 3
          ? rows.first[3] as String? ?? 'active'
          : 'active';
      if (status != 'active' || _hash(password, salt) != expected) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      try {
        await db.execute(
          Sql.named('update admin_users set last_login_at = now() where id = @id'),
          parameters: {'id': id},
        );
      } catch (_) {}
      final token = await _session(db, id);
      return _json({'token': token, 'id': id, 'email': email});
    })
    ..get('/v1/admin/users', (request) async {
      if (await _adminId(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final rows = await db.execute(
        'select id, email from admin_users order by created_at',
      );
      return _json({
        'users': [
          for (final row in rows) {'id': row[0], 'email': row[1]},
        ],
      });
    })
    ..post('/v1/admin/users', (request) async {
      if (await _adminId(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final body = await _body(request);
      final email = _email(body['email']);
      final password = _password(body['password']);
      if (email == null || password == null) {
        return _error(400, 'Geçerli e-posta ve en az 8 karakterlik şifre gerekli.');
      }
      try {
        final account = await _insert(db, email, password);
        return _json({'id': account.id, 'email': account.email});
      } on ServerException catch (e) {
        if (e.code == '23505') return _error(409, 'Bu e-posta zaten kayıtlı.');
        rethrow;
      }
    })
    ..patch('/v1/admin/users/<id>', (Request request, String id) async {
      if (await _adminId(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final body = await _body(request);
      final email = body['email'] == null ? null : _email(body['email']);
      if (body['email'] != null && email == null) {
        return _error(400, 'Geçerli bir e-posta gir.');
      }
      final password = body['password'];
      if (password != null && password is! String) {
        return _error(400, 'Şifre geçersiz.');
      }
      if (password is String && password.isNotEmpty && password.length < 8) {
        return _error(400, 'Şifre en az 8 karakter olmalı.');
      }
      final existing = await db.execute(
        Sql.named('select id from admin_users where id = @id'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) return _error(404, 'Yönetici bulunamadı.');
      if (email != null) {
        try {
          await db.execute(
            Sql.named('update admin_users set email = @email where id = @id'),
            parameters: {'email': email, 'id': id},
          );
        } on ServerException catch (e) {
          if (e.code == '23505') return _error(409, 'Bu e-posta zaten kayıtlı.');
          rethrow;
        }
      }
      if (password is String && password.isNotEmpty) {
        final salt = _id();
        await db.execute(
          Sql.named(
            'update admin_users set password_hash = @hash, salt = @salt where id = @id',
          ),
          parameters: {
            'hash': _hash(password, salt),
            'salt': salt,
            'id': id,
          },
        );
      }
      final rows = await db.execute(
        Sql.named('select id, email from admin_users where id = @id'),
        parameters: {'id': id},
      );
      return _json({'id': rows.first[0], 'email': rows.first[1]});
    })
    ..put('/v1/admin/content/<doc>', (Request request, String doc) async {
      if (await _adminId(db, request) == null) {
        return _error(401, 'Oturum geçersiz.');
      }
      return _saveContent(db, request, doc);
    });
}

Future<void> migrateAdmin(Connection db) async {
  await db.execute('''
    create table if not exists admin_users (
      id text primary key,
      email text not null unique,
      password_hash text not null,
      salt text not null,
      created_at timestamptz not null default now()
    )
  ''');
  await db.execute(
    "alter table admin_users add column if not exists display_name text not null default ''",
  );
  await db.execute(
    "alter table admin_users add column if not exists role text not null default 'super_admin'",
  );
  await db.execute(
    "alter table admin_users add column if not exists game_ids text not null default '[]'",
  );
  await db.execute(
    "alter table admin_users add column if not exists status text not null default 'active'",
  );
  await db.execute(
    'alter table admin_users add column if not exists last_login_at timestamptz',
  );
  await db.execute('''
    create table if not exists admin_sessions (
      token_hash text primary key,
      admin_id text not null references admin_users(id) on delete cascade,
      expires_at timestamptz not null
    )
  ''');
}

Response _json(Object body) => Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _error(int status, String message) => Response(
      status,
      body: jsonEncode({'error': message}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<Map<String, dynamic>> _body(Request request) async {
  final raw = await request.readAsString();
  if (raw.isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {};
}

String? _email(Object? value) {
  if (value is! String) return null;
  final email = value.trim().toLowerCase();
  if (!_emailRe.hasMatch(email)) return null;
  return email;
}

String? _password(Object? value) {
  if (value is! String || value.length < 8) return null;
  return value;
}

String _id() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _hash(String password, String salt) {
  var digest = sha256.convert(utf8.encode('$salt::$password::luno-admin'));
  for (var i = 0; i < 12000; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

const _contentDocs = {'config', 'shop', 'words', 'daily'};

Future<Response> _saveContent(Connection db, Request request, String doc) async {
  if (!_contentDocs.contains(doc)) return _error(404, 'Belge yok.');
  Object? decoded;
  try {
    final raw = await request.readAsString();
    if (raw.isEmpty) return _error(400, 'İçerik boş.');
    decoded = jsonDecode(raw);
  } on FormatException {
    return _error(400, 'İçerik okunamadı.');
  }
  if (doc == 'config') {
    if (decoded is! Map) return _error(400, 'Ayar bir nesne olmalı.');
  } else if (decoded is! List) {
    return _error(400, 'Liste bekleniyor.');
  }
  if (doc == 'shop') {
    for (final item in decoded as List) {
      if (item is! Map || item['id'] is! String || (item['id'] as String).isEmpty) {
        return _error(400, 'Her ürünün kodu olmalı.');
      }
    }
  }
  await db.execute(
    Sql.named('''
      insert into game_content (game_id, doc, body)
      values ('luno_league', @doc, @body::jsonb)
      on conflict (game_id, doc) do update
        set body = excluded.body, updated_at = now()
    '''),
    parameters: {'doc': doc, 'body': jsonEncode(decoded)},
  );
  return _json({'ok': true, 'doc': doc});
}

Future<int> _count(Connection db) async {
  final rows = await db.execute('select count(*) from admin_users');
  final value = rows.first[0];
  if (value is int) return value;
  return int.parse('$value');
}

class _Account {
  const _Account(this.id, this.email);
  final String id;
  final String email;
}

Future<_Account> _insert(Connection db, String email, String password) async {
  final id = _id();
  final salt = _id();
  await db.execute(
    Sql.named('''
      insert into admin_users (id, email, password_hash, salt)
      values (@id, @email, @hash, @salt)
    '''),
    parameters: {
      'id': id,
      'email': email,
      'hash': _hash(password, salt),
      'salt': salt,
    },
  );
  return _Account(id, email);
}

Future<String> _session(Connection db, String adminId) async {
  final token = _id() + _id();
  final hash = sha256.convert(utf8.encode(token)).toString();
  await db.execute(
    Sql.named('''
      insert into admin_sessions (token_hash, admin_id, expires_at)
      values (@hash, @adminId, now() + interval '14 days')
    '''),
    parameters: {'hash': hash, 'adminId': adminId},
  );
  return token;
}

Future<String?> _adminId(Connection db, Request request) async {
  final header = request.headers['authorization'];
  if (header == null || !header.toLowerCase().startsWith('bearer ')) return null;
  final token = header.substring(7).trim();
  if (token.isEmpty) return null;
  final hash = sha256.convert(utf8.encode(token)).toString();
  final rows = await db.execute(
    Sql.named('''
      select admin_id from admin_sessions
      where token_hash = @hash and expires_at > now()
    '''),
    parameters: {'hash': hash},
  );
  if (rows.isEmpty) return null;
  return rows.first[0] as String;
}
