import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/game_models.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  var _period = RankPeriod.week;

  String _periodLabel(RankPeriod period) => switch (period) {
        RankPeriod.week => 'Hafta',
        RankPeriod.month => 'Ay',
        RankPeriod.season => 'Sezon',
        RankPeriod.year => 'Yıl',
      };

  String _periodId(RankPeriod period) => switch (period) {
        RankPeriod.week => DateKeys.weekId(),
        RankPeriod.month => DateKeys.monthId(),
        RankPeriod.season => DateKeys.seasonId(),
        RankPeriod.year => DateKeys.yearId(),
      };

  @override
  Widget build(BuildContext context) {
    final locale = AdminLocaleScope.of(context);
    final league = AdminLocaleScope.leagueOf(context);
    final periodId = _periodId(_period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in RankPeriod.values)
                FilterChip(
                  label: Text(_periodLabel(p)),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
              const SizedBox(width: 8),
              Text(
                '${locale.toUpperCase()} · ${league.label} · '
                '${_periodLabel(_period)} ($periodId)',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AdminBody(
            key: ValueKey('$locale-${league.name}-${_period.name}-$periodId'),
            future: adminServer(context).adminLeagueStandings(
              league,
              locale: locale,
              period: _period,
              periodId: periodId,
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
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.surface),
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('Sıra')),
                            DataColumn(label: Text('Oyuncu')),
                            DataColumn(label: Text('Puan'), numeric: true),
                          ],
                          rows: [
                            for (final e in rows)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '#${e.rank}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(e.displayName),
                                    ),
                                  ),
                                  DataCell(Text('${e.points}')),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
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
