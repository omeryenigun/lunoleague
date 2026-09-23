import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/app_config.dart';

enum _ConfigKind { number, streakMap, intList }

class _ConfigRow {
  const _ConfigRow({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.read,
    required this.defaultValue,
    required this.apply,
  });

  final String id;
  final String title;
  final String description;
  final _ConfigKind kind;
  final String Function(AppConfig c) read;
  final String Function(AppConfig defaults) defaultValue;
  final AppConfig Function(AppConfig c, String raw) apply;
}

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  var _reloadToken = 0;
  String? _busyId;

  static final _defaults = AppConfig.defaults();

  static final _rows = <_ConfigRow>[
    _ConfigRow(
      id: 'dailyWinXp',
      title: 'Daily XP',
      description: 'İpuçsuz Daily kazanıldığında verilen XP.',
      kind: _ConfigKind.number,
      read: (c) => '${c.dailyWinXp}',
      defaultValue: (d) => '${d.dailyWinXp}',
      apply: (c, raw) => c.copyWith(dailyWinXp: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'dailyWinXpWithHint',
      title: 'İpuçlu Daily XP',
      description: 'İpucu kullanılan Daily kazanımında verilen XP.',
      kind: _ConfigKind.number,
      read: (c) => '${c.dailyWinXpWithHint}',
      defaultValue: (d) => '${d.dailyWinXpWithHint}',
      apply: (c, raw) => c.copyWith(dailyWinXpWithHint: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'perfectBonusXp',
      title: 'Mükemmel bonus XP',
      description: 'Tek tahminde (mükemmel) bitirme bonusu.',
      kind: _ConfigKind.number,
      read: (c) => '${c.perfectBonusXp}',
      defaultValue: (d) => '${d.perfectBonusXp}',
      apply: (c, raw) => c.copyWith(perfectBonusXp: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'noHintBonusXp',
      title: 'İpuçsuz bonus XP',
      description: 'İpuçsuz tamamlanan Daily için ek XP.',
      kind: _ConfigKind.number,
      read: (c) => '${c.noHintBonusXp}',
      defaultValue: (d) => '${d.noHintBonusXp}',
      apply: (c, raw) => c.copyWith(noHintBonusXp: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'endlessXp',
      title: 'Endless XP',
      description: 'Endless tur kazanımında verilen XP.',
      kind: _ConfigKind.number,
      read: (c) => '${c.endlessXp}',
      defaultValue: (d) => '${d.endlessXp}',
      apply: (c, raw) => c.copyWith(endlessXp: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'endlessCoins',
      title: 'Endless coin',
      description: 'Endless tur kazanımında verilen coin.',
      kind: _ConfigKind.number,
      read: (c) => '${c.endlessCoins}',
      defaultValue: (d) => '${d.endlessCoins}',
      apply: (c, raw) => c.copyWith(endlessCoins: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'dailyWinCoins',
      title: 'Daily kazanma coin',
      description: 'Daily kazanıldığında verilen coin.',
      kind: _ConfigKind.number,
      read: (c) => '${c.dailyWinCoins}',
      defaultValue: (d) => '${d.dailyWinCoins}',
      apply: (c, raw) => c.copyWith(dailyWinCoins: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'dailyLoseCoins',
      title: 'Daily kayıp coin',
      description: 'Daily kaybedildiğinde verilen / düşülen coin.',
      kind: _ConfigKind.number,
      read: (c) => '${c.dailyLoseCoins}',
      defaultValue: (d) => '${d.dailyLoseCoins}',
      apply: (c, raw) => c.copyWith(dailyLoseCoins: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'hint1Cost',
      title: 'İpucu 1 maliyeti',
      description: 'Harf ipucunun coin maliyeti.',
      kind: _ConfigKind.number,
      read: (c) => '${c.hint1Cost}',
      defaultValue: (d) => '${d.hint1Cost}',
      apply: (c, raw) => c.copyWith(hint1Cost: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'hint2Cost',
      title: 'İpucu 2 maliyeti',
      description: 'Anlam ipucunun coin maliyeti.',
      kind: _ConfigKind.number,
      read: (c) => '${c.hint2Cost}',
      defaultValue: (d) => '${d.hint2Cost}',
      apply: (c, raw) => c.copyWith(hint2Cost: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'adCoinReward',
      title: 'Reklam coin',
      description: 'Reklam izleme ödülü (coin).',
      kind: _ConfigKind.number,
      read: (c) => '${c.adCoinReward}',
      defaultValue: (d) => '${d.adCoinReward}',
      apply: (c, raw) => c.copyWith(adCoinReward: int.parse(raw)),
    ),
    _ConfigRow(
      id: 'streakBonusXp',
      title: 'Streak bonus XP',
      description:
          'Seri gün eşiklerine göre bonus XP. Format: 5:100, 7:250, 14:500',
      kind: _ConfigKind.streakMap,
      read: (c) =>
          c.streakBonusXp.entries.map((e) => '${e.key}:${e.value}').join(', '),
      defaultValue: (d) =>
          d.streakBonusXp.entries.map((e) => '${e.key}:${e.value}').join(', '),
      apply: (c, raw) => c.copyWith(streakBonusXp: _parseStreak(raw)),
    ),
    _ConfigRow(
      id: 'levelXpThresholds',
      title: 'Level XP eşikleri',
      description:
          'Seviye atlama için gereken kümülatif XP listesi (virgülle).',
      kind: _ConfigKind.intList,
      read: (c) => c.levelXpThresholds.join(', '),
      defaultValue: (d) => d.levelXpThresholds.join(', '),
      apply: (c, raw) => c.copyWith(levelXpThresholds: _parseIntList(raw)),
    ),
  ];

  static Map<int, int> _parseStreak(String raw) {
    final out = <int, int>{};
    final parts = raw.split(RegExp(r'[,;\s]+')).where((e) => e.isNotEmpty);
    for (final part in parts) {
      final bits = part.split(RegExp(r'[:|=]'));
      if (bits.length != 2) {
        throw const FormatException('Format: 5:100, 7:250');
      }
      final day = int.tryParse(bits[0].replaceAll(RegExp(r'[^0-9]'), ''));
      final xp = int.tryParse(bits[1].trim());
      if (day == null || xp == null) {
        throw const FormatException('Format: 5:100, 7:250');
      }
      out[day] = xp;
    }
    if (out.isEmpty) throw const FormatException('En az bir eşik girin');
    return out;
  }

  static List<int> _parseIntList(String raw) {
    final out = <int>[];
    for (final part in raw.split(RegExp(r'[,;\s]+'))) {
      if (part.isEmpty) continue;
      final v = int.tryParse(part.trim());
      if (v == null) {
        throw const FormatException('Virgülle ayrılmış sayılar girin');
      }
      out.add(v);
    }
    if (out.isEmpty) throw const FormatException('En az bir değer girin');
    return out;
  }

  Future<void> _save(AppConfig updated, String id) async {
    setState(() => _busyId = id);
    try {
      await adminServer(context).adminUpdateConfig(updated);
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _reloadToken++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editRow(AppConfig current, _ConfigRow row) async {
    final controller = TextEditingController(text: row.read(current));
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row.title),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  row.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  minLines: row.kind == _ConfigKind.number ? 1 : 2,
                  maxLines: row.kind == _ConfigKind.number ? 1 : 4,
                  keyboardType: row.kind == _ConfigKind.number
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: row.kind == _ConfigKind.number
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Değer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (t) {
                    final raw = t?.trim() ?? '';
                    if (raw.isEmpty) return 'Zorunlu';
                    try {
                      row.apply(current, raw);
                    } catch (e) {
                      return '$e';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final updated = row.apply(current, controller.text.trim());
      await _save(updated, row.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resetRow(AppConfig current, _ConfigRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılana dön'),
        content: Text(
          '${row.title} varsayılan değere (${row.defaultValue(_defaults)}) dönsün mü?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Varsayılana dön'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = row.apply(current, row.defaultValue(_defaults));
    await _save(updated, row.id);
  }

  @override
  Widget build(BuildContext context) {
    return AdminBody(
      key: ValueKey(_reloadToken),
      future: adminServer(context).getConfig(),
      builder: (context, AppConfig c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Uygulama ayarları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.surface),
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 80,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Başlık')),
                            DataColumn(label: Text('Tanım')),
                            DataColumn(label: Text('Değer')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final row in _rows)
                              DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        row.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 280,
                                      child: Text(
                                        row.description,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        row.read(c),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _busyId == row.id
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _editRow(c, row),
                                                child: const Text('Düzenle'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _resetRow(c, row),
                                                child: const Text(
                                                  'Varsayılana dön',
                                                ),
                                              ),
                                            ],
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
          ],
        );
      },
    );
  }
}
