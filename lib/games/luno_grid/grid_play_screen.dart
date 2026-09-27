import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';
import 'package:kelimelig/games/luno_grid/grid_rules.dart';
import 'package:kelimelig/games/luno_grid/luno_grid_server.dart';
import 'package:kelimelig/injection.dart';

class GridPlayScreen extends StatefulWidget {
  const GridPlayScreen({
    super.key,
    required this.puzzle,
    required this.dictionary,
    this.preview = false,
    this.playerName = 'Oyuncu',
  });

  final GridPuzzle puzzle;
  final Set<String> dictionary;
  final bool preview;
  final String playerName;

  @override
  State<GridPlayScreen> createState() => _GridPlayScreenState();
}

class _GridPlayScreenState extends State<GridPlayScreen> {
  late final Map<String, String> _filled;
  late List<String> _circle;
  final _found = <String>[];
  final _drag = <int>[];
  var _score = 0;
  var _combo = 1;
  DateTime? _lastFind;
  late final DateTime _started;
  var _done = false;
  String? _note;
  final _highlight = <String>{};

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();
    _circle = [...widget.puzzle.circle]..shuffle();
    _filled = {
      for (final cell in widget.puzzle.cells)
        if (cell.given) cell.key: cell.letter,
    };
  }

  List<GridCell> get _cells => widget.puzzle.cells;

  bool _complete() {
    return _cells.every((cell) => _filled.containsKey(cell.key));
  }

  Future<void> _submit(String raw) async {
    final word = TurkishText.toUpper(raw);
    if (word.length < 3 || _found.contains(word) || !widget.dictionary.contains(word)) {
      setState(() => _note = 'Bu kelime yok');
      return;
    }
    if (!GridRules.canSpell(word, widget.puzzle.circle)) {
      setState(() => _note = 'Harfler yetmiyor');
      return;
    }
    final slots = widget.puzzle.words.where((slot) => slot.word == word).toList();
    if (slots.length > 1) {
      setState(() {
        _pendingWord = word;
        _note = 'Yer seç';
      });
      return;
    }
    if (slots.length == 1) {
      _place(slots.first, word, gridWord: true);
    } else {
      _scoreWord(word, gridWord: false);
    }
    await _afterWord();
  }

  String? _pendingWord;

  void _place(GridWord slot, String word, {required bool gridWord}) {
    final letters = TurkishText.letters(word);
    for (var i = 0; i < letters.length; i++) {
      final x = slot.across ? slot.x + i : slot.x;
      final y = slot.across ? slot.y : slot.y + i;
      _filled['$x,$y'] = letters[i];
    }
    _scoreWord(word, gridWord: gridWord);
  }

  void _scoreWord(String word, {required bool gridWord}) {
    final now = DateTime.now();
    _combo = _lastFind == null ? 1 : GridRules.comboAfter(_combo, now.difference(_lastFind!));
    _lastFind = now;
    final gain = GridRules.lengthScore(TurkishText.letterCount(word)) * _combo + (gridWord ? 20 : 40);
    _score += gain;
    _found.add(word);
    _note = gridWord ? '+$gain' : 'Bonus +$gain';
  }

  Future<void> _afterWord() async {
    final finished = _complete();
      if (finished && !_done) {
      _done = true;
      _score += 300 + GridRules.speedBonus(DateTime.now().difference(_started));
      if (!widget.preview) {
        final before = await sl<LunoGridServer>().profile();
        await sl<LunoGridServer>().recordScore(
          sceneId: widget.puzzle.id,
          score: _score,
          name: widget.playerName,
        );
        if (before.gamesFinished >= 1 && !before.noAds && mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reklam'),
              content: const Text('Bu reklam atlanabilir. Puan veya coin vermez.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Geç')),
              ],
            ),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _openHints() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('İlk boş harf'),
              trailing: const Text('−50'),
              onTap: () {
                Navigator.pop(context);
                _hintLetter();
              },
            ),
            ListTile(
              title: const Text('Kelimeyi aç'),
              trailing: const Text('−100'),
              onTap: () {
                Navigator.pop(context);
                _hintWord();
              },
            ),
            ListTile(
              title: const Text('Yerini göster'),
              trailing: const Text('−75'),
              onTap: () {
                Navigator.pop(context);
                _hintPosition();
              },
            ),
          ],
        ),
      ),
    );
  }

  GridWord? _nextOpenWord() {
    for (final word in widget.puzzle.words) {
      if (_found.contains(word.word)) continue;
      return word;
    }
    return null;
  }

  void _hintLetter() {
    final word = _nextOpenWord();
    if (word == null) return;
    final letters = word.letters;
    for (var i = 0; i < letters.length; i++) {
      final key = _cellKey(word, i);
      if (_filled.containsKey(key)) continue;
      setState(() {
        _filled[key] = letters[i];
        _score = max(0, _score - 50);
        _note = 'Harf −50';
      });
      return;
    }
  }

  void _hintWord() {
    final word = _nextOpenWord();
    if (word == null) return;
    final letters = word.letters;
    setState(() {
      for (var i = 0; i < letters.length; i++) {
        _filled[_cellKey(word, i)] = letters[i];
      }
      if (!_found.contains(word.word)) _found.add(word.word);
      _score = max(0, _score - 100);
      _note = 'Kelime −100';
    });
    _afterWord();
  }

  void _hintPosition() {
    final word = _nextOpenWord();
    if (word == null) return;
    setState(() {
      _highlight
        ..clear()
        ..addAll([for (var i = 0; i < word.letters.length; i++) _cellKey(word, i)]);
      _score = max(0, _score - 75);
      _note = 'Yer −75';
    });
  }

  String _cellKey(GridWord word, int index) {
    final x = word.across ? word.x + index : word.x;
    final y = word.across ? word.y : word.y + index;
    return '$x,$y';
  }

  @override
  Widget build(BuildContext context) {
    final palette = gridPalettes[widget.puzzle.palette % gridPalettes.length];
    final bounds = _bounds();
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.top, palette.bottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Text('$_score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  const Text('PUAN', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.4)),
                  const Spacer(),
                  IconButton(
                    onPressed: _done ? null : _openHints,
                    icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GridBoard(
                    cells: _cells,
                    filled: _filled,
                    columns: bounds.$1 + 1,
                    rows: bounds.$2 + 1,
                    pending: _pendingWord,
                    highlight: _highlight,
                    words: widget.puzzle.words,
                    onPick: (slot) {
                      final word = _pendingWord;
                      if (word == null || slot.word != word) return;
                      setState(() {
                        _place(slot, word, gridWord: true);
                        _pendingWord = null;
                      });
                      _afterWord();
                    },
                  ),
                ),
              ),
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_note!, style: const TextStyle(color: Colors.white)),
                ),
              if (_done)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF14B87A), borderRadius: BorderRadius.circular(16)),
                  child: const Text('GRID TAMAM!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              SizedBox(
                height: 280,
                child: _Wheel(
                  letters: _circle,
                  drag: _drag,
                  onShuffle: () => setState(() => _circle.shuffle()),
                  onChange: (path) => setState(() {
                    _drag
                      ..clear()
                      ..addAll(path);
                  }),
                  onEnd: (word) {
                    setState(_drag.clear);
                    if (word.length >= 3) _submit(word);
                  },
                ),
              ),
              if (_found.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final word in _found)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(word, style: const TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  (int, int) _bounds() {
    var maxX = 0;
    var maxY = 0;
    for (final cell in _cells) {
      if (cell.x > maxX) maxX = cell.x;
      if (cell.y > maxY) maxY = cell.y;
    }
    return (maxX, maxY);
  }
}

class _GridBoard extends StatelessWidget {
  const _GridBoard({
    required this.cells,
    required this.filled,
    required this.columns,
    required this.rows,
    required this.words,
    required this.onPick,
    required this.highlight,
    this.pending,
  });

  final List<GridCell> cells;
  final Map<String, String> filled;
  final int columns;
  final int rows;
  final List<GridWord> words;
  final String? pending;
  final Set<String> highlight;
  final ValueChanged<GridWord> onPick;

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final cell in cells) cell.key: cell};
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth / columns, constraints.maxHeight / rows);
        return Center(
          child: SizedBox(
            width: size * columns,
            height: size * rows,
            child: Stack(
              children: [
                for (var y = 0; y < rows; y++)
                  for (var x = 0; x < columns; x++)
                    if (byKey['$x,$y'] != null)
                      Positioned(
                        left: x * size,
                        top: y * size,
                        width: size - 4,
                        height: size - 4,
                        child: _Tile(
                          cell: byKey['$x,$y']!,
                          shown: filled['$x,$y'],
                          marked: highlight.contains('$x,$y'),
                        ),
                      ),
                if (pending != null)
                  for (final word in words.where((slot) => slot.word == pending))
                    Positioned(
                      left: word.x * size,
                      top: word.y * size,
                      child: GestureDetector(
                        onTap: () => onPick(word),
                        child: Container(
                          width: (word.across ? word.letters.length : 1) * size - 4,
                          height: (word.across ? 1 : word.letters.length) * size - 4,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF5EEAD4), width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.cell, required this.shown, required this.marked});

  final GridCell cell;
  final String? shown;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final open = shown != null;
    final color = !open
        ? Colors.white.withValues(alpha: 0.14)
        : cell.given
            ? const Color(0xFF9B4DFF)
            : const Color(0xFF2DD4BF);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: marked ? Border.all(color: const Color(0xFFFFD166), width: 3) : null,
      ),
      child: Center(
        child: Text(
          shown ?? '',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.letters,
    required this.drag,
    required this.onShuffle,
    required this.onChange,
    required this.onEnd,
  });

  final List<String> letters;
  final List<int> drag;
  final VoidCallback onShuffle;
  final ValueChanged<List<int>> onChange;
  final ValueChanged<String> onEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final centers = _centers(side, letters.length);
        return GestureDetector(
          onPanStart: (details) => _hit(details.localPosition, centers, []),
          onPanUpdate: (details) => _hit(details.localPosition, centers, drag),
          onPanEnd: (_) => onEnd(drag.map((index) => letters[index]).join()),
          child: Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: side * 0.78,
                      height: side * 0.78,
                      decoration: const BoxDecoration(color: Color(0xFFF4F4F8), shape: BoxShape.circle),
                    ),
                  ),
                  Center(
                    child: IconButton(
                      onPressed: onShuffle,
                      icon: const Icon(Icons.shuffle, color: Color(0xFFB0B0BE)),
                    ),
                  ),
                  if (drag.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF9B4DFF), borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            drag.map((index) => letters[index]).join(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  for (var i = 0; i < letters.length; i++)
                    Positioned(
                      left: centers[i].dx - 24,
                      top: centers[i].dy - 24,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: drag.contains(i) ? const Color(0xFF9B4DFF) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF9B4DFF)),
                        ),
                        child: Text(
                          letters[i],
                          style: TextStyle(
                            color: drag.contains(i) ? Colors.white : const Color(0xFF241447),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hit(Offset point, List<Offset> centers, List<int> path) {
    var best = -1;
    var bestDistance = 28.0;
    for (var i = 0; i < centers.length; i++) {
      final distance = (centers[i] - point).distance;
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    if (best < 0 || path.contains(best)) return;
    onChange([...path, best]);
  }

  List<Offset> _centers(double side, int count) {
    final radius = side * 0.30;
    final origin = Offset(side / 2, side / 2);
    return [
      for (var i = 0; i < count; i++)
        origin + Offset(cos(-pi / 2 + 2 * pi * i / count), sin(-pi / 2 + 2 * pi * i / count)) * radius,
    ];
  }
}
