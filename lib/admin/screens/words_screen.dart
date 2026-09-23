import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/admin/word_csv_pick.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/entities/word_import_result.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  static const _pageSize = 50;

  String _query = '';
  WordStatus? _status;
  var _reloadToken = 0;
  var _importing = false;
  var _page = 0;
  String? _scope;

  Future<List<WordEntity>> _load(String locale, LeagueTier league) async {
    final all = await adminServer(context).adminListWords();
    return all.where((w) {
      if (w.language != locale) return false;
      if (w.length != league.wordLength) return false;
      if (_status != null && w.status != _status) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.displayWord.compareTo(b.displayWord));
  }

  bool _searchReady(String locale) =>
      GameLocale.resolve(locale).letterCount(_query.trim()) >= 3;

  List<WordEntity> _visible(List<WordEntity> words, String locale) {
    if (!_searchReady(locale)) return words;
    final q = _query.trim().toLowerCase();
    return words.where((w) {
      return w.word.toLowerCase().contains(q) ||
          w.category.toLowerCase().contains(q) ||
          w.definition.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _saveDefinition(WordEntity w, String definition) async {
    final trimmed = definition.trim();
    if (trimmed == w.definition) return;
    await adminServer(context).adminUpsertWord(
      w.copyWith(definition: trimmed, updatedAt: DateTime.now()),
    );
    setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    final locale = AdminLocaleScope.of(context);
    final league = AdminLocaleScope.leagueOf(context);
    final scope = '$locale-${league.name}';
    if (_scope != scope) {
      _scope = scope;
      _page = 0;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'En az 3 harf yaz',
                    helperText: _query.trim().isEmpty || _searchReady(locale)
                        ? null
                        : 'Arama 3 harfte başlar',
                  ),
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'CSV yükle',
                onPressed: _importing ? null : _importCsv,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
              ),
              IconButton(
                onPressed: () => _edit(null, locale),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Hepsi'),
                selected: _status == null,
                onSelected: (_) => setState(() {
                  _status = null;
                  _page = 0;
                }),
              ),
              for (final s in WordStatus.values)
                FilterChip(
                  label: Text(s.name),
                  selected: _status == s,
                  onSelected: (_) => setState(() {
                    _status = s;
                    _page = 0;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AdminBody(
            key: ValueKey(
              '$_reloadToken-$locale-${league.name}-$_status',
            ),
            future: _load(locale, league),
            builder: (context, words) {
              final visible = _visible(words, locale);
              if (visible.isEmpty) {
                return const Center(
                  child: Text(
                    '0 satır listelendi',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              final pages = (visible.length / _pageSize).ceil();
              final page = _page.clamp(0, pages - 1);
              final start = page * _pageSize;
              final slice = visible.skip(start).take(_pageSize).toList();
              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.surface,
                          ),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 72,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Kelime')),
                            DataColumn(label: Text('Harf'), numeric: true),
                            DataColumn(label: Text('Dil')),
                            DataColumn(label: Text('Durum')),
                            DataColumn(label: Text('Kategori')),
                            DataColumn(label: Text('Anlam')),
                            DataColumn(label: Text('Kullanım'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final w in slice)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      w.displayWord,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onTap: () => _edit(w, locale),
                                  ),
                                  DataCell(Text('${w.length}')),
                                  DataCell(Text(w.language.toUpperCase())),
                                  DataCell(Text(w.status.name)),
                                  DataCell(Text(w.category)),
                                  DataCell(
                                    SizedBox(
                                      width: 260,
                                      child: _MeaningField(
                                        key: ValueKey(
                                          '${w.id}-${w.definition}',
                                        ),
                                        initial: w.definition,
                                        onSubmit: (v) => _saveDefinition(w, v),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${w.usedCount}')),
                                  DataCell(
                                    Switch(
                                      value: w.playable,
                                      onChanged: (v) async {
                                        await adminServer(context).adminUpsertWord(
                                          w.copyWith(
                                            isActive: v,
                                            status: v
                                                ? WordStatus.active
                                                : WordStatus.draft,
                                          ),
                                        );
                                        setState(() => _reloadToken++);
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Düzenle',
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _edit(w, locale),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                    ),
                  ),
                  _Pager(
                    page: page,
                    pages: pages,
                    shown: slice.length,
                    total: visible.length,
                    onPage: (next) => setState(() => _page = next),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _importCsv() async {
    final csv = await pickWordCsv();
    if (csv == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final result = await adminServer(context).adminImportWords(csv);
      if (!mounted) return;
      setState(() => _reloadToken++);
      await _showImportSummary(result);
    } on AppFailure catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dosya hatası'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _showImportSummary(WordImportResult result) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yükleme bitti'),
        content: Text(
          '${result.imported} kayıt yüklendi.\n'
          '${result.skipped} kayıt zaten vardı.\n'
          '${result.invalid} satır atlandı.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(WordEntity? existing, String defaultLocale) async {
    final server = adminServer(context);
    final word = TextEditingController(text: existing?.word ?? '');
    final def = TextEditingController(text: existing?.definition ?? '');
    final ex = TextEditingController(text: existing?.exampleSentence ?? '');
    final en = TextEditingController(text: existing?.englishTranslation ?? '');
    final cat = TextEditingController(text: existing?.category ?? 'genel');
    var status = existing?.status ?? WordStatus.draft;
    var language = existing?.language ?? defaultLocale;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Yeni kelime' : 'Kelime düzenle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: word,
                    decoration: const InputDecoration(labelText: 'Kelime'),
                  ),
                  TextField(
                    controller: def,
                    decoration: const InputDecoration(labelText: 'Anlam'),
                  ),
                  TextField(
                    controller: ex,
                    decoration: const InputDecoration(labelText: 'Örnek'),
                  ),
                  TextField(
                    controller: en,
                    decoration: const InputDecoration(labelText: 'İngilizce'),
                  ),
                  TextField(
                    controller: cat,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                  ),
                  DropdownButton<String>(
                    value: language,
                    items: GameLocale.all
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.id.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => language = v);
                    },
                  ),
                  DropdownButton<WordStatus>(
                    value: status,
                    items: WordStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => status = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await server.adminDeleteWord(existing.id);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Sil'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && word.text.trim().isNotEmpty) {
      final now = DateTime.now();
      await server.adminUpsertWord(
        WordEntity(
          id: existing?.id ?? '',
          word: word.text.trim(),
          language: language,
          length: GameLocale.resolve(language).letterCount(word.text.trim()),
          difficulty: existing?.difficulty ?? 2,
          frequency: existing?.frequency ?? 3,
          category: cat.text.trim(),
          definition: def.text.trim(),
          exampleSentence: ex.text.trim(),
          englishTranslation: en.text.trim(),
          status: status,
          isActive: status == WordStatus.active,
          usedCount: existing?.usedCount ?? 0,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      setState(() => _reloadToken++);
    }
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pages,
    required this.shown,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int pages;
  final int shown;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        children: [
          Text(
            '$shown satır listelendi · ${page + 1} / $pages · toplam $total',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Önceki',
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Sonraki',
            onPressed: page + 1 < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MeaningField extends StatefulWidget {
  const _MeaningField({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final String initial;
  final Future<void> Function(String value) onSubmit;

  @override
  State<_MeaningField> createState() => _MeaningFieldState();
}

class _MeaningFieldState extends State<_MeaningField> {
  late final _controller = TextEditingController(text: widget.initial);
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_controller.text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Anlam yaz…',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: _saving
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Kaydet',
                icon: const Icon(Icons.check, size: 18),
                onPressed: _commit,
              ),
      ),
      onSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
    );
  }
}
