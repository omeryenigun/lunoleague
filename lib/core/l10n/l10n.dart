import 'package:flutter/foundation.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/domain/game/game_server.dart';

class L10n extends ChangeNotifier {
  String id = GameLocale.tr.id;
  bool chosen = false;

  GameLocale get locale => GameLocale.resolve(id);

  String t(String key) =>
      _tables[id]?[key] ?? _tables[GameLocale.en.id]?[key] ?? key;

  Future<void> hydrate(GameServer server) async {
    chosen = await server.hasChosenLocale();
    id = await server.activeLocale();
    notifyListeners();
  }

  void preview(String localeId) {
    id = GameLocale.resolve(localeId).id;
    notifyListeners();
  }

  Future<void> select(GameServer server, String localeId) async {
    final resolved = GameLocale.resolve(localeId).id;
    final user = await server.setLocale(resolved);
    id = user?.locale ?? resolved;
    chosen = true;
    notifyListeners();
  }
}

const _tables = <String, Map<String, String>>{
  'tr': {
    'tagline': 'Her gün bir kelime',
    'onboarding_body':
        'Her gün bir kelime bul. XP kazan, ligde yüksel, yeni kelimeler öğren.',
    'start': 'BAŞLA',
    'hint_green': 'Doğru harf, doğru yer',
    'hint_yellow': 'Harf var, yeri yanlış',
    'hint_gray': 'Harf yok',
    'choose_language': 'Oyun dilini seç',
    'choose_language_sub':
        'Sözlük, klavye ve lig bu dile özel olacak. Daha sonra ayarlardan değiştirebilirsin.',
    'continue': 'Devam',
    'home': 'Ana Sayfa',
    'league': 'Lig',
    'profile': 'Profil',
    'settings': 'Ayarlar',
    'settings_lang_section': 'Dil / Language',
    'settings_prefs': 'Tercihler',
    'settings_extra': 'Ekstra',
    'daily_play': 'GÜNLÜK OYNA',
    'daily_resume': 'DEVAM ET',
    'daily_resume_sub': 'Kaldığın yerden devam et',
    'daily_done': 'Bugün tamamlandı',
    'daily_guest': 'Bugün kelimeyi bul. Lig için kayıt gerekir.',
    'daily_reg': 'Bugün kelimeyi bul, ligde yüksel!',
    'endless': 'ENDLESS',
    'daily_mode': 'Daily',
    'endless_sub': 'Kaybedince reklamla serini koru',
    'record': 'Rekor',
    'guest': 'MİSAFİR',
    'login': 'Giriş',
    'login_or_register': 'Giriş yap / Kayıt ol',
    'profile_login_sub':
        'Google ile giriş yap veya yeni hesap oluştur. Lig, ödül ve istatistikler hesabına bağlanır.',
    'google': 'Google ile giriş',
    'apple': 'Apple ile giriş',
    'guest_continue': 'Misafir olarak devam et',
    'login_hint_ios':
        'Lig ve günlük ödül için Google veya Apple gerekir. Daily misafirde açıktır.',
    'login_hint_android':
        'Lig ve günlük ödül için Google gerekir. Daily misafirde açıktır.',
    'login_lead': 'Hızlı başla, sonra hesabını kalıcı yap.',
    'username': 'Kullanıcı adı',
    'league_need_account':
        'Lig, aylık şampiyonluk, sezon ve onur listesi için Google ile giriş yap.',
    'week': 'Hafta',
    'month': 'Ay',
    'season': 'Sezon',
    'year': 'Yıl',
    'language': 'Oyun dili',
    'difficulty': 'Zorluk (lig)',
    'difficulty_sub':
        'Bronz 5, Gümüş 6, Altın 7 harf. İstediğin zaman değiştir.',
    'sound': 'Ses',
    'haptic': 'Titreşim',
    'notifications': 'Bildirimler',
    'watch_ad': 'Reklam izle, 5 coin kazan',
    'sign_out': 'Çıkış yap',
    'guest_badge': 'MİSAFİR',
    'too_short': 'Lütfen {n} harfli bir kelime gir.',
    'daily_reward': 'Günlük ödül (gün {n})',
    'daily_reward_title': 'Günlük Ödül',
    'daily_reward_sub': 'Gün {n}',
    'daily_reward_got': 'Gün {n} ödülü alındı!',
    'weekly_title': 'HAFTALIK LİG DURUMU',
    'monthly_title': 'AYLIK LİG DURUMU',
    'season_title': 'SEZON LİG DURUMU',
    'yearly_title': 'YILLIK ONUR DURUMU',
    'weekly_left': '{d}g {h}s kaldı',
    'weekly_this': 'Bu hafta',
    'monthly_this': 'Bu ay',
    'season_this': 'Bu sezon',
    'yearly_this': 'Bu yıl',
    'weekly_target': 'Sıralama',
    'weekly_top20': 'Lig puanı',
    'period_swipe_hint': 'Diğer ligler için kaydır',
    'week_champion': 'Haftanın 1.’si',
    'league_named': '{tier} LİG',
    'loading': 'Yükleniyor...',
    'hint_letter': '💡 Harf',
    'hint_meaning': '💡 Anlam',
    'skip': 'Atla',
    'next': 'İleri',
    'tour_play': 'Oyna',
    'tour_goal_title': 'Gizli kelimeyi bul',
    'tour_goal_body':
        'Her tahmin, gizli kelimeyle aynı harf sayısında olmalı ve sözlükte bulunmalı.',
    'tour_green_title': 'Yeşil kutu',
    'tour_green_body': 'Harf doğru ve yeri de doğru.',
    'tour_yellow_title': 'Sarı kutu',
    'tour_yellow_body': 'Harf kelimede var ama yeri yanlış.',
    'tour_gray_title': 'Gri kutu',
    'tour_gray_body': 'Bu harf kelimede yok.',
    'tour_tries_title': 'Sınırlı deneme',
    'tour_tries_body':
        'Bronz ligde 6 hakkın var. Gümüş ve altın ligde kelime uzar, hak da değişir.',
    'tour_daily_title': 'Günlük ve Endless',
    'tour_daily_body':
        'Günlük kelime günde bir kez. Endless’te kaybedene kadar devam edersin.',
    'tour_leagues_title': 'Zorluk seçimi',
    'tour_leagues_body':
        'Bronz 5, Gümüş 6, Altın 7 harfli kelime. Lig bir zorluk seçicidir; ayarlardan istediğin zaman değiştirebilirsin.',
    'tour_points_title': 'Lig puanı',
    'tour_points_body':
        'Günlük oyunu kazanırsan 30–100 lig puanı alırsın (az tahmin = daha çok puan). Kaybedince +10. İpucu kullanırsan −20.',
    'tour_cycle_title': 'Haftalık sıralama',
    'tour_cycle_body':
        'Seçtiğin ligde haftalık sıralama tutulur. Üst sıralar coin ve unvan ödülü verir; lig otomatik yükselmez veya düşmez.',
    'tour_coins_title': 'Coin ve XP',
    'tour_coins_body':
        'Galibiyet, günlük ödül, reklam ve lig sıralaması coin/XP kazandırır. İpuçları coin harcar; coinler hesabında kalır.',
    'lang_switch_title': 'Oyun dilini değiştir',
    'lang_switch_body':
        'Dil değişince sözlük, klavye ve lig ortamı da değişir. Bu dildeki ligin, skorların ve istatistiklerin durur; diğer dilde kendi ligin ve skorların ayrı kalır.',
    'lang_switch_confirm': 'Değiştir',
    'lang_switch_cancel': 'Vazgeç',
    'lang_switch_tooltip': 'Dil',
    'dev_login': 'Test olarak gir',
    'dev_login_sub': 'Geçici. Google olmadan lig, ödül ve istatistikler açılır.',
    'dev_upgrade': 'Test hesabına geç',
  },
  'en': {
    'tagline': 'One word a day',
    'onboarding_body':
        'Find the daily word. Earn XP, climb the league, learn new words.',
    'start': 'START',
    'hint_green': 'Right letter, right place',
    'hint_yellow': 'Letter is in the word',
    'hint_gray': 'Letter is not in the word',
    'choose_language': 'Choose your language',
    'choose_language_sub':
        'Dictionary, keyboard and league stay in this language. You can change it later in Settings.',
    'continue': 'Continue',
    'home': 'Home',
    'league': 'League',
    'profile': 'Profile',
    'settings': 'Settings',
    'settings_lang_section': 'Language',
    'settings_prefs': 'Preferences',
    'settings_extra': 'Extras',
    'daily_play': 'PLAY DAILY',
    'daily_resume': 'CONTINUE',
    'daily_resume_sub': 'Pick up where you left off',
    'daily_done': 'Done for today',
    'daily_guest': 'Find today’s word. Sign in for league.',
    'daily_reg': 'Find today’s word and climb the league!',
    'endless': 'ENDLESS',
    'daily_mode': 'Daily',
    'endless_sub': 'Watch an ad to keep your run',
    'record': 'Best',
    'guest': 'GUEST',
    'login': 'Sign in',
    'login_or_register': 'Sign in / Register',
    'profile_login_sub':
        'Sign in with Google or create an account. League, rewards and stats stay on your account.',
    'google': 'Continue with Google',
    'apple': 'Continue with Apple',
    'guest_continue': 'Continue as guest',
    'login_hint_ios':
        'Google or Apple is required for league and daily rewards. Daily is open for guests.',
    'login_hint_android':
        'Google is required for league and daily rewards. Daily is open for guests.',
    'login_lead': 'Start quickly, lock in your account later.',
    'username': 'Username',
    'league_need_account':
        'Sign in with Google for league, monthly cup, season and honors.',
    'week': 'Week',
    'month': 'Month',
    'season': 'Season',
    'year': 'Year',
    'language': 'Game language',
    'difficulty': 'Difficulty (league)',
    'difficulty_sub':
        'Bronze 5, Silver 6, Gold 7 letters. Change anytime.',
    'sound': 'Sound',
    'haptic': 'Haptics',
    'notifications': 'Notifications',
    'watch_ad': 'Watch an ad, earn 5 coins',
    'sign_out': 'Sign out',
    'guest_badge': 'GUEST',
    'too_short': 'Enter a {n}-letter word.',
    'daily_reward': 'Daily reward (day {n})',
    'daily_reward_title': 'Daily Reward',
    'daily_reward_sub': 'Day {n}',
    'daily_reward_got': 'Day {n} reward claimed!',
    'weekly_title': 'WEEKLY LEAGUE',
    'monthly_title': 'MONTHLY LEAGUE',
    'season_title': 'SEASON LEAGUE',
    'yearly_title': 'YEARLY HONOR',
    'weekly_left': '{d}d {h}h left',
    'weekly_this': 'This week',
    'monthly_this': 'This month',
    'season_this': 'This season',
    'yearly_this': 'This year',
    'weekly_target': 'Standing',
    'weekly_top20': 'League pts',
    'period_swipe_hint': 'Swipe for other leagues',
    'week_champion': 'Week #1',
    'league_named': '{tier} LEAGUE',
    'loading': 'Loading...',
    'hint_letter': '💡 Letter',
    'hint_meaning': '💡 Meaning',
    'skip': 'Skip',
    'next': 'Next',
    'tour_play': 'Play',
    'tour_goal_title': 'Find the hidden word',
    'tour_goal_body':
        'Each guess must match the word length and exist in the dictionary.',
    'tour_green_title': 'Green tile',
    'tour_green_body': 'The letter is correct and in the right place.',
    'tour_yellow_title': 'Yellow tile',
    'tour_yellow_body': 'The letter is in the word, but in the wrong place.',
    'tour_gray_title': 'Gray tile',
    'tour_gray_body': 'This letter is not in the word.',
    'tour_tries_title': 'Limited tries',
    'tour_tries_body':
        'Bronze league gives you 6 tries. Higher leagues use longer words.',
    'tour_daily_title': 'Daily and Endless',
    'tour_daily_body':
        'Daily is once per day. Endless continues until you lose.',
    'tour_leagues_title': 'Difficulty',
    'tour_leagues_body':
        'Bronze is 5 letters, Silver 6, Gold 7. League is a difficulty picker — change it anytime in Settings.',
    'tour_points_title': 'League points',
    'tour_points_body':
        'Win the daily for 30–100 league points (fewer guesses = more). A loss still gives +10. Using a hint costs −20.',
    'tour_cycle_title': 'Weekly ranking',
    'tour_cycle_body':
        'Each difficulty keeps its own weekly board. Top ranks earn coins and titles; your league never auto-promotes or drops.',
    'tour_coins_title': 'Coins and XP',
    'tour_coins_body':
        'Wins, daily rewards, ads and league ranks grant coins/XP. Hints spend coins; coins stay on your account.',
    'lang_switch_title': 'Change game language',
    'lang_switch_body':
        'Changing language also switches the dictionary, keyboard and league. Your league, scores and stats in this language stay here; the other language keeps its own.',
    'lang_switch_confirm': 'Change',
    'lang_switch_cancel': 'Cancel',
    'lang_switch_tooltip': 'Language',
    'dev_login': 'Enter as tester',
    'dev_login_sub': 'Temporary. Unlocks league, rewards and stats without Google.',
    'dev_upgrade': 'Switch to test account',
  },
};
