class UserMessages {
  static const noInternet = 'İnternet bağlantını kontrol et.';
  static const serverError = 'Bir sorun oluştu. Lütfen tekrar dene.';
  static const invalidWord = 'Bu kelime sözlükte bulunamadı.';
  static const dailyCompleted = 'Bugünkü oyunu tamamladınız.';
  static const sessionExpired = 'Oyunun süresi doldu. Lütfen tekrar başla.';
  static String tooShort(int n) => 'Lütfen en az $n harfli bir kelime gir.';
  static String tooLong(int n) => 'Lütfen en fazla $n harfli bir kelime gir.';
  static const invalidGuess = 'Lütfen geçerli bir kelime gir.';
  static const anonymousDaily =
      'Günlük ödül için giriş yap (Google, Apple veya e-posta).';
  static const insufficientCoins = 'Yeterli coin yok.';
  static const shieldsFull = 'Streak kalkanı hakkın dolu.';
  static const banned = 'Hesabın askıya alındı.';
  static const invalidEmail = 'Geçerli bir e-posta gir.';
  static const weakPassword = 'Şifre en az 6 karakter olmalı.';
  static const emailTaken = 'Bu e-posta zaten kayıtlı. Giriş yap.';
  static const nicknameTaken = 'Bu takma ad kullanılıyor.';
  static const nicknameShort = 'Takma ad en az 2 karakter olmalı.';
  static const badCredentials = 'E-posta veya şifre hatalı.';
  static const googleNotConfigured = 'Google girişi henüz ayarlı değil.';
  static const googleSignInFailed = 'Google girişi tamamlanamadı.';
  static const billingUnavailable = 'Google Play ödemesi şu an kullanılamıyor.';
  static const adUnavailable = 'Ödüllü reklam şu an kullanılamıyor.';
  static const purchaseCanceled = 'Satın alma iptal edildi.';
}
