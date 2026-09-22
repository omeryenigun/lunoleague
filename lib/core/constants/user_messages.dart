class UserMessages {
  static const noInternet = 'İnternet bağlantını kontrol et.';
  static const serverError = 'Bir sorun oluştu. Lütfen tekrar dene.';
  static const invalidWord = 'Bu kelime sözlükte bulunamadı.';
  static const dailyCompleted =
      'Bugünkü kelimeyi zaten oynadın. Yarın tekrar gel!';
  static const sessionExpired = 'Oyunun süresi doldu. Lütfen tekrar başla.';
  static String tooShort(int n) => 'Lütfen en az $n harfli bir kelime gir.';
  static String tooLong(int n) => 'Lütfen en fazla $n harfli bir kelime gir.';
  static const invalidGuess = 'Lütfen geçerli bir kelime gir.';
  static const anonymousDaily =
      'Günlük ödül için Google veya Apple ile giriş yap.';
  static const insufficientCoins = 'Yeterli coin yok.';
  static const banned = 'Hesabın askıya alındı.';
}
