import 'package:flutter/material.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/screens/user_detail_screen.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  var _kind = AdminUserKind.all;
  var _query = '';

  Future<List<UserEntity>> _load() =>
      adminServer(context).adminListUsers(query: _query, kind: _kind);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Ad, id veya sağlayıcı ara'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
            ],
          ),
        ),
        Expanded(
          child: AdminBody(
            future: _load(),
            builder: (context, users) {
              if (users.isEmpty) {
                return const Center(child: Text('Kullanıcı yok', style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  return ListTile(
                    title: Text(u.displayName),
                    subtitle: Text(
                      '${adminProviderLabel(u.authProvider.name)} • ${u.currentLeague.label} • Lv ${u.level} • ${u.xp} XP • ${u.coin} coin • streak ${u.streak} • ${u.gamesPlayed} oyun',
                    ),
                    trailing: Text(
                      u.isBanned ? 'BAN' : '',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id)),
                      );
                      setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
