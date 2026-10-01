import 'package:flutter/material.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/screens/user_detail_screen.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  var _kind = AdminUserKind.all;
  var _query = '';
  var _firstGame = '';
  var _activeGame = '';
  var _period = '';
  var _plays = '';

  Future<List<UserEntity>> _load() =>
      adminServer(context).adminListUsers(query: _query, kind: _kind);

  @override
  Widget build(BuildContext context) {
    final games = <(String, String)>[
      ('', 'Tümü'),
      for (final id in GameIds.all) (id, lunoGameLabel(id)),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Ad, e-posta veya id ara'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in AdminUserKind.values)
                    FilterChip(
                      label: Text(switch (k) {
                        AdminUserKind.all => 'Hepsi',
                        AdminUserKind.registered => 'Kayıtlı',
                        AdminUserKind.guest => 'Misafir',
                        AdminUserKind.banned => 'Banlı',
                      }),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filter('İlk oyun', _firstGame, games, (value) => setState(() => _firstGame = value)),
                  _filter('Etkin oyun', _activeGame, games, (value) => setState(() => _activeGame = value)),
                  _filter('İlk kayıt', _period, const [
                    ('', 'Tümü'),
                    ('7', 'Son 7 gün'),
                    ('30', 'Son 30 gün'),
                    ('year', 'Bu yıl'),
                  ], (value) => setState(() => _period = value)),
                  _filter('Oyun sayısı', _plays, const [
                    ('', 'Tümü'),
                    ('0', 'Henüz yok'),
                    ('1', '1 ve üzeri'),
                    ('10', '10 ve üzeri'),
                    ('50', '50 ve üzeri'),
                  ], (value) => setState(() => _plays = value)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminBody(
            future: _load(),
            builder: (context, users) {
              final rows = users.where(_matches).toList()
                ..sort((a, b) => _registeredAt(b).compareTo(_registeredAt(a)));
              if (rows.isEmpty) {
                return const Center(child: Text('Kullanıcı yok', style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Text('${rows.length} kullanıcı', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
                      final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final user in rows) SizedBox(width: width, child: _card(user)),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  DateTime _registeredAt(UserEntity user) => user.accountCreatedAt ?? user.createdAt;

  bool _matches(UserEntity user) {
    if (_firstGame.isNotEmpty && user.accountFirstGame != _firstGame) return false;
    if (_activeGame.isNotEmpty && !user.accountGames.contains(_activeGame)) return false;
    final registered = _registeredAt(user);
    final now = DateTime.now();
    if (_period == '7' && registered.isBefore(now.subtract(const Duration(days: 7)))) return false;
    if (_period == '30' && registered.isBefore(now.subtract(const Duration(days: 30)))) return false;
    if (_period == 'year' && registered.year != now.year) return false;
    final minPlays = int.tryParse(_plays);
    if (minPlays != null && minPlays > 0 && user.gamesPlayed < minPlays) return false;
    if (_plays == '0' && user.gamesPlayed != 0) return false;
    return true;
  }

  String _day(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  Widget _filter(String label, String value, List<(String, String)> items, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: items.any((item) => item.$1 == value) ? value : '',
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final item in items) DropdownMenuItem(value: item.$1, child: Text(item.$2, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }

  Widget _card(UserEntity user) {
    final first = (user.accountFirstGame ?? '').isEmpty ? '—' : lunoGameLabel(user.accountFirstGame!);
    final active = user.accountGames.isEmpty ? '—' : user.accountGames.map(lunoGameLabel).join(', ');
    return Card(
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.id)),
          );
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (user.isBanned)
                    const Text('BAN', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))
                  else if (user.guestHere)
                    const Text('Misafir', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ],
              ),
              if ((user.email ?? '').isNotEmpty)
                Text(user.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _fact('İlk oyun', first),
                  _fact('Etkin oyunlar', active),
                  _fact('İlk kayıt', _day(_registeredAt(user))),
                  _fact('Oyun sayısı', '${user.gamesPlayed}'),
                  _fact('Etkin oyun', '${user.accountGames.length}'),
                  _fact('Seviye', '${user.level}'),
                  _fact('Lig', user.currentLeague.label),
                  _fact('Coin', '${user.coin}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
