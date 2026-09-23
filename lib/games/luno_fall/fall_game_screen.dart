import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/games/luno_fall/fall_copy.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/fall_words.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.vy,
    required this.letter,
    this.special,
  });

  double x;
  double y;
  double vy;
  String letter;
  FallSpecial? special;
  bool gone = false;
}

class FallGameScreen extends StatefulWidget {
  const FallGameScreen({super.key, required this.difficulty});

  final FallDifficulty difficulty;

  @override
  State<FallGameScreen> createState() => _FallGameScreenState();
}

class _FallGameScreenState extends State<FallGameScreen>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late final Ticker _ticker;
  Timer? _spawn;
  Timer? _clock;
  Timer? _adTimer;

  String _locale = 'tr';
  FallWord? _word;
  int _index = 0;
  int _score = 0;
  int _lives = 3;
  int _combo = 0;
  int _maxCombo = 0;
  int _words = 0;
  int _level = 1;
  int _timeLeft = 45;
  double _speed = 1.4;
  int _spawnMs = 850;
  double _wrong = 0.35;
  bool _shield = false;
  bool _mirror = false;
  bool _ice = false;
  Timer? _iceTimer;
  bool _running = false;
  bool _paused = false;
  String? _banner;
  int? _waitLeft;
  int _adLeft = 0;
  FallRunEnd? _end;
  var _closing = false;
  Size _area = Size.zero;
  double _catcher = 160;
  double _catcherTarget = 160;
  final _drops = <_Drop>[];
  Duration? _last;

  LunoFallServer get _server => sl<LunoFallServer>();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_frame)..start();
    _boot();
  }

  Future<void> _boot() async {
    _locale = await _server.locale();
    final rule = FallRules.difficulty[widget.difficulty]!;
    _lives = rule.lives;
    _speed = rule.speed;
    _spawnMs = rule.spawnMs;
    _wrong = rule.wrongRate;
    _timeLeft = rule.seconds;
    _word = await _server.nextWord(widget.difficulty);
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _running = true;
    _armSpawn();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running || _paused || _end != null) return;
      setState(() => _timeLeft -= 1);
      if (_timeLeft <= 0) _finish();
    });
  }

  void _armSpawn() {
    _spawn?.cancel();
    _spawn = Timer.periodic(Duration(milliseconds: max(280, _spawnMs)), (_) {
      if (_running && !_paused && _end == null) _spawnDrop();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spawn?.cancel();
    _clock?.cancel();
    _iceTimer?.cancel();
    _adTimer?.cancel();
    super.dispose();
  }

  void _frame(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (!_running || _paused || _end != null || last == null || _area == Size.zero) {
      return;
    }
    final dt = (elapsed - last).inMilliseconds / 16.67;
    _catcher += (_catcherTarget - _catcher) * (0.22 * dt).clamp(0, 1);
    final slow = _ice ? 0.4 : 1.0;
    final next = _word?.word;
    for (final drop in _drops) {
      if (drop.gone) continue;
      drop.y += drop.vy * dt * slow * (_area.height / 520);
      final caught = drop.y > _area.height - 78 &&
          (drop.x - _catcher).abs() < 36;
      if (caught) {
        drop.gone = true;
        _catch(drop);
      } else if (drop.y > _area.height + 20) {
        drop.gone = true;
        if (drop.special == null &&
            next != null &&
            _index < next.length &&
            drop.letter == next[_index]) {
          _combo = 0;
        }
      }
    }
    _drops.removeWhere((drop) => drop.gone);
    if (mounted) setState(() {});
  }

  void _spawnDrop() {
    final word = _word?.word;
    if (word == null || _area == Size.zero || _index >= word.length) return;
    final roll = _random.nextDouble();
    FallSpecial? special;
    var letter = word[_index];
    if (roll > 0.65) {
      special = _rollSpecial();
      letter = switch (special) {
        FallSpecial.gold => '★',
        FallSpecial.bomb => '!',
        FallSpecial.ice => '*',
        FallSpecial.shield => '+',
        FallSpecial.joker => '?',
        FallSpecial.mirror => '2',
        FallSpecial.time => '+',
      };
    } else if (_random.nextDouble() < _wrong) {
      final alphabet = _locale == 'en' ? fallAlphabetEn : fallAlphabetTr;
      do {
        letter = alphabet[_random.nextInt(alphabet.length)];
      } while (letter == word[_index]);
    }
    _drops.add(
      _Drop(
        x: 24 + _random.nextDouble() * max(1, _area.width - 48),
        y: -30,
        vy: _speed * 2.4 + _random.nextDouble(),
        letter: letter,
        special: special,
      ),
    );
  }

  FallSpecial _rollSpecial() {
    final roll = _random.nextDouble();
    if (roll < 0.10 / 0.35) return FallSpecial.gold;
    if (roll < 0.18 / 0.35) return FallSpecial.bomb;
    if (roll < 0.23 / 0.35) return FallSpecial.ice;
    if (roll < 0.28 / 0.35) return FallSpecial.shield;
    if (roll < 0.31 / 0.35) return FallSpecial.joker;
    if (roll < 0.33 / 0.35) return FallSpecial.mirror;
    return FallSpecial.time;
  }

  void _catch(_Drop drop) {
    final special = drop.special;
    if (special != null) {
      switch (special) {
        case FallSpecial.gold:
          _score += 25;
          _banner = '+25';
        case FallSpecial.bomb:
          if (_shield) {
            _shield = false;
            _banner = fallText(_locale, 'lives');
          } else {
            _lives -= 2;
            _combo = 0;
            _score = max(0, _score - 10);
          }
        case FallSpecial.ice:
          _ice = true;
          _iceTimer?.cancel();
          _iceTimer = Timer(const Duration(seconds: 3), () {
            _ice = false;
          });
          _banner = '3s';
        case FallSpecial.shield:
          _shield = true;
        case FallSpecial.joker:
          _fillNext();
          _score += 15;
        case FallSpecial.mirror:
          _mirror = true;
        case FallSpecial.time:
          _timeLeft += 5;
      }
      if (_lives <= 0) _finish();
      return;
    }
    final word = _word!.word;
    if (_index < word.length && drop.letter == word[_index]) {
      _combo += 1;
      _maxCombo = max(_maxCombo, _combo);
      final mult = FallRules.comboMultiplier(_combo);
      _score += (10 * mult).round();
      _fillNext();
      if (_mirror) {
        _score += (10 * mult).round();
        _mirror = false;
        _banner = 'x2';
      } else {
        final name = FallRules.comboName(_combo, _locale);
        if (name.isNotEmpty) _banner = name;
      }
    } else if (_shield) {
      _shield = false;
      _combo = 0;
    } else {
      _lives -= 1;
      _combo = 0;
      if (_lives <= 0) _finish();
    }
  }

  void _fillNext() {
    final word = _word?.word;
    if (word == null || _index >= word.length) return;
    _index += 1;
    if (_index >= word.length) _completeWord();
  }

  Future<void> _completeWord() async {
    final rule = FallRules.difficulty[widget.difficulty]!;
    _score += (50 * rule.scoreMult).round();
    _words += 1;
    if (_words % 3 == 0) {
      _level += 1;
      _speed = min(3.5, _speed + 0.15);
      _spawnMs = max(400, _spawnMs - 50);
      _wrong = min(0.55, _wrong + 0.02);
      _armSpawn();
      _banner = 'Lv $_level';
    }
    final next = await _server.nextWord(widget.difficulty, avoid: _word?.word);
    if (!mounted) return;
    setState(() {
      _word = next;
      _index = 0;
    });
  }

  Future<void> _finish() async {
    if (_closing || _end != null) return;
    _closing = true;
    _running = false;
    _spawn?.cancel();
    final end = await _server.finishRun(
      difficulty: widget.difficulty,
      score: _score,
      words: _words,
      maxCombo: _maxCombo,
    );
    if (!mounted) return;
    setState(() {
      _end = end;
      _waitLeft = end.waitSeconds;
    });
    if (end.waitSeconds > 0) {
      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_waitLeft == null || _end == null) return;
        if (_waitLeft! <= 1) {
          _replay();
        } else {
          setState(() => _waitLeft = _waitLeft! - 1);
        }
      });
    }
  }

  Future<void> _replay() async {
    _adTimer?.cancel();
    _drops.clear();
    _end = null;
    _closing = false;
    _waitLeft = null;
    _index = 0;
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _words = 0;
    _level = 1;
    _shield = false;
    _mirror = false;
    _ice = false;
    _banner = null;
    final rule = FallRules.difficulty[widget.difficulty]!;
    _lives = rule.lives;
    _speed = rule.speed;
    _spawnMs = rule.spawnMs;
    _wrong = rule.wrongRate;
    _timeLeft = rule.seconds;
    _word = await _server.nextWord(widget.difficulty);
    _running = true;
    _armSpawn();
    if (mounted) setState(() {});
  }

  void _watchAd() {
    setState(() => _adLeft = 5);
    _adTimer?.cancel();
    _adTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_adLeft <= 1) {
        _adTimer?.cancel();
        _replay();
      } else {
        setState(() => _adLeft -= 1);
      }
    });
  }

  void _aim(double dx, double width) {
    _catcherTarget = dx.clamp(28, width - 28);
  }

  Future<void> _use(String field) async {
    if (!_running || _end != null) return;
    final ok = await _server.consume(field);
    if (!ok || !mounted) return;
    setState(() {
      switch (field) {
        case 'hints':
          _fillNext();
        case 'shields':
          _shield = true;
        case 'jokers':
          _fillNext();
          _score += 15;
        case 'extraLives':
          _lives += 1;
        case 'extraTimes':
          _timeLeft += 10;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = _word;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/fall'),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Text(
                    '${fallText(_locale, 'score')} $_score',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text('❤' * max(0, _lives), style: const TextStyle(color: Color(0xFFE74C3C))),
                  IconButton(
                    onPressed: () => setState(() => _paused = !_paused),
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (word != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    Text(word.clue, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      '${word.word.length} · ${word.category}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 0; i < word.word.length; i++)
                          Container(
                            width: 28,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1ABC9C)),
                              color: i < _index
                                  ? const Color(0x332ECC71)
                                  : const Color(0x221E293B),
                            ),
                            child: Text(
                              i < _index ? word.word[i] : '',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            Text(
              '$_timeLeft  ${fallText(_locale, 'no_midgame_ad')}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _area = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onPanDown: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
                    onPanUpdate: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
                    child: Stack(
                      children: [
                        for (final drop in _drops)
                          Positioned(
                            left: drop.x - 16,
                            top: drop.y,
                            child: _Token(drop: drop),
                          ),
                        Positioned(
                          left: _catcher - 28,
                          bottom: 16,
                          child: Container(
                            width: 56,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                              ),
                            ),
                          ),
                        ),
                        if (_banner != null)
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              _banner!,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF1C40F),
                              ),
                            ),
                          ),
                        if (_end != null) _result(context),
                        if (_adLeft > 0)
                          ColoredBox(
                            color: const Color(0xCC0A0E1A),
                            child: Center(
                              child: Text(
                                '${fallText(_locale, 'mock_ad')} $_adLeft',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Tool(label: 'A', onTap: () => _use('hints')),
                  _Tool(label: '+', onTap: () => _use('shields')),
                  _Tool(label: '?', onTap: () => _use('jokers')),
                  _Tool(label: '❤', onTap: () => _use('extraLives')),
                  _Tool(label: '+10', onTap: () => _use('extraTimes')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final end = _end!;
    return ColoredBox(
      color: const Color(0xE60A0E1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fallText(_locale, 'result'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('$_score · $_words ${fallText(_locale, 'words')} · x$_maxCombo'),
              Text('+${end.coinsEarned} ${fallText(_locale, 'coins')}'),
              const SizedBox(height: 16),
              if (_adLeft == 0)
                FilledButton(
                  onPressed: _watchAd,
                  child: Text(fallText(_locale, 'watch')),
                ),
              const SizedBox(height: 8),
              if ((_waitLeft ?? 0) > 0)
                Text('${fallText(_locale, 'wait')} ${_waitLeft}s'),
              TextButton(
                onPressed: () => context.go('/fall'),
                child: Text(fallText(_locale, 'menu')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({required this.drop});

  final _Drop drop;

  @override
  Widget build(BuildContext context) {
    final special = drop.special != null;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: special ? const Color(0xFF9B59B6) : const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF2ECC71)),
      ),
      child: Text(
        drop.letter,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(label));
  }
}
