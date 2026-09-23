import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class FallProfileScreen extends StatefulWidget {
  const FallProfileScreen({super.key});

  @override
  State<FallProfileScreen> createState() => _FallProfileScreenState();
}

class _FallProfileScreenState extends State<FallProfileScreen> {
  FallProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await sl<LunoFallServer>().profile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
    }
    final en = profile.locale == 'en';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Text(profile.displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        Text(FallRules.tierLabel(profile.tier, profile.locale)),
        const SizedBox(height: 16),
        Text(en ? 'Best score ${profile.bestScore}' : 'En iyi skor ${profile.bestScore}'),
        Text(en ? 'Words ${profile.wordsCaught}' : 'Kelime ${profile.wordsCaught}'),
        Text(en ? 'XP ${profile.xp}' : 'XP ${profile.xp}'),
        Text(en
            ? 'This platform is ${profile.locale.toUpperCase()} only.'
            : 'Bu platform yalnız ${profile.locale.toUpperCase()}.'),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => context.go('/hub'),
          child: Text(en ? 'All games' : 'Tüm oyunlar'),
        ),
      ],
    );
  }
}
