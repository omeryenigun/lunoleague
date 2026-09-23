import 'package:flutter/material.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class FallLeagueScreen extends StatefulWidget {
  const FallLeagueScreen({super.key});

  @override
  State<FallLeagueScreen> createState() => _FallLeagueScreenState();
}

class _FallLeagueScreenState extends State<FallLeagueScreen> {
  FallLeagueBoard? _board;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final board = await sl<LunoFallServer>().league();
    if (mounted) setState(() => _board = board);
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    if (board == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Text(
          '${FallRules.tierLabel(board.tier, board.locale)} · ${board.weekId}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(board.rule, style: const TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        for (var i = 0; i < board.standings.length; i++)
          ListTile(
            dense: true,
            leading: Text('${i + 1}'),
            title: Text(
              board.standings[i].name,
              style: TextStyle(
                fontWeight: board.standings[i].isPlayer ? FontWeight.w900 : FontWeight.w500,
                color: board.standings[i].isPlayer ? const Color(0xFF2ECC71) : null,
              ),
            ),
            trailing: Text('${board.standings[i].points}'),
          ),
      ],
    );
  }
}
