import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  late Future<List<SavedWord>> _future = sl<GameServer>().wordBook();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime defteri'),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final words = snap.data!;
          if (words.isEmpty) {
            return const Center(child: Text('Henüz kaydedilmiş kelime yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: words.length,
            separatorBuilder: (context, index) =>
                const Divider(color: AppColors.border),
            itemBuilder: (context, i) {
              final w = words[i];
              return ListTile(
                title: Text(
                  w.word,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${w.definition}\n🇬🇧 ${w.englishTranslation}'),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
