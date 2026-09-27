import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GamePageHeader(title: 'Başarımlar'),
              ),
              Expanded(
                child: FutureBuilder(
                  future: sl<GameServer>().achievements(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.cosmicGreen,
                        ),
                      );
                    }
                    final list = snap.data!;
                    final done = list.where((a) => a.unlocked).length;
                    final total = list.length;
                    final progress = total == 0 ? 0.0 : done / total;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _SummaryCard(
                          done: done,
                          total: total,
                          progress: progress,
                        ),
                        const SizedBox(height: 14),
                        for (final a in list) ...[
                          _AchievementCard(achievement: a),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.done,
    required this.total,
    required this.progress,
  });

  final int done;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0x990F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cosmicGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cosmicGreen.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Text('🏅', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İLERLEME',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xCC0A0F19),
                    color: AppColors.cosmicGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Tamamlanan',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$done / $total',
                      style: const TextStyle(
                        color: AppColors.cosmicGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        shadows: [
                          Shadow(color: Color(0x802ECC71), blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final AchievementView achievement;

  _IconTheme get _theme => switch (achievement.id) {
        'first_step' => const _IconTheme(
            colors: [Color(0x402ECC71), Color(0x261ABC9C)],
            border: Color(0x662ECC71),
          ),
        'fire_started' => const _IconTheme(
            colors: [Color(0x40E74C3C), Color(0x26E67E22)],
            border: Color(0x66E74C3C),
          ),
        'professor' => const _IconTheme(
            colors: [Color(0x40FF6B9D), Color(0x26E64C8A)],
            border: Color(0x66FF6B9D),
          ),
        'lightning' => const _IconTheme(
            colors: [Color(0x40F1C40F), Color(0x26E67E22)],
            border: Color(0x66F1C40F),
          ),
        'perfectionist' => const _IconTheme(
            colors: [Color(0x40E74C3C), Color(0x26C0392B)],
            border: Color(0x66E74C3C),
          ),
        'gold_league' => const _IconTheme(
            colors: [Color(0x4DF1C40F), Color(0x33E67E22)],
            border: Color(0x80F1C40F),
          ),
        _ => const _IconTheme(
            colors: [Color(0x403498DB), Color(0x262980B9)],
            border: Color(0x663498DB),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final theme = _theme;
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: unlocked
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x0F2ECC71), Color(0x990F172A)],
                )
              : null,
          color: unlocked ? null : const Color(0x990F172A),
          border: Border.all(
            color: unlocked
                ? AppColors.cosmicGreen.withValues(alpha: 0.4)
                : const Color(0x1A94A3B8),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.colors,
                ),
                border: Border.all(color: theme.border),
                boxShadow: [
                  BoxShadow(
                    color: theme.border.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: 24,
                  color: unlocked ? null : Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlocked
                          ? AppColors.cosmicGreen
                          : const Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      shadows: unlocked
                          ? const [
                              Shadow(color: Color(0x662ECC71), blurRadius: 10),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    achievement.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: unlocked
                    ? const LinearGradient(
                        colors: [AppColors.cosmicGold, Color(0xFFE67E22)],
                      )
                    : const LinearGradient(
                        colors: [Color(0x26F1C40F), Color(0x1AE67E22)],
                      ),
                border: Border.all(
                  color: unlocked
                      ? AppColors.cosmicGold
                      : const Color(0x59F1C40F),
                ),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: AppColors.cosmicGold.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${achievement.rewardCoin}',
                    style: TextStyle(
                      color: unlocked
                          ? AppColors.cosmicBg
                          : AppColors.cosmicGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('🪙', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTheme {
  const _IconTheme({required this.colors, required this.border});

  final List<Color> colors;
  final Color border;
}
