import 'package:shelf/shelf.dart';

const privacyPolicyUrl = 'https://api-production-bf3c9.up.railway.app/privacy';

Response privacyPolicyPage(Request request) {
  return Response.ok(
    _html,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
    },
  );
}

const _html = '''
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Luno League Gizlilik Politikası</title>
  <style>
    body { font-family: Georgia, serif; max-width: 42rem; margin: 2rem auto; padding: 0 1.25rem; line-height: 1.55; color: #1a1a1a; }
    h1 { font-size: 1.7rem; }
    h2 { font-size: 1.15rem; margin-top: 1.6rem; }
    p, li { font-size: 1rem; }
  </style>
</head>
<body>
  <h1>Luno League Gizlilik Politikası</h1>
  <p>Son güncelleme: 25 Eylül 2026</p>
  <p>Luno League, Ömer Akif Yenigün tarafından sunulan bir kelime oyunudur. Bu metin, Android uygulamasının hangi bilgileri işlediğini açıklar.</p>

  <h2>Toplanan bilgiler</h2>
  <ul>
    <li>Misafir oyunda cihazınıza özel bir oyuncu kimliği ve görünen ad (örneğin Misafir2442).</li>
    <li>E-posta ile kayıtta ad, e-posta adresi ve parolanın güvenli özeti. Parolanın kendisi saklanmaz.</li>
    <li>Google ile girişte Google’ın verdiği hesap kimliği, ad ve e-posta.</li>
    <li>İsteğe bağlı profil fotoğrafı.</li>
    <li>Oyun verisi: skor, süre, tahminler, coin, seri, lig puanı ve başarımlar.</li>
    <li>Google Play satın almasında ürün kimliği ve satın alma jetonu. Ödeme kartı bilgisi bize gelmez; ödemeyi Google Play alır.</li>
    <li>Ödüllü reklam izlendiğinde Google AdMob’un gönderdiği doğrulama kaydı (reklam birimi, işlem kimliği, oyuncu kimliği). Reklam sunumu için Google reklam kimliği ve cihaz bilgisi işleyebilir.</li>
  </ul>

  <h2>Bilgiler ne için kullanılır</h2>
  <p>Hesabı açmak, oyunu kaydetmek, coin ve satın almayı doğrulamak, sıralama tutmak ve izlenen ödüllü reklamın karşılığını bir kez yazmak için. Günlük hatırlatma izni verirseniz bildirim yalnızca cihazınızda kurulur; bu izin sunucuya bir bildirim adresi göndermez.</p>

  <h2>Kimlerle paylaşılır</h2>
  <p>Veriyi satmayız. Google hesap girişi, Google Play ödemesi ve Google AdMob reklamları bu hizmetlerin kendi şartlarına göre işlenir. Oyun sunucusu Railway üzerinde çalışır.</p>

  <h2>Saklama</h2>
  <p>Hesap ve oyun kaydı, hesabı silmemizi isteyene kadar veya oyun hizmeti sürdüğü sürece tutulur. Aynı reklam işlemi ikinci kez coin yazmaz.</p>

  <h2>Çocuklar</h2>
  <p>Uygulama 13 yaşın altındaki çocuklara yönelik değildir.</p>

  <h2>Haklarınız</h2>
  <p>Hesabınızdaki bilgilere erişmek, düzeltilmesini veya silinmesini istemek için aşağıdaki adrese yazın.</p>

  <h2>İletişim</h2>
  <p>Ömer Akif Yenigün<br>omeryenigun@gmail.com</p>

  <h2>Privacy Policy (English)</h2>
  <p>Last updated: 25 September 2026. Luno League is a word game operated by Ömer Akif Yenigün.</p>
  <p>We store a guest player id and display name; if you register, your name, email, and a password hash; if you use Google Sign-In, the account id, name, and email Google provides; an optional profile photo; gameplay such as score, time, guesses, coins, streak, and league points; and, for a Play purchase, the product id and purchase token. Card data stays with Google Play. When you finish a rewarded ad, Google AdMob sends a signed callback with the ad unit, transaction id, and player id. AdMob may process an advertising id and device data to show the ad.</p>
  <p>We use this data to run the account, save games, verify coins and purchases, keep rankings, and grant a reward once per ad. We do not sell personal data. Google handles sign-in, Play billing, and ads under its own terms. The game server is hosted on Railway. Data is kept while the account exists or until you ask us to delete it. The app is not directed at children under 13. To access, correct, or delete your data, email omeryenigun@gmail.com.</p>
</body>
</html>
''';
