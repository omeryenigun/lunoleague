import 'package:flutter/material.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';

/// One labeled row of the profile avatar picker.
class BilgiAvatarGroup {
  const BilgiAvatarGroup(this.label, this.emojis);

  final String label;
  final List<String> emojis;
}

const bilgiAvatarGroupSize = 12;

/// Woman faces and people. Default yellow tone, no Fitzpatrick modifiers.
const bilgiAvatarKadin = <String>[
  '👩',
  '👧',
  '👵',
  '👸',
  '🧕',
  '🤰',
  '💃',
  '👰‍♀️',
  '👩‍🎓',
  '👩‍🎤',
  '👩‍🍳',
  '👩‍⚕️',
];

/// Man faces and people. Default yellow tone, no Fitzpatrick modifiers.
const bilgiAvatarErkek = <String>[
  '👨',
  '👦',
  '👴',
  '🤴',
  '🧔',
  '👲',
  '🕺',
  '🤵‍♂️',
  '👳‍♂️',
  '👨‍🦰',
  '👨‍🎓',
  '👨‍🍳',
];

/// Fantasy and profession characters. No branded figures.
const bilgiAvatarKahraman = <String>[
  '🧙',
  '🥷',
  '🦸',
  '🦹',
  '🧑‍🚀',
  '🧛',
  '🧟',
  '🧞',
  '🧚',
  '🧝',
  '🧜',
  '👽',
];

/// Nine animals from the league seed list, plus dog, cat, and rabbit.
/// The default profile face 😎 stays outside this catalog.
const bilgiAvatarHayvan = <String>[
  '🦊',
  '🐼',
  '🦁',
  '🐯',
  '🐸',
  '🐙',
  '🦄',
  '🐻',
  '🐨',
  '🐶',
  '🐱',
  '🐰',
];

const bilgiAvatarGroups = <BilgiAvatarGroup>[
  BilgiAvatarGroup('Kadın', bilgiAvatarKadin),
  BilgiAvatarGroup('Erkek', bilgiAvatarErkek),
  BilgiAvatarGroup('Kahraman', bilgiAvatarKahraman),
  BilgiAvatarGroup('Hayvan', bilgiAvatarHayvan),
];

/// Opens the dark avatar sheet. Returns the chosen emoji, or null if dismissed.
Future<String?> showBilgiAvatarPicker(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: BilgiColors.card,
    elevation: 0,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _BilgiAvatarSheet(current: current),
  );
}

class _BilgiAvatarSheet extends StatefulWidget {
  const _BilgiAvatarSheet({required this.current});

  final String current;

  @override
  State<_BilgiAvatarSheet> createState() => _BilgiAvatarSheetState();
}

class _BilgiAvatarSheetState extends State<_BilgiAvatarSheet> {
  late int _group;

  @override
  void initState() {
    super.initState();
    final index = bilgiAvatarGroups.indexWhere((group) => group.emojis.contains(widget.current));
    _group = index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final group = bilgiAvatarGroups[_group];
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BilgiColors.muted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Avatar seç',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < bilgiAvatarGroups.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _groupChip(i)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final emoji in group.emojis) _emoji(emoji),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupChip(int index) {
    final selected = index == _group;
    return Material(
      color: selected ? const Color(0xFFFFC83D) : BilgiColors.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _group = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bilgiAvatarGroups[index].label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emoji(String emoji) {
    final selected = emoji == widget.current;
    return Material(
      color: selected ? BilgiColors.primary.withValues(alpha: 0.35) : BilgiColors.bg,
      shape: CircleBorder(
        side: BorderSide(color: selected ? BilgiColors.secondary : Colors.transparent, width: 2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(context, emoji),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
      ),
    );
  }
}
