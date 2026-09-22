import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late var _year = DateTime.now().year;
  late var _month = DateTime.now().month;
  var _bulkAssigning = false;
  String? _dayBusy;
  var _reloadToken = 0;
  final _random = Random();

  static const _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const _weekdays = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  List<String> get _daysInMonth {
    final count = DateTime(_year, _month + 1, 0).day;
    return [
      for (var d = 1; d <= count; d++)
        DateKeys.dayKey(DateTime(_year, _month, d)),
    ];
  }

  Future<({List<WordEntity> words, Map<String, String> map})> _load() async {
    final words = await sl<GameServer>().adminListWords();
    final map = await sl<GameServer>().adminDailyMap();
    return (words: words, map: map);
  }

  String? _wordIdFor(
    Map<String, String> map,
    String day,
    String language,
    LeagueTier league,
  ) =>
      map['${day}_${language}_${league.name}'] ??
      (language == 'tr' ? map['${day}_${league.name}'] : null);

  Set<String> _usedInMonth(
    Map<String, String> map,
    String language,
    LeagueTier league,
  ) {
    final used = <String>{};
    for (final day in _daysInMonth) {
      final id = _wordIdFor(map, day, language, league);
      if (id != null) used.add(id);
    }
    return used;
  }

  List<WordEntity> _pool(
    List<WordEntity> words,
    String language,
    LeagueTier league,
  ) =>
      words
          .where(
            (w) =>
                w.playable &&
                w.length == league.wordLength &&
                w.language == language,
          )
          .toList()
        ..sort((a, b) => a.displayWord.compareTo(b.displayWord));

  Future<void> _bulkAuto(String language, LeagueTier league) async {
    setState(() => _bulkAssigning = true);
    try {
      final n = await sl<GameServer>().adminAutoAssignMonth(
        year: _year,
        month: _month,
        league: league,
        locale: language,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n güne otomatik kelime atandı')),
      );
      setState(() {
        _reloadToken++;
        _bulkAssigning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _bulkAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _autoDay({
    required String day,
    required String language,
    required LeagueTier league,
    required List<WordEntity> pool,
    required Map<String, String> map,
  }) async {
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uygun kelime havuzu boş')),
      );
      return;
    }
    setState(() => _dayBusy = day);
    try {
      final used = _usedInMonth(map, language, league);
      final current = _wordIdFor(map, day, language, league);
      final unused = pool.where((w) => !used.contains(w.id)).toList();
      final candidates = unused.isNotEmpty
          ? unused
          : pool.where((w) => w.id != current).toList();
      final pick = (candidates.isNotEmpty ? candidates : pool)[
          _random.nextInt((candidates.isNotEmpty ? candidates : pool).length)];
      await sl<GameServer>().adminSetDaily(
        dateKey: day,
        league: league,
        wordId: pick.id,
        language: language,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$day → ${pick.displayWord}')),
      );
      setState(() {
        _dayBusy = null;
        _reloadToken++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dayBusy = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _manualDay({
    required String day,
    required String language,
    required LeagueTier league,
    required List<WordEntity> pool,
    required Map<String, String> map,
    required Map<String, WordEntity> wordsById,
  }) async {
    final used = _usedInMonth(map, language, league);
    final currentId = _wordIdFor(map, day, language, league);
    final picked = await showDialog<WordEntity>(
      context: context,
      builder: (ctx) => _WordPickerDialog(
        day: day,
        leagueLabel: league.label,
        language: language,
        pool: pool,
        usedIds: used,
        currentId: currentId,
        currentWord: currentId == null ? null : wordsById[currentId],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dayBusy = day);
    try {
      await sl<GameServer>().adminSetDaily(
        dateKey: day,
        league: league,
        wordId: picked.id,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _dayBusy = null;
        _reloadToken++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dayBusy = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = AdminLocaleScope.of(context);
    final league = AdminLocaleScope.leagueOf(context);
    return AdminBody(
      key: ValueKey('$_reloadToken-$language-${league.name}-$_year-$_month'),
      future: _load(),
      builder: (context, data) {
        final wordsById = {for (final w in data.words) w.id: w};
        final pool = _pool(data.words, language, league);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Önceki ay',
                    onPressed: () => setState(() {
                      final prev = DateTime(_year, _month - 1, 1);
                      _year = prev.year;
                      _month = prev.month;
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  DropdownButton<int>(
                    value: _month,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(_monthNames[m - 1]),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _month = v);
                    },
                  ),
                  DropdownButton<int>(
                    value: _year,
                    items: [
                      for (var y = _year - 2; y <= _year + 2; y++)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _year = v);
                    },
                  ),
                  IconButton(
                    tooltip: 'Sonraki ay',
                    onPressed: () => setState(() {
                      final next = DateTime(_year, _month + 1, 1);
                      _year = next.year;
                      _month = next.month;
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  FilledButton.icon(
                    onPressed: _bulkAssigning
                        ? null
                        : () => _bulkAuto(language, league),
                    icon: _bulkAssigning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      _bulkAssigning ? 'Atanıyor…' : 'Eksikleri otomatik ata',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _daysInMonth.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0x1494A3B8)),
                itemBuilder: (context, i) {
                  final day = _daysInMonth[i];
                  final wordId = _wordIdFor(data.map, day, language, league);
                  final word = wordId == null ? null : wordsById[wordId];
                  final date = DateKeys.parseDay(day);
                  final busy = _dayBusy == day;
                  return ListTile(
                    leading: SizedBox(
                      width: 52,
                      child: Text(
                        '${date.day}\n${_weekdays[date.weekday - 1]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: word == null
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    title: Text(
                      word?.displayWord ?? '— atanmamış —',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: word == null
                            ? AppColors.warning
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      word?.definition.isNotEmpty == true
                          ? word!.definition
                          : '${language.toUpperCase()} · ${league.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Wrap(
                            spacing: 6,
                            children: [
                              OutlinedButton(
                                onPressed: () => _autoDay(
                                  day: day,
                                  language: language,
                                  league: league,
                                  pool: pool,
                                  map: data.map,
                                ),
                                child: const Text('Oto'),
                              ),
                              FilledButton(
                                onPressed: () => _manualDay(
                                  day: day,
                                  language: language,
                                  league: league,
                                  pool: pool,
                                  map: data.map,
                                  wordsById: wordsById,
                                ),
                                child: const Text('Manuel'),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WordPickerDialog extends StatefulWidget {
  const _WordPickerDialog({
    required this.day,
    required this.leagueLabel,
    required this.language,
    required this.pool,
    required this.usedIds,
    required this.currentId,
    required this.currentWord,
  });

  final String day;
  final String leagueLabel;
  final String language;
  final List<WordEntity> pool;
  final Set<String> usedIds;
  final String? currentId;
  final WordEntity? currentWord;

  @override
  State<_WordPickerDialog> createState() => _WordPickerDialogState();
}

class _WordPickerDialogState extends State<_WordPickerDialog> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.pool.where((w) {
      if (q.isEmpty) return true;
      return w.displayWord.toLowerCase().contains(q) ||
          w.definition.toLowerCase().contains(q) ||
          w.category.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: Text('${widget.day} · ${widget.leagueLabel}'),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentWord != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Şu an: ${widget.currentWord!.displayWord}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Kelime veya anlam ara…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Text(
              '${filtered.length} / ${widget.pool.length} kelime',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Sonuç yok',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final w = filtered[i];
                        final selected = w.id == widget.currentId;
                        final usedElsewhere =
                            widget.usedIds.contains(w.id) && !selected;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            w.displayWord,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              if (w.definition.isNotEmpty) w.definition,
                              if (usedElsewhere) 'ayda kullanılmış',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check, color: AppColors.accent)
                              : null,
                          onTap: () => Navigator.pop(context, w),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}
