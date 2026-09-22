import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AdminLocaleScope.of(context);
    final league = AdminLocaleScope.leagueOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${locale.toUpperCase()} · ${league.label} sıralaması',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: AdminBody(
            future: sl<GameServer>().adminLeagueStandings(
              league,
              locale: locale,
            ),
            builder: (context, List<LeaderboardEntry> rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'Sıralama yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final e = rows[i];
                  return ListTile(
                    leading: Text(
                      '#${e.rank}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    title: Text(e.displayName),
                    trailing: Text('${e.points} p'),
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
