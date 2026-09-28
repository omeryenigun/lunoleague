import 'package:flutter/material.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';
import 'package:kelimelig/games/luno_grid/grid_play_screen.dart';
import 'package:kelimelig/games/luno_grid/grid_rules.dart';
import 'package:kelimelig/games/luno_grid/luno_grid_server.dart';
import 'package:kelimelig/injection.dart';

class GridHomeScreen extends StatelessWidget {
  const GridHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const name = 'Oyuncu';
    return Scaffold(
      backgroundColor: const Color(0xFF140F2A),
      appBar: AppBar(title: const Text('Luno Grid'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Harflerden kelime üret, ızgarayı doldur.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Pratik',
            subtitle: 'Aktif sahneden oyna',
            onTap: () => _open(context, () => sl<LunoGridServer>().openPractice(), name),
          ),
          _MenuTile(
            title: 'Daily Grid',
            subtitle: 'Günün aktif sahnesi',
            onTap: () => _open(context, () => sl<LunoGridServer>().openDaily(), name),
          ),
          _MenuTile(
            title: 'Weekly',
            subtitle: 'Bu haftanın puanı',
            onTap: () => _page(context, const _WeeklyPage()),
          ),
          _MenuTile(
            title: 'Düello',
            subtitle: 'Aynı sahnede süre yarışı',
            onTap: () => _open(context, () => sl<LunoGridServer>().openPractice(), name),
          ),
          _MenuTile(
            title: 'Özel oda',
            subtitle: 'Kodla aynı sahne',
            onTap: () => _page(context, _RoomPage(playerName: name)),
          ),
          _MenuTile(title: 'Sıralama', subtitle: 'Grid puanları', onTap: () => _page(context, const _RankPage())),
          _MenuTile(title: 'Profil', subtitle: name, onTap: () => _page(context, _ProfilePage(name: name))),
          _MenuTile(title: 'Başarımlar', subtitle: 'Bitirilen sahneler', onTap: () => _page(context, const _BadgePage())),
          _MenuTile(title: 'Koleksiyon', subtitle: 'Bitirdiğin sahneler', onTap: () => _page(context, const _CollectionPage())),
          _MenuTile(title: 'Nasıl oynanır', subtitle: 'Çember ve ızgara', onTap: () => _page(context, const _HelpPage())),
          _MenuTile(title: 'Ayarlar', subtitle: 'Ses ve titreşim bu uygulamada', onTap: () => _page(context, const _SettingsNote())),
          _MenuTile(title: 'Reklamsız', subtitle: 'Bu oyunun reklamı', onTap: () => _page(context, const _NoAdsPage())),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    Future<GridPuzzle?> Function() load,
    String name,
  ) async {
    final puzzle = await load();
    if (!context.mounted) return;
    if (puzzle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktif sahne yok. Yönetici bir sahne üretip açabilir.')),
      );
      return;
    }
    final dictionary = (await sl<LunoGridServer>().dictionary()).map(TurkishText.toUpper).toSet();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GridPlayScreen(puzzle: puzzle, dictionary: dictionary, playerName: name),
      ),
    );
  }

  void _page(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _WeeklyPage extends StatelessWidget {
  const _WeeklyPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Grid')),
      body: FutureBuilder<GridProfile>(
        future: sl<LunoGridServer>().profile(),
        builder: (context, snap) {
          final profile = snap.data;
          final days = profile?.weekScores ?? const [0, 0, 0, 0, 0, 0, 0];
          const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('${profile?.weeklyPoints ?? 0}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const Text('Haftalık toplam'),
              const SizedBox(height: 16),
              for (var i = 0; i < 7; i++) ListTile(title: Text(names[i]), trailing: Text('${days[i]}')),
            ],
          );
        },
      ),
    );
  }
}

class _RankPage extends StatelessWidget {
  const _RankPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sıralama')),
      body: FutureBuilder<List<GridScore>>(
        future: sl<LunoGridServer>().ranking(),
        builder: (context, snap) {
          final rows = snap.data ?? const <GridScore>[];
          if (rows.isEmpty) return const Center(child: Text('Henüz skor yok'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(leading: Text('${index + 1}'), title: Text(row.name), trailing: Text('${row.score}'));
            },
          );
        },
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<GridProfile>(
        future: sl<LunoGridServer>().profile(displayName: name),
        builder: (context, snap) {
          final profile = snap.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(profile?.displayName ?? name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Google veya Apple hesabın. Grid skorun ayrı durur.'),
              const SizedBox(height: 16),
              Text('Oyun ${profile?.gamesFinished ?? 0}'),
              Text('En iyi ${profile?.bestScore ?? 0}'),
              Text('Toplam ${profile?.totalScore ?? 0}'),
            ],
          );
        },
      ),
    );
  }
}

class _BadgePage extends StatelessWidget {
  const _BadgePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başarımlar')),
      body: FutureBuilder<GridProfile>(
        future: sl<LunoGridServer>().profile(),
        builder: (context, snap) {
          final done = snap.data?.gamesFinished ?? 0;
          return ListView(
            children: [
              ListTile(title: const Text('İlk grid'), subtitle: Text(done > 0 ? 'Açıldı' : 'Bir sahne bitir')),
              ListTile(title: const Text('Beş sahne'), subtitle: Text(done >= 5 ? 'Açıldı' : '$done / 5')),
            ],
          );
        },
      ),
    );
  }
}

Future<List<GridPuzzle>> _finishedScenes() async {
  final profile = await sl<LunoGridServer>().profile();
  final scenes = await sl<LunoGridServer>().scenes();
  final ids = profile.finishedIds.toSet();
  return [for (final scene in scenes) if (ids.contains(scene.id)) scene];
}

class _CollectionPage extends StatelessWidget {
  const _CollectionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koleksiyon')),
      body: FutureBuilder<List<GridPuzzle>>(
        future: _finishedScenes(),
        builder: (context, snap) {
          final done = snap.data ?? const <GridPuzzle>[];
          if (done.isEmpty) return const Center(child: Text('Henüz biten sahne yok'));
          return ListView(
            children: [
              for (final scene in done)
                ListTile(
                  title: Text(GridRules.difficultyLabel(scene.difficulty)),
                  subtitle: Text(scene.words.map((word) => word.word).join(', ')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nasıl oynanır')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Çemberdeki harfleri sürükleyerek kelime kur. Sözlükteki kelime ızgaraya uyuyorsa yerleşir. '
          'Uymayan geçerli kelime bonus puan verir. Mor kareler başlangıç harfidir. '
          'Izgara dolunca sahne biter.',
        ),
      ),
    );
  }
}

class _SettingsNote extends StatelessWidget {
  const _SettingsNote();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Ses, titreşim ve dil bu uygulamanın ayarlarındadır. Grid ayrı bir dil listesi tutmaz.'),
      ),
    );
  }
}

class _NoAdsPage extends StatelessWidget {
  const _NoAdsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reklamsız')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Bu paket yalnız Luno Grid reklamını kapatır. Satın alma, doğrulanmış mağaza kaydıyla açılır. '
          'Reklam coin vermez.',
        ),
      ),
    );
  }
}

class _RoomPage extends StatefulWidget {
  const _RoomPage({required this.playerName});

  final String playerName;

  @override
  State<_RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<_RoomPage> {
  final _code = TextEditingController();
  String? _hostCode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _play(String code) async {
    final puzzle = await sl<LunoGridServer>().joinRoom(code);
    if (!mounted) return;
    if (puzzle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oda yok')));
      return;
    }
    final dictionary = (await sl<LunoGridServer>().dictionary()).map(TurkishText.toUpper).toSet();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GridPlayScreen(
          puzzle: puzzle,
          dictionary: dictionary,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Özel oda')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () async {
                final code = await sl<LunoGridServer>().openRoom();
                setState(() => _hostCode = code);
              },
              child: const Text('Oda aç'),
            ),
            if (_hostCode != null) ...[
              const SizedBox(height: 12),
              Text('Kod $_hostCode', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => _play(_hostCode!), child: const Text('Bu odada oyna')),
            ],
            const SizedBox(height: 24),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Oda kodu')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _play(_code.text),
              child: const Text('Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}
