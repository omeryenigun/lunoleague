import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/features/match/rival_notice.dart';
import 'package:kelimelig/injection.dart';

class RivalNoticeHost extends StatefulWidget {
  const RivalNoticeHost({super.key, required this.kind});

  final String kind;

  @override
  State<RivalNoticeHost> createState() => _RivalNoticeHostState();
}

class _RivalNoticeHostState extends State<RivalNoticeHost> {
  Timer? _timer;
  Timer? _hide;
  List<MatchRow>? _previous;
  final _queue = <RivalNotice>[];
  RivalNotice? _showing;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final server = sl<GameServer>();
      final user = await server.currentUser();
      final snap = await server.matchSnapshot(widget.kind);
      final notices = rivalNotices(
        previous: _previous,
        next: snap.rows,
        me: user?.id ?? '',
      );
      _previous = snap.rows;
      if (!mounted || notices.isEmpty) return;
      setState(() => _queue.addAll(notices));
      _showNext();
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  void _showNext() {
    if (_showing != null || _queue.isEmpty || !mounted) return;
    setState(() => _showing = _queue.removeAt(0));
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _showing = null);
      _showNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notice = _showing;
    if (notice == null) return const SizedBox.shrink();
    final l10n = sl<L10n>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEE0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  notice.kind == RivalNoticeKind.finished
                      ? l10n
                          .t(notice.solved ? 'match_found' : 'match_missed')
                          .replaceAll('{name}', notice.name)
                      : notice.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (notice.kind == RivalNoticeKind.colors) ...[
                _CountPip(color: AppColors.correct, count: notice.greens),
                const SizedBox(width: 10),
                _CountPip(color: AppColors.present, count: notice.yellows),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPip extends StatelessWidget {
  const _CountPip({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
