/// Same floor as `bilgiMinPublishedQuestions` in bilgi_league.dart.
const bilgiPublishedCountFloor = 60;

class BilgiSubCountLine {
  const BilgiSubCountLine({
    required this.pending,
    required this.published,
    required this.publishedLow,
  });

  final int pending;
  final int published;

  /// True when the published (approved) count is under [bilgiPublishedCountFloor].
  final bool publishedLow;

  /// `Beklemede 3 • Yayınlı 12`
  String get label => 'Beklemede $pending • Yayınlı $published';
}

/// Pending is status `pending`. Published is status `approved`.
/// Draft and rejected stay out of both numbers. Only the published count is low.
BilgiSubCountLine bilgiSubCountLine({
  required int pending,
  required int published,
  int floor = bilgiPublishedCountFloor,
}) {
  return BilgiSubCountLine(
    pending: pending,
    published: published,
    publishedLow: published < floor,
  );
}
