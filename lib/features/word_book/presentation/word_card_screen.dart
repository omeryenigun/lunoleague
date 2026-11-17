import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class WordCardScreen extends StatelessWidget {
  const WordCardScreen({super.key, required this.outcome});

  final GameOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GamePageHeader(title: 'Kelime kartı'),
                Text(
                  outcome.won ? '✅ ${outcome.word}' : outcome.word,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 20),
                _InfoBlock(
                  label: '📖 Anlamı',
                  body: outcome.definition,
                ),
                const SizedBox(height: 12),
                _InfoBlock(
                  label: '📝 Örnek',
                  body: outcome.exampleSentence,
                ),
                const SizedBox(height: 12),
                _InfoBlock(
                  label: '🇬🇧 İngilizce',
                  body: outcome.englishTranslation,
                  emphasize: true,
                ),
                const Spacer(),
                CosmicContinueButton(
                  label: 'Kelime defterine ekle',
                  showArrow: false,
                  onPressed: () async {
                    await sl<GameServer>().saveWord(outcome.wordId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kelime defterine eklendi'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.body,
    this.emphasize = false,
  });

  final String label;
  final String body;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.slateGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: emphasize ? 17 : 16,
              height: 1.4,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFFF1F5F9),
            ),
          ),
        ],
      ),
    );
  }
}
