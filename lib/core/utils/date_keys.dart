class DateKeys {
  static String dayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String weekId([DateTime? now]) {
    final d = now ?? DateTime.now();
    final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final week = 1 + ((thursday.difference(firstThursday).inDays) / 7).floor();
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String monthId([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String seasonId([DateTime? now]) {
    final d = now ?? DateTime.now();
    final season = ((d.month - 1) ~/ 3) + 1;
    return '${d.year}-S$season';
  }

  static String yearId([DateTime? now]) => '${(now ?? DateTime.now()).year}';

  static DateTime parseDay(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static int daysBetween(String fromKey, String toKey) {
    return parseDay(toKey).difference(parseDay(fromKey)).inDays;
  }

  static Duration weekRemaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    final daysToMonday = n.weekday == DateTime.sunday ? 1 : (DateTime.monday + 7 - n.weekday);
    final end = DateTime(n.year, n.month, n.day).add(Duration(days: daysToMonday));
    return end.difference(n);
  }

  static Duration monthRemaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    final end = DateTime(n.year, n.month + 1, 1);
    return end.difference(n);
  }

  static Duration seasonRemaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    final seasonStartMonth = ((n.month - 1) ~/ 3) * 3 + 1;
    final end = DateTime(n.year, seasonStartMonth + 3, 1);
    return end.difference(n);
  }

  static Duration yearRemaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    final end = DateTime(n.year + 1, 1, 1);
    return end.difference(n);
  }

  /// Time left until the next local midnight, when the new daily opens.
  static Duration untilMidnight([DateTime? now]) {
    final n = now ?? DateTime.now();
    final next = DateTime(n.year, n.month, n.day + 1);
    final left = next.difference(n);
    return left.isNegative ? Duration.zero : left;
  }

  static String formatClock(Duration duration) {
    final total = duration.inSeconds;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total ~/ 60) % 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
