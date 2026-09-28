import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_hub.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String? _locale;
  Future<AdminOverview>? _future;

  Future<AdminOverview> _load(String locale) =>
      adminServer(context).adminOverview(locale: locale);

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
          padding: const EdgeInsets.all(32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AdminHubColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AdminHubColors.teal,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AdminHubColors.teal,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hafta ${o.weekId} · ${locale.toUpperCase()} · ${league.label}',
                        style: const TextStyle(
                          color: AdminHubColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Kayıtlı',
                  value: '${o.registeredCount}',
                  color: AdminHubColors.teal,
                ),
                _MetricCard(
                  label: 'Misafir',
                  value: '${o.guestCount}',
                ),
                _MetricCard(
                  label: 'Banlı',
                  value: '${o.bannedCount}',
                  color: AdminHubColors.error,
                ),
                _MetricCard(
                  label: 'Bugün Daily',
                  value: '${o.todayDailyCompleted}',
                ),
                _MetricCard(
                  label: 'Bugün Endless',
                  value: '${o.todayEndlessCompleted}',
                ),
              ],
            ),
            const SizedBox(height: 32),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AdminHubColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x0DFFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '📚 Kelime havuzu ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '(${locale.toUpperCase()}, aktif) · lig uzunlukları',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AdminHubColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AdminHubColors.primary,
                                Color(0xFF8B5CF6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _future = _load(locale)),
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Yenile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final tier in LeagueTier.values)
                          _PoolCard(
                            tier: tier,
                            count: o.wordPoolByLength[tier.wordLength] ?? 0,
                            selected: tier == league,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (o.missingDailyLeagues.isEmpty)
                      _Banner(
                        ok: true,
                        text:
                            '${locale.toUpperCase()} · Bugünün Daily kelimeleri tüm liglerde atanmış.',
                      )
                    else
                      _Banner(
                        ok: false,
                        text:
                            '${locale.toUpperCase()} · Daily atanmamış ligler: '
                            '${o.missingDailyLeagues.map((e) => e.label).join(', ')}'
                            ' (oyuncu girerse otomatik doldurulabilir)',
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AdminHubColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AdminHubColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: color ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({
    required this.tier,
    required this.count,
    required this.selected,
  });

  final LeagueTier tier;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x0D00D9C0)
              : AdminHubColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AdminHubColors.teal : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(tier.symbol, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    tier.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AdminHubColors.teal,
                ),
              ),
              Text(
                '${tier.wordLength} harf',
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminHubColors.muted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? const Color(0x1A00D9C0) : const Color(0x33B71C1C),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: ok ? AdminHubColors.teal : AdminHubColors.error,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
