import 'package:flutter/material.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';
import 'package:kelimelig/games/luno_grid/grid_play_screen.dart';
import 'package:kelimelig/games/luno_grid/grid_rules.dart';
import 'package:kelimelig/games/luno_grid/luno_grid_server.dart';
import 'package:kelimelig/injection.dart';

class GridAdminScreen extends StatelessWidget {
  const GridAdminScreen({super.key, required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AdminSection.overview => const _GridOverview(),
      AdminSection.users => const _GridUsers(),
      AdminSection.games => const _GridGames(),
      AdminSection.words => const _GridWords(),
      AdminSection.daily => const _GridDaily(),
      AdminSection.settings => const _GridSettings(),
      _ => const _GridScenes(),
    };
  }
}

class _GridOverview extends StatelessWidget {
  const _GridOverview();

  @override
  Widget build(BuildContext context) {
    return AdminBody(
      future: _load(),
      builder: (context, data) {
        final scenes = data.$1;
        final scores = data.$2;
        final profile = data.$3;
        final active = scenes.where((scene) => scene.active).length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Luno Kelime Izgarası kaydı. Lig puanı ve coin buraya yazılmaz.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminStatCard(label: 'Sahne', value: '${scenes.length}'),
                AdminStatCard(label: 'Aktif', value: '$active', accent: AppColors.accent),
                AdminStatCard(label: 'Skor', value: '${scores.length}'),
                AdminStatCard(label: 'Bitirilen', value: '${profile.gamesFinished}'),
                AdminStatCard(label: 'En iyi', value: '${profile.bestScore}'),
                AdminStatCard(label: 'Haftalık', value: '${profile.weeklyPoints}'),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<(List<GridPuzzle>, List<GridScore>, GridProfile)> _load() async {
    final server = sl<LunoGridServer>();
    return (await server.scenes(), await server.ranking(), await server.profile());
  }
}

class _GridUsers extends StatelessWidget {
  const _GridUsers();

  @override
  Widget build(BuildContext context) {
    return AdminBody(
      future: _load(),
      builder: (context, data) {
        final profile = data.$1;
        final scores = data.$2;
        final names = <String, int>{};
        for (final score in scores) {
          names[score.name] = (names[score.name] ?? 0) + 1;
        }
        if (profile.displayName.isNotEmpty) {
          names.putIfAbsent(profile.displayName, () => profile.gamesFinished);
        }
        if (names.isEmpty) {
          return const Center(child: Text('Grid oyuncusu yok', style: TextStyle(color: AppColors.textSecondary)));
        }
        final rows = names.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return ListView(
          children: [
            for (final row in rows)
              ListTile(
                title: Text(row.key),
                subtitle: Text(row.key == profile.displayName ? 'Grid profili' : 'Skor kaydı'),
                trailing: Text('${row.value} oyun'),
              ),
          ],
        );
      },
    );
  }

  Future<(GridProfile, List<GridScore>)> _load() async {
    final server = sl<LunoGridServer>();
    return (await server.profile(), await server.ranking());
  }
}

class _GridGames extends StatelessWidget {
  const _GridGames();

  @override
  Widget build(BuildContext context) {
    return AdminBody(
      future: sl<LunoGridServer>().ranking(),
      builder: (context, scores) {
        if (scores.isEmpty) {
          return const Center(child: Text('Bitmiş Grid oyunu yok', style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView(
          children: [
            for (final score in scores)
              ListTile(
                title: Text(score.name),
                subtitle: Text(score.sceneId),
                trailing: Text('${score.score}'),
              ),
          ],
        );
      },
    );
  }
}

class _GridWords extends StatefulWidget {
  const _GridWords();

  @override
  State<_GridWords> createState() => _GridWordsState();
}

class _GridWordsState extends State<_GridWords> {
  var _query = '';
  late final Future<List<String>> _words = sl<LunoGridServer>().dictionary();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Kelime ara'),
            onChanged: (value) => setState(() => _query = TurkishText.toUpper(value)),
          ),
        ),
        Expanded(
          child: AdminBody(
            future: _words,
            builder: (context, words) {
              final prepared = words.map(TurkishText.toUpper).where((word) {
                final length = TurkishText.letterCount(word);
                return length >= 3 && length <= 7 && (_query.isEmpty || word.contains(_query));
              }).toList()
                ..sort();
              final counts = <int, int>{};
              for (final word in words.map(TurkishText.toUpper)) {
                final length = TurkishText.letterCount(word);
                if (length < 3 || length > 7) continue;
                counts[length] = (counts[length] ?? 0) + 1;
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const Text(
                    'Havuz Luno League Türkçe kelimelerinden okunur. Buradan düzenlenmez.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final length in [3, 4, 5, 6, 7])
                        Chip(label: Text('$length harf · ${counts[length] ?? 0}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final word in prepared.take(200)) ListTile(title: Text(word)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridDaily extends StatelessWidget {
  const _GridDaily();

  @override
  Widget build(BuildContext context) {
    return AdminBody(
      future: _load(),
      builder: (context, data) {
        final today = data.$1;
        final active = data.$2.where((scene) => scene.active).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              today == null ? 'Bugünün sahnesi henüz seçilmedi' : 'Bugünün sahnesi hazır',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              today == null
                  ? 'Oyuncu Daily açınca ilk aktif sahne günün sahnesi olur.'
                  : today.words.map((word) => word.word).join(', '),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('Aktif sahneler', style: TextStyle(fontWeight: FontWeight.w800)),
            if (active.isEmpty)
              const ListTile(title: Text('Aktif sahne yok'))
            else
              for (final scene in active)
                ListTile(
                  title: Text(GridRules.difficultyLabel(scene.difficulty)),
                  subtitle: Text(scene.words.map((word) => word.word).join(', ')),
                ),
          ],
        );
      },
    );
  }

  Future<(GridPuzzle?, List<GridPuzzle>)> _load() async {
    final server = sl<LunoGridServer>();
    return (await server.todaysDaily(), await server.scenes());
  }
}

class _GridSettings extends StatelessWidget {
  const _GridSettings();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text('Puan', style: TextStyle(fontWeight: FontWeight.w800)),
        ListTile(title: Text('3 harf'), trailing: Text('30')),
        ListTile(title: Text('4 harf'), trailing: Text('50')),
        ListTile(title: Text('5 harf'), trailing: Text('80')),
        ListTile(title: Text('6 harf'), trailing: Text('120')),
        ListTile(title: Text('7 harf'), trailing: Text('180')),
        ListTile(title: Text('Izgara kelimesi'), trailing: Text('+20')),
        ListTile(title: Text('Bonus kelime'), trailing: Text('+40')),
        ListTile(title: Text('Bitiş'), trailing: Text('+300')),
        SizedBox(height: 12),
        Text('İpucu skordan düşer', style: TextStyle(fontWeight: FontWeight.w800)),
        ListTile(title: Text('İlk boş harf'), trailing: Text('−50')),
        ListTile(title: Text('Kelimeyi aç'), trailing: Text('−100')),
        ListTile(title: Text('Yerini göster'), trailing: Text('−75')),
        SizedBox(height: 12),
        Text(
          'Reklam coin vermez. Reklamsız paket yalnız Grid içindir ve doğrulanmış mağaza kaydı ister.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SceneLetters extends StatelessWidget {
  const _SceneLetters({required this.puzzle});

  final GridPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final cells = puzzle.cells;
    if (cells.isEmpty) return const SizedBox.shrink();
    var maxX = 0;
    var maxY = 0;
    for (final cell in cells) {
      if (cell.x > maxX) maxX = cell.x;
      if (cell.y > maxY) maxY = cell.y;
    }
    final byKey = {for (final cell in cells) cell.key: cell};
    const size = 32.0;
    return SizedBox(
      width: (maxX + 1) * size,
      height: (maxY + 1) * size,
      child: Stack(
        children: [
          for (var y = 0; y <= maxY; y++)
            for (var x = 0; x <= maxX; x++)
              if (byKey['$x,$y'] != null)
                Positioned(
                  left: x * size,
                  top: y * size,
                  width: size - 3,
                  height: size - 3,
                  child: _SceneTile(cell: byKey['$x,$y']!),
                ),
        ],
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({required this.cell});

  final GridCell cell;

  @override
  Widget build(BuildContext context) {
    final given = cell.given;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: given ? const Color(0xFF9B4DFF) : const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          cell.letter,
          style: TextStyle(
            color: given ? Colors.white : const Color(0xFF8E8EA8),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _GridScenes extends StatefulWidget {
  const _GridScenes();

  @override
  State<_GridScenes> createState() => _GridScenesState();
}

class _GridScenesState extends State<_GridScenes> {
  var _difficulty = 'normal';
  var _sceneType = GridSceneTypes.cross5.id;
  var _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    final puzzle = await sl<LunoGridServer>().generate(difficulty: _difficulty, sceneType: _sceneType);
    if (!mounted) return;
    setState(() => _busy = false);
    if (puzzle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu zorluk için sözlükte yeterli kelime yok.')),
      );
    }
  }

  Future<void> _preview(String id) async {
    final puzzle = await sl<LunoGridServer>().scene(id);
    if (puzzle == null || !mounted) return;
    final dictionary = (await sl<LunoGridServer>().dictionary()).map(TurkishText.toUpper).toSet();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GridPlayScreen(puzzle: puzzle, dictionary: dictionary, preview: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<LunoGridServer>().scenes(),
      builder: (context, snap) {
        final scenes = snap.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Sahneler pasif doğar. Aktif olan oyuncuya açılır.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _sceneType,
              items: [
                for (final type in GridSceneTypes.all)
                  DropdownMenuItem(value: type.id, child: Text(type.label)),
              ],
              onChanged: _busy ? null : (value) => setState(() => _sceneType = value ?? GridSceneTypes.cross5.id),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _difficulty,
              items: [
                for (final id in GridRules.difficulties)
                  DropdownMenuItem(value: id, child: Text(GridRules.difficultyLabel(id))),
              ],
              onChanged: _busy ? null : (value) => setState(() => _difficulty = value ?? 'normal'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _generate,
              child: const Text('Sahne üret'),
            ),
            const SizedBox(height: 16),
            for (final scene in scenes)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${GridSceneTypes.byId(scene.type).label} · ${GridRules.difficultyLabel(scene.difficulty)} · ${scene.active ? 'Aktif' : 'Pasif'}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Önizle',
                            onPressed: () => _preview(scene.id),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                          Switch(
                            value: scene.active,
                            onChanged: (value) async {
                              await sl<LunoGridServer>().setActive(scene.id, value);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SceneLetters(puzzle: scene),
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
