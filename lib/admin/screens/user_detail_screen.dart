import 'package:flutter/material.dart';
import 'package:kelimelig/admin/screens/game_detail_screen.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _reason = TextEditingController();
  final _coins = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _coins.dispose();
    super.dispose();
  }

  Future<AdminUserDetail> _load() => sl<GameServer>().adminUserDetail(widget.userId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı')),
      body: AdminBody(
        future: _load(),
        builder: (context, detail) {
          final u = detail.user;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(u.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(u.id, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                '${adminProviderLabel(u.authProvider.name)} • ${u.isAnonymous ? 'Misafir' : 'Kayıtlı'} • ${u.currentLeague.label}',
              ),
              Text('Lv ${u.level} • ${u.xp} XP • ${u.coin} coin • streak ${u.streak}/${u.longestStreak}'),
              Text('Oyun ${u.gamesPlayed} / kazanç ${u.gamesWon} • endless en iyi ${u.endlessBest}'),
              if (u.isBanned)
                Text('Ban: ${u.banReason ?? 'neden yok'}', style: const TextStyle(color: AppColors.danger)),
              const Divider(height: 32),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Ban nedeni'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await sl<GameServer>().adminBanUser(
                          u.id,
                          true,
                          reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
                        );
                        setState(() {});
                      },
                      child: const Text('Banla'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await sl<GameServer>().adminBanUser(u.id, false);
                        setState(() {});
                      },
                      child: const Text('Ban kaldır'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _coins,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Coin düzeltmesi (+/-)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final d = int.tryParse(_coins.text.trim()) ?? 0;
                  if (d == 0) return;
                  await sl<GameServer>().adminAdjustCoins(u.id, d);
                  _coins.clear();
                  setState(() {});
                },
                child: const Text('Coin uygula'),
              ),
              const Divider(height: 32),
              const Text('Son oyunlar', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final g in detail.recentGames)
                ListTile(
                  title: Text('${g.gameType.name} • ${g.word} • ${g.won ? 'kazandı' : 'kaybetti'}'),
                  subtitle: Text('${g.guesses} tahmin • ${g.xpEarned} XP • ${g.coinEarned} coin'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GameDetailScreen(sessionId: g.sessionId)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
