import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/widgets/game_page_header.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/match/match_copy.dart';
import 'package:kelimelig/injection.dart';
import 'package:share_plus/share_plus.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  final _code = TextEditingController();
  MatchSnapshot? _snap;
  String? _me;
  String? _error;
  Timer? _timer;
  var _joining = false;
  var _opened = false;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final user = await sl<GameServer>().currentUser();
    if (!mounted) return;
    setState(() => _me = user?.id);
  }

  Future<void> _poll() async {
    if (_snap == null || _snap!.status == 'idle') return;
    try {
      final snap = await sl<GameServer>().duelPoll();
      if (!mounted) return;
      setState(() => _snap = snap);
      _openIfPlaying(snap);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = matchErrorText(sl<L10n>(), e));
    }
  }

  void _openIfPlaying(MatchSnapshot snap) {
    if (_opened || snap.status != 'playing' || snap.sessionId == null) return;
    _opened = true;
    context.push('/game/duel');
  }

  Future<void> _create() async {
    setState(() => _error = null);
    try {
      final snap = await sl<GameServer>().duelCreate();
      if (!mounted) return;
      setState(() => _snap = snap);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = matchErrorText(sl<L10n>(), e));
    }
  }

  Future<void> _join() async {
    setState(() => _error = null);
    try {
      final snap = await sl<GameServer>().duelJoin(_code.text);
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _joining = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = matchErrorText(sl<L10n>(), e));
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final snap = await sl<GameServer>().duelStart();
      if (!mounted) return;
      setState(() => _snap = snap);
      _openIfPlaying(snap);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = matchErrorText(sl<L10n>(), e));
    }
  }

  Future<void> _leave() async {
    final snap = await sl<GameServer>().duelCancel();
    if (!mounted) return;
    setState(() => _snap = snap.status == 'idle' ? null : snap);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final snap = _snap;
    final inLobby = snap != null && snap.status == 'lobby';
    final host = inLobby && snap.hostId == _me;
    final friendHere = inLobby && snap.rows.length >= 2;
    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              GamePageHeader(title: l10n.t('duel_title')),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.cosmicRed, fontSize: 15),
                ),
                const SizedBox(height: 16),
              ],
              if (snap != null && snap.status == 'done' && snap.sessionId == null)
                Text(
                  l10n.t('err_duel_done'),
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 18),
                )
              else if (inLobby) ...[
                Text(
                  l10n.t('room_code'),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  snap.code ?? '',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DuelButton(
                        label: l10n.t('room_copy'),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: snap.code ?? ''),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.t('room_copied'))),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DuelButton(
                        label: l10n.t('room_share'),
                        onTap: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: l10n
                                  .t('duel_share_text')
                                  .replaceAll('{code}', snap.code ?? ''),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.t('room_players'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final row in snap.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      row.name,
                      style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 16),
                    ),
                  ),
                const SizedBox(height: 8),
                if (host && !friendHere)
                  Text(
                    l10n.t('duel_wait_friend'),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                if (!host)
                  Text(
                    l10n.t('room_waiting_host'),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                const SizedBox(height: 18),
                if (host && friendHere)
                  _DuelButton(label: l10n.t('duel_start'), onTap: _start),
                const SizedBox(height: 10),
                _DuelButton(label: l10n.t('room_leave'), onTap: _leave),
              ] else if (_joining) ...[
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 22),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: l10n.t('room_code_hint'),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 16),
                _DuelButton(label: l10n.t('duel_join'), onTap: _join),
              ] else ...[
                Text(
                  l10n.t('duel_sub'),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                _DuelButton(label: l10n.t('duel_create'), onTap: _create),
                const SizedBox(height: 12),
                _DuelButton(
                  label: l10n.t('duel_join'),
                  onTap: () => setState(() => _joining = true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DuelButton extends StatelessWidget {
  const _DuelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicGlassCard(
      onTap: onTap,
      colors: const [
        AppColors.cosmicBlue,
        AppColors.cosmicTeal,
        AppColors.cosmicBlue,
      ],
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
