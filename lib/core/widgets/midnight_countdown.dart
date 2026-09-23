import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/utils/date_keys.dart';

/// Counts down to the next local midnight.
class MidnightCountdown extends StatefulWidget {
  const MidnightCountdown({super.key, this.onElapsed, this.style});

  final VoidCallback? onElapsed;
  final TextStyle? style;

  @override
  State<MidnightCountdown> createState() => _MidnightCountdownState();
}

class _MidnightCountdownState extends State<MidnightCountdown> {
  Timer? _timer;
  var _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final left = DateKeys.untilMidnight();
      if (left == Duration.zero && !_fired) {
        _fired = true;
        widget.onElapsed?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateKeys.formatClock(DateKeys.untilMidnight()),
      style: widget.style ??
          const TextStyle(
            color: Color(0xFFF1C40F),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
    );
  }
}
