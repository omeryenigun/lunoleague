import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

void main() {
  const turkishLeague = {
    'league_tab_daily': 'Günlük',
    'league_tab_general': 'Genel Lig',
    'league_tab_categories': 'Kategori Ligleri',
    'league_sort_alpha': 'Alfabetik',
    'league_sort_questions': 'Soru sayısı',
    'league_sort_players': 'Oyuncu sayısı',
    'league_join': 'Lige Katıl',
    'league_continue': 'Lige devam et',
    'league_period_week': 'Bu hafta',
    'league_period_all': 'Tüm zamanlar',
    'league_points': 'Lig Puanınız: {n}',
    'league_rank': '{n}. Sıradasınız',
  };

  test('a non-Turkish locale does not return the Turkish category-league labels', () {
    for (final entry in turkishLeague.entries) {
      expect(bilgiT('tr', entry.key), entry.value);
    }
    for (final id in ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl']) {
      for (final entry in turkishLeague.entries) {
        expect(bilgiT(id, entry.key), isNot(entry.value), reason: '$id ${entry.key}');
      }
      expect(bilgiT(id, 'league_tab_categories'), isNot('Kategori Ligleri'));
      expect(bilgiT(id, 'league_join'), isNot('Lige Katıl'));
    }
    expect(bilgiMyRankLabel(score: 117, rank: 8), 'Lig Puanınız: 117\n8. Sıradasınız');
    expect(bilgiMyRankLabel(score: 117, rank: 8, locale: 'de'), 'Ligapunkte: 117\nPlatz 8');
    expect(bilgiMyRankLabel(score: 117, rank: 0, locale: 'de'), 'Ligapunkte: 117');
    expect(
      bilgiStoredLabel({'de|category|bilim': 'Wissenschaft'}, 'de', 'category', 'bilim', 'Bilim'),
      'Wissenschaft',
    );
    expect(bilgiStoredLabel(const {}, 'de', 'category', 'bilim', 'Bilim'), 'Bilim');
  });

  test('german profile chrome is not the Turkish rank, badges, or English stat labels', () {
    expect(bilgiRankTitle('de', 'Çaylak'), 'Anfänger');
    expect(bilgiRankTitle('tr', 'Çaylak'), 'Çaylak');
    expect(bilgiRankTitle('de', 'Bilge'), 'Weise');
    expect(bilgiRankTitle('de', 'Felsefe Ustası'), 'Felsefe Ustası');
    expect(bilgiBadgeLabel('de', 'champ', 'Şampiyon'), 'Champion');
    expect(bilgiBadgeLabel('de', 'fast', 'Hızlı Parmak'), 'Schnelle Finger');
    expect(bilgiBadgeLabel('de', 'wise', 'Bilge'), 'Weise');
    expect(bilgiBadgeLabel('de', 'gem', 'Elmas'), 'Diamant');
    expect(bilgiBadgeLabel('de', 'king', 'Kral'), 'König');
    expect(bilgiT('de', 'total_games'), 'Gespielte Spiele');
    expect(bilgiT('de', 'correct_ratio'), 'Trefferquote');
    expect(bilgiT('de', 'best_score'), 'Bestpunktzahl');
    expect(bilgiT('de', 'login_streak'), 'Login-Serie');
    expect(bilgiT('de', 'badges'), 'ABZEICHEN');
    expect(bilgiT('de', 'day_one'), '{n} Tag');
    expect(bilgiT('de', 'days'), '{n} Tage');
    expect(bilgiT('de', 'total_games'), isNot('Games played'));
    expect(bilgiT('de', 'badges'), isNot('BADGES'));
    expect(bilgiT('de', 'badges'), isNot('ROZETLER'));
  });

  test('a new german guest name uses Gast and an existing name stays', () async {
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 8));
    final fresh = await server.profile();
    expect(fresh.username, startsWith('Misafir'));
    expect(fresh.localeChosen, isFalse);
    final german = await server.setLocale('de');
    expect(german.locale, 'de');
    expect(german.username, startsWith('Gast'));
    expect(german.username, isNot(contains('Misafir')));

    final again = await server.setLocale('en');
    expect(again.username, german.username);

    final named = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 8));
    await named.profile();
    final kept = await named.updateProfile(username: 'Deniz');
    expect(kept.profile!.username, 'Deniz');
    expect((await named.setLocale('de')).username, 'Deniz');

    final oldStore = MemoryKeyValueStore();
    final old = LunoBilgiServer(oldStore, clock: () => DateTime.utc(2026, 10, 8));
    final existing = await old.profile();
    final raw = await oldStore.get('users', existing.id);
    raw!['username'] = 'Misafir253122699';
    raw['locale'] = 'de';
    raw['localeChosen'] = true;
    await oldStore.put('users', existing.id, raw);
    expect((await old.setLocale('de')).username, 'Misafir253122699');
  });
}
