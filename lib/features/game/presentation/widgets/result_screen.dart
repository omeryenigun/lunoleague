import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:share_plus/share_plus.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.outcome,
    required this.guesses,
    required this.maxAttempts,
    required this.isDaily,
    required this.onHome,
    required this.onLearn,
    required this.onReplay,
    this.onReviveWithAd,
  });

  final GameOutcome outcome;
  final List<EvaluatedGuess> guesses;
  final int maxAttempts;
  final bool isDaily;
  final VoidCallback onHome;
  final VoidCallback onLearn;
  final VoidCallback onReplay;
  final VoidCallback? onReviveWithAd;

  @override
  Widget build(BuildContext context) {
    final canRevive = !isDaily && onReviveWithAd != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                outcome.won ? '🎉' : '😅',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 8),
              Text(
                outcome.won ? 'HARİKA!' : 'BU KEZ OLMADI',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.correct.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  outcome.word,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                outcome.won
                    ? '${outcome.guesses} / $maxAttempts tahminde buldun'
                    : 'Kelime: ${outcome.word}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+${outcome.xpEarned} XP',
                    style: const TextStyle(
                      color: AppColors.level,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '+${outcome.coinEarned} 🪙',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (isDaily) ...[
                const SizedBox(height: 10),
                Text(
                  '🔥 STREAK ${outcome.streak}',
                  style: const TextStyle(
                    color: AppColors.streak,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
              if (outcome.rankAfter != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Lig sırası #${outcome.rankAfter}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
              if (outcome.unlockedAchievements.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Başarım: ${outcome.unlockedAchievements.join(', ')}'),
              ],
              if (!isDaily && outcome.won && outcome.endlessRun > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Endless seri: ${outcome.endlessRun}',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ],
              if (canRevive && outcome.endlessRun > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${outcome.endlessRun} kelimelik serin reklamla korunabilir',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Yeni kelime öğrendin!',
                style: TextStyle(color: AppColors.level, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onLearn,
                child: const Text('Kelimeyi Öğren'),
              ),
              if (canRevive) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.surface,
                    ),
                    onPressed: onReviveWithAd,
                    child: const Text('Reklam izle, seriyi koru'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.share,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _share,
                      child: const Text('Paylaş'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: !isDaily
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.keyDefault,
                            ),
                            onPressed: onReplay,
                            child: Text(
                              outcome.won
                                  ? 'Sonraki'
                                  : (canRevive ? 'Seriyi sıfırla' : 'Tekrar dene'),
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.keyDefault,
                            ),
                            onPressed: onHome,
                            child: const Text('Ana Sayfa'),
                          ),
                  ),
                ],
              ),
              if (!isDaily)
                TextButton(onPressed: onHome, child: const Text('Ana sayfa')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    final buf = StringBuffer('${AppConstants.appName}\n');
    for (final g in guesses) {
      for (final s in g.statuses) {
        buf.write(switch (s) {
          LetterStatus.correct => '🟩',
          LetterStatus.present => '🟨',
          _ => '⬜',
        });
      }
      buf.writeln();
    }
    buf.writeln('${outcome.guesses}/$maxAttempts TAHMİN');
    if (isDaily) buf.writeln('🔥 ${outcome.streak} GÜNLÜK STREAK');
    await SharePlus.instance.share(ShareParams(text: buf.toString()));
  }
}
