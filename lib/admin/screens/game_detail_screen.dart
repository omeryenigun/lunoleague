import 'package:flutter/material.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyun detayı')),
      body: AdminBody(
        future: sl<GameServer>().adminGetSession(sessionId),
        builder: (context, AdminSessionDetail? detail) {
          if (detail == null) {
            return const Center(child: Text('Oturum bulunamadı'));
          }
          final s = detail.session;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(detail.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Gizli kelime: ${detail.word}', style: const TextStyle(color: AppColors.warning, fontSize: 18)),
              Text('${s.gameType.name} • ${s.status.name} • ipucu: ${s.hintUsed}'),
              Text('${s.startedAt} → ${s.expiresAt}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Tahminler', style: TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < s.guesses.length; i++)
                ListTile(
                  dense: true,
                  title: Text(s.guesses[i].guess),
                  subtitle: Text(s.guesses[i].statuses.map((e) => e.name).join(' ')),
                ),
              if (s.outcome != null) ...[
                const Divider(),
                Text('XP ${s.outcome!.xpEarned} • coin ${s.outcome!.coinEarned} • lig ${s.outcome!.leaguePoints}'),
              ],
            ],
          );
        },
      ),
    );
  }
}
