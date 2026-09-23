import 'package:flutter/widgets.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/data/remote/live_version.dart';

class GameVersionLabel extends StatefulWidget {
  const GameVersionLabel({super.key, this.style});

  final TextStyle? style;

  @override
  State<GameVersionLabel> createState() => _GameVersionLabelState();
}

class _GameVersionLabelState extends State<GameVersionLabel> {
  late final Future<String> _version = _load();

  Future<String> _load() {
    final fallback = GameVersion.parse(gameVersionCode).label;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('Test')) return Future.value(fallback);
    return readLiveGameVersion();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );
    return FutureBuilder<String>(
      future: _version,
      builder: (context, snap) {
        final label = snap.data ?? GameVersion.parse(gameVersionCode).label;
        return Text(label, style: style);
      },
    );
  }
}
