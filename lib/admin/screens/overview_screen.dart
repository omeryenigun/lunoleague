import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String? _locale;
  Future<AdminOverview>? _future;

  Future<AdminOverview> _load(String locale) =>
      sl<GameServer>().adminOverview(locale: locale);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = AdminLocaleScope.of(context);
    if (_locale != locale || _future == null) {
      _locale = locale;
      _future = _load(locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AdminLocaleScope.of(context);
    final league = AdminLocaleScope.leagueOf(context);
    return AdminBody(
      future: _future!,
      builder: (context, o) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hafta ${o.weekId} · ${locale.toUpperCase()} · ${league.label}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminStatCard(
                  label: 'Kayıtlı',
                  value: '${o.registeredCount}',
                  accent: AppColors.accent,
                ),
                AdminStatCard(label: 'Misafir', value: '${o.guestCount}'),
                AdminStatCard(
                  label: 'Banlı',
                  value: '${o.bannedCount}',
                  accent: AppColors.danger,
                ),
                AdminStatCard(
                  label: 'Bugün Daily',
                  value: '${o.todayDailyCompleted}',
                ),
                AdminStatCard(
                  label: 'Bugün Endless',
                  value: '${o.todayEndlessCompleted}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Kelime havuzu (${locale.toUpperCase()}, aktif) · lig uzunlukları',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tier in LeagueTier.values)
                  Chip(
                    avatar: Text(tier.symbol),
                    label: Text(
                      '${tier.label} (${tier.wordLength}): '
                      '${o.wordPoolByLength[tier.wordLength] ?? 0}',
                    ),
                    backgroundColor: tier == league
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : null,
                    side: tier == league
                        ? const BorderSide(color: AppColors.accent)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (o.missingDailyLeagues.isEmpty)
              Text(
                '${locale.toUpperCase()} · Bugünün Daily kelimeleri tüm liglerde atanmış.',
                style: const TextStyle(color: AppColors.accent),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${locale.toUpperCase()} · Daily atanmamış ligler: ${o.missingDailyLeagues.map((e) => e.label).join(', ')}',
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _future = _load(locale)),
              child: const Text('Yenile'),
            ),
          ],
        );
      },
    );
  }
}
