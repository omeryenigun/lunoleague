import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/injection.dart';
import 'package:kelimelig/domain/game/game_server.dart';

class WordCardScreen extends StatelessWidget {
  const WordCardScreen({super.key, required this.outcome});

  final GameOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime kartı')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(outcome.won ? '✅ ${outcome.word}' : outcome.word,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            const Text('📖 Anlamı', style: TextStyle(color: AppColors.textSecondary)),
            Text(outcome.definition, style: const TextStyle(fontSize: 18, height: 1.4)),
            const SizedBox(height: 16),
            const Text('📝 Örnek', style: TextStyle(color: AppColors.textSecondary)),
            Text(outcome.exampleSentence, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 16),
            const Text('🇬🇧 İngilizce', style: TextStyle(color: AppColors.textSecondary)),
            Text(outcome.englishTranslation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await sl<GameServer>().saveWord(outcome.wordId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kelime defterine eklendi')),
                  );
                }
              },
              child: const Text('KELİME DEFTERİNE EKLE'),
            ),
          ],
        ),
      ),
    );
  }
}
