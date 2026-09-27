import 'package:shelf/shelf.dart';

const privacyPolicyUrl = 'https://onyapp.app/privacy';

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
  <title>Onyapp Gizlilik Politikası</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://onyapp.app/css/style.css?v=8">
  <style>
    .legal { max-width: 1180px; margin: 0 auto; padding: 48px 24px 80px; }
    .legal h1 { font-size: clamp(1.8rem, 3vw, 2.4rem); letter-spacing: -.03em; margin-bottom: 12px; }
    .legal h2 { font-size: 1.25rem; margin: 1.8rem 0 .6rem; letter-spacing: -.02em; }
    .legal h3 { font-size: 1.05rem; margin: 1.3rem 0 .4rem; }
    .legal h4 { font-size: 1rem; margin: 1.1rem 0 .4rem; }
    .legal p, .legal li { color: var(--muted); font-size: .98rem; }
    .legal strong { color: var(--text); }
    .legal a { color: var(--cyan); }
    .legal hr { border: 0; border-top: 1px solid var(--line); margin: 1.6rem 0; }
    .legal ul { margin: .4rem 0 1rem 1.2rem; }
    .legal table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
    .legal th, .legal td { border: 1px solid var(--line); padding: .5rem .65rem; text-align: left; vertical-align: top; color: var(--muted); }
    .legal th { color: var(--text); }
    html.lang-en [data-legal="tr"] { display: none; }
    html:not(.lang-en) [data-legal="en"] { display: none; }
  </style>
  <script>
    try {
      if (localStorage.getItem('ony-lang') === 'en') document.documentElement.classList.add('lang-en');
    } catch (e) {}
  </script>
</head>
<body>
<header>
  <nav class="nav">
    <a href="/" class="logo"><span class="logo-mark" aria-hidden="true">🎮</span><span><b>Onyapp</b></span></a>
    <div class="nav-end">
      <div class="menu">
        <a href="/" data-i18n="navHome">Ana Sayfa</a>
        <a href="/oyunlar" data-i18n="navGames">Oyunlar</a>
        <a href="/hakkimizda" data-i18n="navAbout">Hakkımızda</a>
        <a href="/iletisim" data-i18n="navContact">İletişim</a>
      </div>
      <div class="langs" role="group" aria-label="Language">
        <button type="button" data-lang="tr">TR</button>
        <button type="button" data-lang="en">EN</button>
      </div>
      <button class="nav-toggle" type="button" aria-label="Menü">☰</button>
    </div>
  </nav>
</header>
<main class="legal">
<article class="legal-lang" lang="tr" data-legal="tr">
  <h1>Onyapp Gizlilik Politikası</h1>
  <p><strong>Son güncelleme: 27 Eylül 2026</strong></p>
  <p>Bu Gizlilik Politikası, <strong>Onyapp</strong> mobil uygulaması ("Onyapp", "Uygulama", "biz", "bize" veya "bizim") aracılığıyla gerçekleştirilen kişisel veri işleme faaliyetleri hakkında kullanıcıları bilgilendirmek amacıyla hazırlanmıştır.</p>
  <p>Bu politika; Türkiye'de 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK"), Avrupa Birliği Genel Veri Koruma Tüzüğü ("GDPR") ve uygulanabildiği ölçüde Birleşik Krallık veri koruma mevzuatı ile Amerika Birleşik Devletleri'ndeki uygulanabilir federal ve eyalet düzeyindeki gizlilik mevzuatı kapsamında kullanıcıların bilgilendirilmesini amaçlar.</p>
  <p>Apple App Store ve Google Play gibi uygulama mağazalarının gizlilik ve kullanıcı verileri politikaları ayrıca uygulanabilir.</p>
  <hr>
  <h2>1. Veri Sorumlusu / Veri İşleyen</h2>
  <p>Onyapp kapsamında işlenen kişisel veriler bakımından, ilgili işleme faaliyetine göre veri sorumlusu:</p>
  <p><strong>[Şirket Unvanı]</strong><br>
  <strong>Adres:</strong> [Şirket Adresi]<br>
  <strong>E-posta:</strong> [Gizlilik / KVKK E-posta Adresi]<br>
  <strong>Web:</strong> [Web Sitesi]</p>
  <p>olarak hareket eder.</p>
  <p>Bazı kişisel veriler ise uygulamanın çalışması için kullanılan üçüncü taraf hizmet sağlayıcıları tarafından kendi hizmetleri kapsamında bağımsız olarak veya bizim adımıza işlenebilir.</p>
  <p>Üçüncü tarafların kendi veri işleme faaliyetleri bakımından ilgili sağlayıcının kendi gizlilik politikaları ve şartları ayrıca uygulanabilir.</p>
  <hr>
  <h2>2. Hangi Bilgileri İşliyoruz?</h2>
  <p>Onyapp'ta işlenen bilgiler, uygulamanın hangi özelliklerinin kullanıldığına göre değişebilir.</p>
  <h3>2.1. Misafir Kullanıcı Bilgileri</h3>
  <p>Onyapp'ın misafir kullanım özelliği kullanıldığında:</p>
  <ul>
    <li>Uygulama tarafından oluşturulan oyuncu/kullanıcı kimliği,</li>
    <li>Otomatik oluşturulan görünen ad,</li>
    <li>Oyun ilerlemesi,</li>
    <li>Skorlar,</li>
    <li>Lig puanı,</li>
    <li>Başarımlar,</li>
    <li>Coin bakiyesi,</li>
    <li>Seri (streak) bilgileri,</li>
    <li>Oyun süresi ve oyun içi performans bilgileri</li>
  </ul>
  <p>işlenebilir.</p>
  <p>Misafir kullanımında kullanıcıdan zorunlu olarak ad, soyad veya e-posta adresi istenmez.</p>
  <p>Ancak cihaz, uygulama ve teknik bağlantı bilgileri üçüncü taraf SDK'lar veya sunucu altyapısı tarafından kendi hizmetlerinin çalışması ve güvenliği kapsamında işlenebilir.</p>
  <hr>
  <h3>2.2. E-posta ile Hesap Oluşturma</h3>
  <p>E-posta ile hesap oluşturulması halinde:</p>
  <ul>
    <li>Ad,</li>
    <li>E-posta adresi,</li>
    <li>Kullanıcı hesabı kimliği,</li>
    <li>Parolanın güvenli kriptografik özeti (hash),</li>
    <li>Hesap ve oyun ilerleme bilgileri</li>
  </ul>
  <p>işlenebilir.</p>
  <p>Parolanın kendisi düz metin olarak saklanmaz.</p>
  <p>Parolanın güvenli biçimde saklanması amacıyla kullanılan kriptografik yöntemler ve teknik güvenlik tedbirleri zaman içinde güncellenebilir.</p>
  <hr>
  <h3>2.3. Google ile Giriş</h3>
  <p>Google ile giriş özelliğinin kullanılması halinde Google tarafından uygulamaya sağlanan bilgiler işlenebilir.</p>
  <p>Bunlar:</p>
  <ul>
    <li>Google hesap kimliği,</li>
    <li>Ad,</li>
    <li>E-posta adresi,</li>
    <li>Google hesabına ilişkin teknik kimlik bilgileri</li>
  </ul>
  <p>olabilir.</p>
  <p>Google hesabının parolası Onyapp tarafından alınmaz veya saklanmaz.</p>
  <p>Google hesabıyla giriş yapılması halinde Google'ın kendi gizlilik politikası ve hizmet şartları da uygulanır.</p>
  <hr>
  <h3>2.4. Profil Fotoğrafı</h3>
  <p>Kullanıcı tarafından isteğe bağlı olarak profil fotoğrafı yüklenebilir.</p>
  <p>Profil fotoğrafı:</p>
  <ul>
    <li>Kullanıcı profilinde gösterilmek,</li>
    <li>Kullanıcı hesabının kişiselleştirilmesini sağlamak,</li>
    <li>Oyun içindeki profil görünümünü oluşturmak</li>
  </ul>
  <p>amacıyla işlenir.</p>
  <p>Profil fotoğrafı yüklemek zorunlu değildir.</p>
  <p>Kullanıcı profil fotoğrafını uygulamanın ilgili özellikleri üzerinden kaldırabilir veya değiştirebilir.</p>
  <p>Profil fotoğrafı, kullanıcı tarafından açıkça yüklenmediği sürece Onyapp tarafından kamera veya fotoğraf galerisi üzerinden kendiliğinden alınmaz.</p>
  <hr>
  <h2>3. Oyun ve Kullanım Verileri</h2>
  <p>Onyapp'ın oyun özelliklerinin çalışması için aşağıdaki bilgiler işlenebilir:</p>
  <ul>
    <li>Skor,</li>
    <li>Oyun süresi,</li>
    <li>Tahminler,</li>
    <li>Doğru ve yanlış cevaplar,</li>
    <li>Lig puanı,</li>
    <li>Lig sıralaması,</li>
    <li>Seri (streak),</li>
    <li>Başarımlar,</li>
    <li>Oyun seviyesi,</li>
    <li>Oyun içi ilerleme,</li>
    <li>Coin bakiyesi,</li>
    <li>Kullanılan veya kazanılan oyun içi ödüller,</li>
    <li>Oyun oturumları,</li>
    <li>Oyun sonuçları,</li>
    <li>Kullanıcı adı ve profil bilgileri.</li>
  </ul>
  <p>Bu bilgiler oyun deneyiminin sağlanması, ilerlemenin kaydedilmesi, sıralamaların oluşturulması, ödüllerin verilmesi ve hileli veya kötüye kullanımlı işlemlerin tespit edilmesi amacıyla işlenebilir.</p>
  <hr>
  <h2>4. Satın Alma ve Ödeme Bilgileri</h2>
  <p>Onyapp içerisinde Google Play Billing veya Apple'ın ilgili uygulama içi satın alma sistemi üzerinden satın alma yapılması halinde ödeme işlemi ilgili uygulama mağazası tarafından gerçekleştirilir.</p>
  <p>Onyapp doğrudan:</p>
  <ul>
    <li>Kredi kartı numarası,</li>
    <li>Banka kartı numarası,</li>
    <li>CVV/CVC,</li>
    <li>Kart şifresi,</li>
    <li>İnternet bankacılığı bilgileri</li>
  </ul>
  <p>gibi ödeme bilgilerini almaz veya saklamaz.</p>
  <p>Satın alma işleminin doğrulanması amacıyla aşağıdaki bilgiler işlenebilir:</p>
  <ul>
    <li>Ürün kimliği,</li>
    <li>Satın alma işlemi kimliği,</li>
    <li>Satın alma jetonu / purchase token,</li>
    <li>İşlem tarihi,</li>
    <li>İşlem durumu,</li>
    <li>İlgili kullanıcı veya hesap kimliği,</li>
    <li>Satın alınan ürünün türü ve durumu.</li>
  </ul>
  <p>Google Play satın almalarında Google Play'in, Apple satın almalarında ise Apple'ın ilgili ödeme ve gizlilik politikaları uygulanır.</p>
  <hr>
  <h2>5. Ödüllü Reklamlar ve Reklam Teknolojileri</h2>
  <p>Onyapp, uygulama içerisinde ödüllü reklamlar sunmak için Google AdMob gibi üçüncü taraf reklam hizmetlerinden yararlanabilir.</p>
  <p>Ödüllü reklam görüntülendiğinde, ödülün doğru kullanıcıya yalnızca bir kez verilmesi ve aynı reklam işleminin tekrar kullanılarak kötüye kullanılmasının önlenmesi amacıyla uygulama veya sunucu tarafında aşağıdaki bilgiler işlenebilir:</p>
  <ul>
    <li>Reklam birimi bilgisi,</li>
    <li>Reklam işlemi / doğrulama kimliği,</li>
    <li>Kullanıcı veya oyuncu kimliği,</li>
    <li>Ödül bilgisi,</li>
    <li>İşlem zamanı,</li>
    <li>İşlemin doğrulama durumu.</li>
  </ul>
  <p>Google AdMob ve ilgili reklam SDK'ları, kullanılan yapılandırmaya, cihaza, işletim sistemine ve kullanıcının bulunduğu bölgeye bağlı olarak reklam kimliği, cihaz bilgileri, IP adresi, uygulama bilgileri ve reklam etkileşimleri gibi bilgileri kendi hizmetleri kapsamında işleyebilir.</p>
  <p>Bu işlemler Google'ın kendi gizlilik politikalarına ve ilgili bölgesel gerekliliklere tabidir.</p>
  <p>Kişiselleştirilmiş reklamcılık veya uygulamalar ve web siteleri arasındaki izleme için gerekli izinlerin bulunduğu platformlarda, kullanıcıya platformun gerektirdiği seçim ve izin mekanizmaları sunulabilir.</p>
  <p>Apple cihazlarında, başka şirketlere ait uygulama ve web siteleri arasında izleme yapılmasını gerektiren durumlarda Apple'ın App Tracking Transparency ("ATT") sistemi ve ilgili kullanıcı izinleri uygulanır.</p>
  <p>Apple, App Store'daki gizlilik beyanlarında uygulamanın ve entegre edilen üçüncü taraf SDK'ların veri uygulamalarının doğru şekilde açıklanmasını ister.</p>
  <hr>
  <h2>6. Bildirimler</h2>
  <p>Kullanıcı günlük hatırlatma veya benzeri bildirimlere izin verirse Onyapp cihaz üzerinde bildirim oluşturabilir.</p>
  <p>Bildirim izni:</p>
  <ul>
    <li>Cihaz ayarlarından kapatılabilir,</li>
    <li>Uygulama ayarları üzerinden yönetilebilir,</li>
    <li>Kullanıcı tarafından istenmediği sürece etkinleştirilmez.</li>
  </ul>
  <p>Bildirim özelliğinin mevcut teknik uygulamasında bildirim adresi veya push token sunucuda saklanmıyorsa, yalnızca cihaz üzerinde oluşturulan yerel bildirimler kullanılır.</p>
  <p>Teknik mimarinin ileride push bildirim sistemine dönüştürülmesi halinde ilgili veri işleme faaliyetleri bu politika güncellenerek açıklanacaktır.</p>
  <hr>
  <h2>7. Teknik Veriler ve Günlük Kayıtları</h2>
  <p>Uygulamanın güvenliği, hata tespiti, performansının iyileştirilmesi ve kötüye kullanımın önlenmesi amacıyla uygulama veya sunucu altyapısı kapsamında aşağıdaki teknik bilgiler işlenebilir:</p>
  <ul>
    <li>IP adresi,</li>
    <li>Tarih ve saat bilgisi,</li>
    <li>Uygulama sürümü,</li>
    <li>İşletim sistemi,</li>
    <li>Cihaz türü,</li>
    <li>Dil ve bölge ayarları,</li>
    <li>Ağ bağlantısı ile ilgili teknik bilgiler,</li>
    <li>Hata kayıtları,</li>
    <li>Sunucu günlükleri,</li>
    <li>Oturum ve güvenlik kayıtları,</li>
    <li>Kullanıcı veya cihazla ilişkilendirilebilen teknik tanımlayıcılar.</li>
  </ul>
  <p>Bu bilgilerin tamamı her kullanıcı için veya her platformda aynı şekilde toplanmayabilir.</p>
  <p>Teknik kayıtlar, güvenlik ve hizmetin işletilmesi için gerekli olduğu sürece saklanır ve daha uzun saklanmasını gerektiren hukuki bir neden bulunmadığı sürece makul süre sonunda silinir veya anonimleştirilir.</p>
  <hr>
  <h2>8. Bilgilerin Kaynakları</h2>
  <p>Kişisel veriler aşağıdaki kaynaklardan elde edilebilir:</p>
  <ol>
    <li>Kullanıcının doğrudan sağladığı bilgiler,</li>
    <li>Google hesabı üzerinden sağlanan bilgiler,</li>
    <li>Google Play veya Apple'ın satın alma sistemlerinden gelen doğrulama bilgileri,</li>
    <li>Kullanıcının uygulamayı kullanması sırasında otomatik olarak oluşan teknik bilgiler,</li>
    <li>Reklam SDK'ları ve diğer entegre üçüncü taraf hizmetler,</li>
    <li>Onyapp sunucularında oluşan oyun ve güvenlik kayıtları.</li>
  </ol>
  <hr>
  <h2>9. Kişisel Verileri Neden Kullanıyoruz?</h2>
  <p>Kişisel veriler aşağıdaki amaçlarla işlenebilir:</p>
  <ul>
    <li>Kullanıcı hesabı oluşturmak ve yönetmek,</li>
    <li>Kullanıcının kimliğini doğrulamak,</li>
    <li>Oyuncu profilini oluşturmak,</li>
    <li>Oyun ilerlemesini kaydetmek,</li>
    <li>Oyun ilerlemesini farklı oturumlarda geri yüklemek,</li>
    <li>Skorları hesaplamak,</li>
    <li>Ligleri ve sıralamaları oluşturmak,</li>
    <li>Başarımları kaydetmek,</li>
    <li>Coin bakiyesini yönetmek,</li>
    <li>Oyun içi ödülleri vermek,</li>
    <li>Satın almaları doğrulamak,</li>
    <li>Ödüllü reklamları doğrulamak,</li>
    <li>Aynı reklam işleminin birden fazla kez ödüllendirilmesini önlemek,</li>
    <li>Dolandırıcılık, hile, kötüye kullanım ve yetkisiz erişimi önlemek,</li>
    <li>Uygulamanın güvenliğini sağlamak,</li>
    <li>Hataları tespit etmek,</li>
    <li>Uygulamanın performansını ve kararlılığını geliştirmek,</li>
    <li>Kullanıcının talep ettiği bildirimleri göstermek,</li>
    <li>Yasal yükümlülükleri yerine getirmek,</li>
    <li>Kullanıcı taleplerini ve başvurularını cevaplamak,</li>
    <li>Hukuki haklarımızı kullanmak veya savunmak.</li>
  </ul>
  <p>Kişisel veriler, bu politikada açıklanan amaçlarla bağdaşmayan yeni bir amaç için kullanılacaksa, uygulanabilir mevzuatın gerektirdiği durumlarda kullanıcı ayrıca bilgilendirilir veya gerekli izin alınır.</p>
  <hr>
  <h2>10. İşleme Hukuki Sebepleri</h2>
  <h3>10.1. KVKK</h3>
  <p>Türkiye'deki kullanıcılar bakımından kişisel veriler, ilgili işleme faaliyetinin niteliğine göre KVKK'da öngörülen hukuki işleme şartlarından biri veya birkaçı kapsamında işlenebilir.</p>
  <p>Bunlar arasında:</p>
  <ul>
    <li>Kanunda açıkça öngörülmesi,</li>
    <li>Bir sözleşmenin kurulması veya ifası için gerekli olması,</li>
    <li>Veri sorumlusunun hukuki yükümlülüğünün yerine getirilmesi,</li>
    <li>Bir hakkın tesisi, kullanılması veya korunması için veri işlemenin zorunlu olması,</li>
    <li>Veri sorumlusunun meşru menfaati,</li>
    <li>İlgili kişinin açık rızası</li>
  </ul>
  <p>gibi hukuki sebepler bulunabilir.</p>
  <p>KVKK kapsamında açık rıza, kişisel veri işlemenin her durumda zorunlu şartı değildir. İlgili işleme faaliyetine uygun hukuki sebep ayrıca değerlendirilir.</p>
  <p>KVKK kapsamında kullanıcıya veri sorumlusunun kimliği, veri işleme amaçları, aktarım yapılabilecek kişi veya gruplar, veri toplama yöntemi ve hukuki sebebi ile ilgili kişinin hakları hakkında aydınlatma yapılır.</p>
  <hr>
  <h3>10.2. GDPR / Avrupa Ekonomik Alanı</h3>
  <p>GDPR'ın uygulanabildiği durumlarda kişisel veriler, işleme faaliyetinin niteliğine göre aşağıdaki hukuki sebeplerden biri kapsamında işlenebilir:</p>
  <ul>
    <li>Kullanıcının sözleşmesinin kurulması veya ifası,</li>
    <li>Hukuki yükümlülüğün yerine getirilmesi,</li>
    <li>Meşru menfaat,</li>
    <li>Kullanıcının açık rızası,</li>
    <li>Kullanıcının veya başka bir kişinin hayati menfaatlerinin korunması gibi GDPR kapsamında tanınan diğer hukuki sebepler.</li>
  </ul>
  <p>Kullanıcının rızasına dayanan işlemlerde kullanıcı rızasını istediği zaman geri çekebilir. Rızanın geri çekilmesi, geri çekilmeden önce rızaya dayalı olarak gerçekleştirilen işlemenin hukuka uygunluğunu etkilemez.</p>
  <p>GDPR kapsamında kişisel verilerin işlenmesi; adalet, şeffaflık, amaçla sınırlılık, veri minimizasyonu, doğruluk, saklama süresinin sınırlandırılması ve güvenlik ilkelerine uygun şekilde yürütülür.</p>
  <hr>
  <h2>11. Kişisel Verilerin Paylaşılması</h2>
  <p>Kişisel veriler satılmaz veya kiralanmaz.</p>
  <p>Bununla birlikte, hizmetin çalışması için gerekli olduğu ölçüde aşağıdaki kategorilerdeki taraflarla veri paylaşılabilir:</p>
  <h3>Google</h3>
  <ul>
    <li>Google Sign-In,</li>
    <li>Google Play Billing,</li>
    <li>Google AdMob,</li>
    <li>İlgili Google SDK'ları ve hizmetleri.</li>
  </ul>
  <h3>Apple</h3>
  <p>Apple cihazlarında kullanılan App Store ve uygulama içi satın alma hizmetleri kapsamında ilgili işlem doğrulama bilgileri Apple'ın sistemleri üzerinden işlenebilir.</p>
  <h3>Railway</h3>
  <p>Onyapp'ın uygulama/sunucu altyapısının barındırılması amacıyla Railway altyapısı kullanılmaktadır.</p>
  <h3>Teknik hizmet sağlayıcıları</h3>
  <p>İleride uygulamanın çalışması için gerekli başka altyapı, güvenlik, analitik, hata izleme veya teknik hizmet sağlayıcılarının kullanılması halinde, ilgili hizmetin veri işleme kapsamına göre bu sağlayıcılar kişisel verilere erişebilir.</p>
  <p>Bu tür sağlayıcılar mümkün olduğu ölçüde yalnızca kendilerine verilen hizmetin yerine getirilmesi için gerekli verilere erişir.</p>
  <p>Üçüncü taraf sağlayıcıların kendi bağımsız veri işleme faaliyetleri bakımından ilgili sağlayıcının kendi gizlilik politikası da uygulanır.</p>
  <hr>
  <h2>12. Üçüncü Taraf Hizmetler</h2>
  <p>Onyapp'ın kullandığı veya kullanabileceği başlıca üçüncü taraf hizmet kategorileri şunlardır:</p>
  <table>
    <thead>
      <tr><th>Hizmet</th><th>Kullanım amacı</th></tr>
    </thead>
    <tbody>
      <tr><td>Google Sign-In</td><td>Hesap girişi</td></tr>
      <tr><td>Google Play Billing</td><td>Uygulama içi satın alma</td></tr>
      <tr><td>Google AdMob</td><td>Ödüllü reklam</td></tr>
      <tr><td>Apple App Store / StoreKit</td><td>iOS uygulama dağıtımı ve uygulama içi satın alma</td></tr>
      <tr><td>Railway</td><td>Sunucu ve uygulama altyapısı</td></tr>
    </tbody>
  </table>
  <p>Bu hizmetlerin kendi veri işleme faaliyetleri bakımından kendi gizlilik politikaları geçerli olabilir.</p>
  <p>Onyapp, üçüncü taraf hizmet sağlayıcıların kendi bağımsız veri işleme faaliyetlerini kontrol etmez. Bununla birlikte, Onyapp tarafından veri işleyen olarak kullanılan hizmet sağlayıcılarla ilgili olarak uygulanabilir mevzuat kapsamında gerekli sözleşmesel ve teknik tedbirler alınmaya çalışılır.</p>
  <hr>
  <h2>13. Uluslararası Veri Aktarımı</h2>
  <p>Onyapp'ın kullandığı bazı hizmet sağlayıcıların altyapıları Türkiye, Avrupa Birliği veya Avrupa Ekonomik Alanı dışında bulunabilir.</p>
  <p>Bu nedenle kişisel veriler, hizmetin teknik olarak gerekli olması halinde farklı ülkelerde bulunan sunuculara aktarılabilir veya bu ülkelerde işlenebilir.</p>
  <p>Türkiye'deki kullanıcılar bakımından yurt dışına kişisel veri aktarımı, KVKK'nın yurt dışına aktarım hükümlerine ve uygulanabilir ikincil düzenlemelere uygun şekilde gerçekleştirilir.</p>
  <p>KVKK kapsamında standart sözleşmeler, bağlayıcı şirket kuralları veya mevzuatta öngörülen diğer uygun güvenceler ilgili aktarımın hukuki yapısına göre kullanılabilir. KVKK, 2024 değişiklikleri sonrasında standart sözleşmeleri yurt dışına aktarım için uygun güvence yöntemlerinden biri olarak düzenlemiştir.</p>
  <p>GDPR'ın uygulandığı durumlarda Avrupa Ekonomik Alanı dışındaki ülkelere veri aktarımı, GDPR'ın uluslararası aktarım hükümlerine uygun mekanizmalar kullanılarak gerçekleştirilebilir. Bunlar arasında yeterlilik kararı veya uygulanabilir durumda Avrupa Komisyonu tarafından kabul edilen Standart Sözleşme Maddeleri (SCC) bulunabilir.</p>
  <hr>
  <h2>14. Verilerin Saklanma Süresi</h2>
  <p>Kişisel veriler, yalnızca işlenme amacı için gerekli olduğu veya hukuki bir yükümlülüğün gerektirdiği süre boyunca saklanır.</p>
  <p>Saklama süresi belirlenirken:</p>
  <ul>
    <li>Hesabın aktif olup olmadığı,</li>
    <li>Oyunun hizmet süresi,</li>
    <li>Satın alma doğrulama gereklilikleri,</li>
    <li>Muhasebe ve vergi yükümlülükleri,</li>
    <li>Güvenlik ve kötüye kullanımın önlenmesi,</li>
    <li>Hukuki uyuşmazlıkların çözümü,</li>
    <li>Yasal saklama yükümlülükleri</li>
  </ul>
  <p>dikkate alınır.</p>
  <p>Genel olarak:</p>
  <p><strong>Hesap verileri:</strong> Hesap aktif olduğu sürece veya kullanıcı silme talebinde bulunana kadar.</p>
  <p><strong>Oyun verileri:</strong> Hesapla ilişkili hizmetin sağlanması için gerekli olduğu sürece.</p>
  <p><strong>Misafir verileri:</strong> Misafir hesabının ve ilgili oyun hizmetinin sağlanması için gerekli olduğu sürece.</p>
  <p><strong>Satın alma kayıtları:</strong> Satın alma doğrulaması, muhasebe, vergi ve hukuki yükümlülükler için gerekli olduğu sürece.</p>
  <p><strong>Reklam ödül doğrulama kayıtları:</strong> Ödülün yalnızca bir kez verilmesini ve kötüye kullanımın önlenmesini sağlamak için gerekli olduğu sürece.</p>
  <p><strong>Güvenlik ve sunucu kayıtları:</strong> Güvenlik, hata tespiti ve kötüye kullanımın önlenmesi için gerekli makul süre boyunca.</p>
  <p>Saklama süresinin sona ermesiyle veriler silinir, anonimleştirilir veya teknik olarak artık kişiyi belirlemeyecek hale getirilir.</p>
  <hr>
  <h2>15. Hesap ve Veri Silme</h2>
  <p>Kullanıcı, hesabının ve hesabıyla ilişkili kişisel verilerin silinmesini talep edebilir.</p>
  <p>Silme talebi:</p>
  <p><strong>E-posta:</strong> [Gizlilik / Veri Silme E-posta Adresi]</p>
  <p>üzerinden iletilebilir.</p>
  <p>Talep doğrulandıktan sonra, yasal olarak saklanması gereken bilgiler hariç olmak üzere ilgili hesap ve kişisel veriler uygulanabilir mevzuatın öngördüğü süre içinde silinir veya anonimleştirilir.</p>
  <p>Bazı bilgilerin silinmesi, yasal yükümlülükler, dolandırıcılık veya güvenlik incelemeleri, uyuşmazlıkların çözümü veya hukuki hakların kullanılması gibi nedenlerle hemen mümkün olmayabilir.</p>
  <p>Google Play, hesap oluşturmaya izin veren uygulamalar için kullanıcıların hesap ve ilişkili verilerini silmelerine yönelik bir yöntem sunulmasını gerektirir. Bu nedenle Onyapp'ın hesap silme mekanizması uygulama ve/veya uygun bir web kanalı üzerinden erişilebilir olmalıdır.</p>
  <hr>
  <h2>16. Kullanıcı Hakları</h2>
  <p>Uygulanabilir mevzuata bağlı olarak kullanıcılar aşağıdaki haklara sahip olabilir.</p>
  <h3>16.1. KVKK kapsamındaki haklar</h3>
  <p>Kullanıcılar KVKK kapsamında:</p>
  <ul>
    <li>Kişisel verilerinin işlenip işlenmediğini öğrenme,</li>
    <li>İşlenmişse buna ilişkin bilgi talep etme,</li>
    <li>İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,</li>
    <li>Yurt içinde veya yurt dışında kişisel verilerin aktarıldığı üçüncü kişileri bilme,</li>
    <li>Eksik veya yanlış işlenmiş verilerin düzeltilmesini isteme,</li>
    <li>Kanunda öngörülen şartlar kapsamında kişisel verilerin silinmesini veya yok edilmesini isteme,</li>
    <li>Düzeltme, silme veya yok etme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme,</li>
    <li>İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi sonucunda aleyhe bir sonucun ortaya çıkmasına itiraz etme,</li>
    <li>Kanuna aykırı veri işlenmesi nedeniyle zarara uğranması halinde zararın giderilmesini talep etme</li>
  </ul>
  <p>haklarına sahip olabilir.</p>
  <hr>
  <h2>17. GDPR Kapsamındaki Haklar</h2>
  <p>GDPR'ın uygulanabildiği durumlarda kullanıcılar, koşullara bağlı olarak:</p>
  <ul>
    <li>Kişisel verilere erişim,</li>
    <li>Yanlış kişisel verilerin düzeltilmesi,</li>
    <li>Kişisel verilerin silinmesi,</li>
    <li>İşlemenin kısıtlanması,</li>
    <li>Veri taşınabilirliği,</li>
    <li>İşlemeye itiraz,</li>
    <li>Rızaya dayalı işlemede rızayı geri çekme,</li>
    <li>Otomatik karar verme ve profil oluşturmaya ilişkin haklar</li>
  </ul>
  <p>gibi haklara sahip olabilir.</p>
  <p>Bu hakların bazıları mutlak değildir ve GDPR'da öngörülen istisnalara tabi olabilir.</p>
  <p>Örneğin yasal yükümlülük nedeniyle saklanması gereken bir verinin kullanıcı tarafından talep edilmesi üzerine hemen silinmesi mümkün olmayabilir.</p>
  <hr>
  <h2>18. Birleşik Krallık Kullanıcıları</h2>
  <p>Birleşik Krallık veri koruma mevzuatının uygulanabildiği durumlarda kullanıcıların ilgili mevzuat kapsamında erişim, düzeltme, silme, işlemeyi kısıtlama, veri taşınabilirliği, itiraz ve diğer uygulanabilir hakları bulunabilir.</p>
  <p>Birleşik Krallık kullanıcıları, uygulanabilir olması halinde Information Commissioner's Office ("ICO") kurumuna başvurma hakkına da sahip olabilir.</p>
  <hr>
  <h2>19. Amerika Birleşik Devletleri Kullanıcıları</h2>
  <p>Amerika Birleşik Devletleri'nde gizlilik hakları eyalete göre değişebilir.</p>
  <p>Uygulanabilir olduğu ölçüde California, Virginia, Colorado ve diğer eyaletlerin tüketici gizliliği mevzuatı kapsamında kullanıcıların aşağıdaki haklardan bazılarına sahip olması mümkündür:</p>
  <ul>
    <li>Hangi kişisel bilgilerin toplandığını öğrenme,</li>
    <li>Kişisel bilgilere erişme,</li>
    <li>Kişisel bilgilerin silinmesini isteme,</li>
    <li>Yanlış bilgilerin düzeltilmesini isteme,</li>
    <li>Kişisel verilerin taşınabilir bir kopyasını isteme,</li>
    <li>Kişisel bilgilerin satılmasına veya paylaşılmasına itiraz etme,</li>
    <li>Hedefli reklamcılık amacıyla kişisel verilerin kullanılmasını reddetme,</li>
    <li>Bazı durumlarda profil oluşturma veya otomatik karar verme faaliyetlerinden çıkma,</li>
    <li>Gizlilik haklarının kullanılması nedeniyle ayrımcı muamele görmeme.</li>
  </ul>
  <p>California kullanıcıları bakımından CCPA/CPRA'nın uygulanabilir olduğu durumlarda "bilme", "silme", "düzeltme", satış/paylaşımı reddetme, hedefli reklamcılıktan çıkma ve ayrımcılığa karşı korunma gibi haklar bulunabilir.</p>
  <p>Virginia'da uygulanabilir olduğu durumlarda erişim, düzeltme, silme, veri taşınabilirliği ve hedefli reklamcılık/satış/profil oluşturmadan çıkma gibi haklar bulunmaktadır.</p>
  <p>Colorado'da da uygulanabilir olduğu durumlarda erişim, düzeltme, silme, taşınabilirlik ve satış/hedefli reklamcılıktan çıkma gibi haklar bulunmaktadır.</p>
  <p>Bu haklar her kullanıcıya otomatik olarak uygulanmayabilir; ilgili eyalet mevzuatındaki kapsam, eşik ve istisnalar dikkate alınır.</p>
  <hr>
  <h2>20. California "Do Not Sell or Share"</h2>
  <p>Onyapp kişisel bilgileri ticari amaçla satmayı hedeflemez.</p>
  <p>Kişisel bilgilerin "satış" veya "paylaşım" kavramları altında değerlendirilebilecek şekilde reklam teknolojileri aracılığıyla işlenmesi halinde, California hukukunun uygulanabildiği durumlarda kullanıcıya mevzuatın gerektirdiği şekilde ilgili seçim ve opt-out mekanizmaları sağlanır.</p>
  <p>California mevzuatı, uygulanabilir işletmeler bakımından tüketicilere kişisel bilgilerin satışı/paylaşımı ve hedefli reklamcılıkla ilgili belirli haklar tanımaktadır.</p>
  <hr>
  <h2>21. Çocukların Gizliliği</h2>
  <p>Onyapp, çocukların kişisel bilgilerinin korunmasına önem verir.</p>
  <p>Onyapp'ın çocuklara yönelik olup olmadığı ve belirli bir kullanıcının çocuk olduğunun bilindiği durumlar bakımından uygulanabilir çocuk gizliliği mevzuatı ayrıca dikkate alınır.</p>
  <p>Amerika Birleşik Devletleri'nde COPPA, 13 yaşın altındaki çocuklara yöneltilen veya 13 yaşın altındaki bir çocuktan kişisel bilgi topladığını fiilen bilen çevrim içi hizmetlere uygulanabilir. Bu durumlarda ebeveyn bilgilendirmesi ve uygulanabilir hallerde doğrulanabilir ebeveyn izni gibi yükümlülükler doğabilir.</p>
  <p>Onyapp'ın çocuklara yönelik olarak pazarlanması, çocuklardan veri toplanması veya yaş bilgilerinin çocuk kullanıcı olduğunu göstermesi halinde ilgili çocuk gizliliği gerekliliklerine göre ek teknik ve idari tedbirler uygulanabilir.</p>
  <p>Avrupa'da çocukların kişisel verileri bakımından GDPR ve ilgili ülke mevzuatındaki çocuklara ilişkin özel hükümler uygulanabilir.</p>
  <p>Apple ve Google'ın çocuklara yönelik uygulamalar ve aile politikaları da ayrıca uygulanabilir.</p>
  <hr>
  <h2>22. Özel Nitelikli / Hassas Veriler</h2>
  <p>Onyapp, oyun hizmetinin çalışması için gerekli olmayan özel nitelikli veya hassas kişisel verileri istemeyi amaçlamaz.</p>
  <p>Kullanıcılardan:</p>
  <ul>
    <li>Sağlık bilgileri,</li>
    <li>Biyometrik bilgiler,</li>
    <li>Genetik bilgiler,</li>
    <li>Dini veya siyasi görüşler,</li>
    <li>Cinsel yaşam veya yönelim bilgileri,</li>
    <li>Irk veya etnik köken bilgileri</li>
  </ul>
  <p>gibi hassas bilgilerin uygulama içerisindeki profil alanlarına girilmemesi gerekir.</p>
  <p>Kullanıcının kendi isteğiyle bu tür bilgileri herkese açık veya başka kullanıcıların görebileceği alanlara yazması halinde, söz konusu bilgilerin üçüncü kişiler tarafından görülmesinden doğabilecek sonuçlardan kullanıcı sorumlu olabilir.</p>
  <p>Onyapp, bu tür bilgileri oyun hizmetinin bir parçası olarak talep etmez.</p>
  <hr>
  <h2>23. Profil ve Kullanıcı Tarafından Paylaşılan İçerikler</h2>
  <p>Kullanıcı adı, görünen ad ve profil fotoğrafı gibi bilgiler, uygulamanın sosyal veya rekabetçi özellikleri kapsamında diğer kullanıcılar tarafından görülebilir.</p>
  <p>Kullanıcıların profil alanlarına kendileri veya başka kişiler hakkında gereksiz kişisel bilgi eklememeleri gerekir.</p>
  <p>Kullanıcı tarafından kamuya açık veya diğer kullanıcıların erişebileceği şekilde paylaşılan bilgiler, paylaşımın niteliğine göre kişisel veri niteliğini koruyabilir.</p>
  <hr>
  <h2>24. Çerezler ve Benzeri Teknolojiler</h2>
  <p>Onyapp doğrudan web tarayıcısı çerezleri kullanmayabilir.</p>
  <p>Bununla birlikte, uygulamaya entegre edilen üçüncü taraf SDK'lar aşağıdakiler dahil olmak üzere benzer teknolojiler veya cihaz tanımlayıcıları kullanabilir:</p>
  <ul>
    <li>Reklam kimliği,</li>
    <li>Cihaz tanımlayıcıları,</li>
    <li>SDK tarafından oluşturulan tanımlayıcılar,</li>
    <li>IP adresi,</li>
    <li>Reklam etkileşim bilgileri,</li>
    <li>Teknik cihaz bilgileri.</li>
  </ul>
  <p>Bu teknolojilerin kullanımı, ilgili SDK'nın yapılandırmasına ve kullanıcının bulunduğu ülkeye göre değişebilir.</p>
  <hr>
  <h2>25. Apple App Store Gizlilik Beyanı</h2>
  <p>Onyapp'ın Apple App Store'da yayınlanması halinde App Store Connect içerisinde Apple tarafından istenen App Privacy bilgileri doğru ve güncel şekilde beyan edilir.</p>
  <p>Bu beyanlar yalnızca Onyapp'ın kendi veri işleme faaliyetlerini değil, uygulamaya entegre edilen ilgili üçüncü taraf SDK'ların veri toplama ve kullanım faaliyetlerini de dikkate alır. Apple, App Store'da uygulamanın veri toplama ve kullanım uygulamalarına ilişkin gizlilik etiketlerinin sunulmasını zorunlu tutmaktadır.</p>
  <p>Onyapp'ın veri işleme uygulamalarında değişiklik olması halinde App Store Connect üzerindeki ilgili gizlilik bilgilerinin de güncellenmesi amaçlanır.</p>
  <hr>
  <h2>26. Google Play Data Safety Beyanı</h2>
  <p>Onyapp'ın Google Play'de yayınlanması halinde Google Play Console'daki Data Safety bölümü, uygulamanın ve entegre üçüncü taraf SDK'ların gerçek veri işleme uygulamalarıyla uyumlu şekilde doldurulur.</p>
  <p>Google Play, geliştiricilerin uygulamalarının veri toplama, kullanma ve paylaşma uygulamalarını doğru şekilde açıklamasını ve bu bilgilerin gizlilik politikasıyla uyumlu olmasını gerektirir.</p>
  <p>Bu nedenle bu Gizlilik Politikası ile Google Play Data Safety beyanlarının birbirinden farklı bilgiler içermemesi için gerekli güncellemeler yapılır.</p>
  <hr>
  <h2>27. Veri Güvenliği</h2>
  <p>Kişisel verilerin:</p>
  <ul>
    <li>Yetkisiz erişime,</li>
    <li>Yetkisiz değişikliğe,</li>
    <li>Kayıp veya imhaya,</li>
    <li>Yetkisiz açıklamaya</li>
  </ul>
  <p>karşı korunması amacıyla makul teknik ve idari güvenlik tedbirleri uygulanır.</p>
  <p>Bunlar kapsamında uygun olduğu ölçüde:</p>
  <ul>
    <li>Güvenli bağlantılar,</li>
    <li>Parola hashleme,</li>
    <li>Erişim kontrolleri,</li>
    <li>Yetkilendirme,</li>
    <li>Sunucu güvenliği,</li>
    <li>Güvenlik günlükleri,</li>
    <li>Yetkisiz erişim tespiti,</li>
    <li>Yedekleme ve kurtarma mekanizmaları</li>
  </ul>
  <p>kullanılabilir.</p>
  <p>Bununla birlikte hiçbir internet bağlantısı, elektronik depolama sistemi veya yazılım altyapısı yüzde yüz güvenli olarak garanti edilemez.</p>
  <p>Bir kişisel veri güvenliği ihlali meydana gelmesi halinde, uygulanabilir mevzuat kapsamında gerekli değerlendirme, bildirim ve düzeltici işlemler gerçekleştirilir.</p>
  <hr>
  <h2>28. Veri Minimizasyonu</h2>
  <p>Onyapp, hizmetin sağlanması için gerekli olmayan kişisel verilerin toplanmaması veya işlenmemesi ilkesini benimser.</p>
  <p>Toplanan bilgiler, belirlenen amaçlarla bağlantılı, gerekli ve ölçülü tutulmaya çalışılır.</p>
  <p>GDPR kapsamında da veri minimizasyonu ve amaçla sınırlılık temel veri koruma ilkeleri arasındadır.</p>
  <hr>
  <h2>29. Otomatik Karar Verme ve Profil Oluşturma</h2>
  <p>Onyapp, kullanıcılar hakkında hukuki veya benzer şekilde önemli sonuç doğuran otomatik kararlar vermeyi amaçlamaz.</p>
  <p>Oyun puanı, lig sıralaması, başarımlar veya oyun içi sonuçların otomatik olarak hesaplanması, tek başına hukuki veya benzer şekilde önemli bir karar verme faaliyeti olarak kullanılmaz.</p>
  <p>Reklam hizmetleri tarafından gerçekleştirilen reklam kişiselleştirme veya profil oluşturma faaliyetleri, ilgili üçüncü taraf sağlayıcının kendi sistemleri ve politikaları kapsamında gerçekleşebilir.</p>
  <hr>
  <h2>30. Kullanıcı Taleplerinin Doğrulanması</h2>
  <p>Kişisel verilere erişim, hesap silme, düzeltme veya benzeri taleplerin güvenli şekilde sonuçlandırılabilmesi için, talepte bulunan kişinin ilgili hesap üzerinde yetkili olduğunu doğrulamak gerekebilir.</p>
  <p>Kimlik doğrulama amacıyla gereğinden fazla kişisel veri talep edilmez.</p>
  <p>Bir başvurunun başka bir kişinin verilerine yetkisiz erişim sağlayabileceği değerlendirilirse, uygulanabilir mevzuat kapsamında gerekli güvenlik kontrolleri yapılabilir.</p>
  <hr>
  <h2>31. Kullanıcı Taleplerinin Sonuçlandırılması</h2>
  <p>Kullanıcı talepleri uygulanabilir mevzuatta öngörülen süreler içinde değerlendirilir.</p>
  <p>Bazı talepler:</p>
  <ul>
    <li>Yasal saklama yükümlülükleri,</li>
    <li>Güvenlik gereklilikleri,</li>
    <li>Dolandırıcılık ve kötüye kullanımın önlenmesi,</li>
    <li>Hukuki uyuşmazlıklar,</li>
    <li>Üçüncü kişilerin hakları,</li>
    <li>Teknik sınırlamalar</li>
  </ul>
  <p>nedeniyle tamamen veya derhal yerine getirilemeyebilir.</p>
  <p>Böyle bir durumda kullanıcıya uygulanabilir mevzuatın izin verdiği ölçüde gerekçe bildirilir.</p>
  <hr>
  <h2>32. Üçüncü Taraf Web Siteleri ve Hizmetleri</h2>
  <p>Onyapp içerisinde veya uygulama aracılığıyla üçüncü taraf web sitelerine veya hizmetlerine bağlantılar bulunabilir.</p>
  <p>Bu hizmetler Onyapp tarafından işletilmiyorsa, bu hizmetlerin kendi gizlilik politikaları ve kullanım şartları geçerlidir.</p>
  <p>Bir üçüncü taraf hizmetine ilişkin kişisel veri işlemenin kapsamı, ilgili üçüncü tarafın kendi politikalarına göre belirlenir.</p>
  <hr>
  <h2>33. Gizlilik Politikasında Değişiklikler</h2>
  <p>Bu Gizlilik Politikası zaman zaman güncellenebilir.</p>
  <p>Değişiklikler:</p>
  <ul>
    <li>Yeni özelliklerin eklenmesi,</li>
    <li>Yeni üçüncü taraf hizmetlerin kullanılması,</li>
    <li>Mevzuat değişiklikleri,</li>
    <li>Veri işleme yöntemlerinin değişmesi,</li>
    <li>Güvenlik veya teknik gereklilikler</li>
  </ul>
  <p>nedeniyle yapılabilir.</p>
  <p>Önemli değişiklikler olması halinde uygulanabilir mevzuatın gerektirdiği ölçüde kullanıcılar bilgilendirilir.</p>
  <p>Politikanın en güncel sürümü bu sayfada yayımlanır ve güncel sürümün tarihi metnin başında gösterilir.</p>
  <hr>
  <h2>34. Veri Sorumlusu ile İletişim</h2>
  <p>Kişisel verileriniz, gizlilik haklarınız veya bu politika hakkında sorularınız için:</p>
  <p><strong>Veri Sorumlusu:</strong> [Şirket Unvanı]<br>
  <strong>E-posta:</strong> [Gizlilik E-posta Adresi]<br>
  <strong>Adres:</strong> [Şirket Adresi]<br>
  <strong>Web:</strong> [Web Sitesi]</p>
  <p>üzerinden bizimle iletişime geçebilirsiniz.</p>
  <p>Hesap silme veya kişisel veri taleplerinde konu başlığına <strong>"Onyapp Veri Talebi"</strong> veya <strong>"Onyapp Hesap Silme Talebi"</strong> yazılması işlemlerin daha hızlı değerlendirilmesine yardımcı olabilir.</p>
  <p>Türkiye'deki kullanıcıların KVKK kapsamındaki başvuruları için uygulanabilir başvuru yöntemleri ve yasal süreler saklıdır.</p>
  <p>Avrupa Birliği/AEA veya Birleşik Krallık kullanıcıları, uygulanabilir olması halinde kendi ülkelerindeki yetkili veri koruma otoritesine şikâyette bulunma hakkına da sahiptir.</p>
  <hr>
  <h2>35. Kabul ve Uygulanabilirlik</h2>
  <p>Onyapp'ın kullanılması, bu Gizlilik Politikası'nın kullanıcıya sunulduğu ve uygulanabilir mevzuat kapsamında kullanıcıya sağlanan hakların saklı olduğu anlamına gelir.</p>
  <p>Bu politika, kullanıcıların kanunlardan doğan emredici haklarını ortadan kaldırmaz, sınırlandırmaz veya bunlardan feragat edilmesini sağlamaz.</p>
  <p>Uygulanabilir mevzuat ile bu politika arasında zorunlu bir farklılık olması halinde, uygulanabilir mevzuatın emredici hükümleri önceliklidir.</p>
  <p><strong>Son güncelleme:</strong> 27 Eylül 2026</p>
</article>
<article class="legal-lang" lang="en" data-legal="en">
  <h1>Onyapp Privacy Policy</h1>
  <p><strong>Last updated: 27 September 2026</strong></p>
  <p>This Privacy Policy is prepared to inform users about the personal data processing activities carried out through the <strong>Onyapp</strong> mobile application ("Onyapp", the "Application", "we", "us", or "our").</p>
  <p>This policy aims to inform users under Turkey's Law No. 6698 on the Protection of Personal Data ("KVKK"), the European Union General Data Protection Regulation ("GDPR"), and, to the extent applicable, United Kingdom data protection law and applicable federal and state privacy laws in the United States.</p>
  <p>The privacy and user-data policies of application stores such as the Apple App Store and Google Play also apply.</p>
  <hr>
  <h2>1. Data Controller / Data Processor</h2>
  <p>For personal data processed within Onyapp, the data controller, depending on the relevant processing activity, acts as:</p>
  <p><strong>[Şirket Unvanı]</strong><br>
  <strong>Address:</strong> [Şirket Adresi]<br>
  <strong>Email:</strong> [Gizlilik / KVKK E-posta Adresi]<br>
  <strong>Web:</strong> [Web Sitesi]</p>
  <p>Some personal data may also be processed independently, or on our behalf, by third-party service providers used to operate the application, within the scope of their own services.</p>
  <p>For a third party's own data processing activities, that provider's privacy policy and terms also apply.</p>
  <hr>
  <h2>2. What Information Do We Process?</h2>
  <p>The information processed in Onyapp may vary depending on which features of the application are used.</p>
  <h3>2.1. Guest User Information</h3>
  <p>When Onyapp's guest feature is used, the following may be processed:</p>
  <ul>
    <li>A player/user identifier created by the application,</li>
    <li>An automatically generated display name,</li>
    <li>Game progress,</li>
    <li>Scores,</li>
    <li>League points,</li>
    <li>Achievements,</li>
    <li>Coin balance,</li>
    <li>Streak information,</li>
    <li>Play time and in-game performance information.</li>
  </ul>
  <p>Guest use does not require a first name, last name, or email address.</p>
  <p>Device, application, and technical connection information may still be processed by third-party SDKs or the server infrastructure for the operation and security of their own services.</p>
  <hr>
  <h3>2.2. Account Creation with Email</h3>
  <p>If an account is created with email, the following may be processed:</p>
  <ul>
    <li>Name,</li>
    <li>Email address,</li>
    <li>User account identifier,</li>
    <li>A secure cryptographic hash of the password,</li>
    <li>Account and game progress information.</li>
  </ul>
  <p>The password itself is not stored in plain text.</p>
  <p>The cryptographic methods and technical security measures used to store the password securely may be updated over time.</p>
  <hr>
  <h3>2.3. Sign-in with Google</h3>
  <p>If sign-in with Google is used, information provided to the application by Google may be processed.</p>
  <p>This may include:</p>
  <ul>
    <li>Google account identifier,</li>
    <li>Name,</li>
    <li>Email address,</li>
    <li>Technical identity information related to the Google account.</li>
  </ul>
  <p>Onyapp does not receive or store the Google account password.</p>
  <p>If you sign in with a Google account, Google's own privacy policy and terms of service also apply.</p>
  <hr>
  <h3>2.4. Profile Photo</h3>
  <p>A profile photo may be uploaded optionally by the user.</p>
  <p>A profile photo is processed in order to:</p>
  <ul>
    <li>Display it on the user profile,</li>
    <li>Personalize the user account,</li>
    <li>Create the in-game profile appearance.</li>
  </ul>
  <p>Uploading a profile photo is not required.</p>
  <p>The user may remove or change the profile photo through the relevant features of the application.</p>
  <p>Unless the user expressly uploads one, Onyapp does not take a profile photo from the camera or photo gallery on its own.</p>
  <hr>
  <h2>3. Game and Usage Data</h2>
  <p>The following information may be processed so that Onyapp's game features can work:</p>
  <ul>
    <li>Score,</li>
    <li>Play time,</li>
    <li>Guesses,</li>
    <li>Correct and incorrect answers,</li>
    <li>League points,</li>
    <li>League ranking,</li>
    <li>Streak,</li>
    <li>Achievements,</li>
    <li>Game level,</li>
    <li>In-game progress,</li>
    <li>Coin balance,</li>
    <li>In-game rewards used or earned,</li>
    <li>Game sessions,</li>
    <li>Game results,</li>
    <li>Username and profile information.</li>
  </ul>
  <p>This information may be processed to provide the game experience, save progress, build rankings, grant rewards, and detect cheating or abusive activity.</p>
  <hr>
  <h2>4. Purchase and Payment Information</h2>
  <p>If a purchase is made inside Onyapp through Google Play Billing or Apple's in-app purchase system, the payment is processed by the relevant application store.</p>
  <p>Onyapp does not receive or store payment information such as:</p>
  <ul>
    <li>Credit card number,</li>
    <li>Debit card number,</li>
    <li>CVV/CVC,</li>
    <li>Card PIN,</li>
    <li>Online banking information.</li>
  </ul>
  <p>The following information may be processed to verify the purchase:</p>
  <ul>
    <li>Product identifier,</li>
    <li>Purchase transaction identifier,</li>
    <li>Purchase token,</li>
    <li>Transaction date,</li>
    <li>Transaction status,</li>
    <li>The relevant user or account identifier,</li>
    <li>The type and status of the purchased product.</li>
  </ul>
  <p>Google Play's payment and privacy policies apply to Google Play purchases, and Apple's apply to Apple purchases.</p>
  <hr>
  <h2>5. Rewarded Ads and Advertising Technologies</h2>
  <p>Onyapp may use third-party advertising services such as Google AdMob to offer rewarded ads inside the application.</p>
  <p>When a rewarded ad is shown, the application or the server may process the following so that the reward is granted to the correct user only once and the same ad transaction cannot be reused:</p>
  <ul>
    <li>Ad unit information,</li>
    <li>Ad transaction / verification identifier,</li>
    <li>User or player identifier,</li>
    <li>Reward information,</li>
    <li>Transaction time,</li>
    <li>Verification status of the transaction.</li>
  </ul>
  <p>Google AdMob and related advertising SDKs may, depending on the configuration in use, the device, the operating system, and the user's region, process information such as an advertising identifier, device information, IP address, application information, and ad interactions within the scope of their own services.</p>
  <p>These activities are subject to Google's own privacy policies and the relevant regional requirements.</p>
  <p>On platforms where permission is required for personalized advertising or for tracking across apps and websites, the user may be offered the choice and permission mechanisms the platform requires.</p>
  <p>On Apple devices, where tracking across other companies' apps and websites is required, Apple's App Tracking Transparency ("ATT") system and the related user permissions apply.</p>
  <p>Apple requires that the data practices of the application and of integrated third-party SDKs be described accurately in App Store privacy disclosures.</p>
  <hr>
  <h2>6. Notifications</h2>
  <p>If the user allows a daily reminder or similar notifications, Onyapp may create a notification on the device.</p>
  <p>Notification permission:</p>
  <ul>
    <li>Can be turned off in the device settings,</li>
    <li>Can be managed in the application settings,</li>
    <li>Is not enabled unless the user asks for it.</li>
  </ul>
  <p>If the current technical implementation does not store a notification address or push token on the server, only local notifications created on the device are used.</p>
  <p>If the technical design is later changed to a push notification system, the related data processing will be described by updating this policy.</p>
  <hr>
  <h2>7. Technical Data and Logs</h2>
  <p>The following technical information may be processed within the application or server infrastructure in order to secure the application, detect errors, improve performance, and prevent abuse:</p>
  <ul>
    <li>IP address,</li>
    <li>Date and time,</li>
    <li>Application version,</li>
    <li>Operating system,</li>
    <li>Device type,</li>
    <li>Language and region settings,</li>
    <li>Technical information about the network connection,</li>
    <li>Error logs,</li>
    <li>Server logs,</li>
    <li>Session and security records,</li>
    <li>Technical identifiers that can be associated with a user or device.</li>
  </ul>
  <p>Not all of this information may be collected in the same way for every user or on every platform.</p>
  <p>Technical records are kept for as long as they are needed for security and operation of the service, and are deleted or anonymized after a reasonable period unless a legal reason requires longer retention.</p>
  <hr>
  <h2>8. Sources of Information</h2>
  <p>Personal data may be obtained from the following sources:</p>
  <ol>
    <li>Information the user provides directly,</li>
    <li>Information provided through a Google account,</li>
    <li>Verification information from Google Play or Apple purchase systems,</li>
    <li>Technical information created automatically while the user uses the application,</li>
    <li>Advertising SDKs and other integrated third-party services,</li>
    <li>Game and security records created on Onyapp servers.</li>
  </ol>
  <hr>
  <h2>9. Why Do We Use Personal Data?</h2>
  <p>Personal data may be processed for the following purposes:</p>
  <ul>
    <li>To create and manage a user account,</li>
    <li>To verify the user's identity,</li>
    <li>To create a player profile,</li>
    <li>To save game progress,</li>
    <li>To restore game progress across sessions,</li>
    <li>To calculate scores,</li>
    <li>To build leagues and rankings,</li>
    <li>To record achievements,</li>
    <li>To manage the coin balance,</li>
    <li>To grant in-game rewards,</li>
    <li>To verify purchases,</li>
    <li>To verify rewarded ads,</li>
    <li>To prevent the same ad transaction from being rewarded more than once,</li>
    <li>To prevent fraud, cheating, abuse, and unauthorized access,</li>
    <li>To keep the application secure,</li>
    <li>To detect errors,</li>
    <li>To improve the application's performance and stability,</li>
    <li>To show the notifications the user requested,</li>
    <li>To meet legal obligations,</li>
    <li>To respond to user requests and applications,</li>
    <li>To exercise or defend our legal rights.</li>
  </ul>
  <p>If personal data will be used for a new purpose that is incompatible with the purposes described in this policy, the user is informed separately, or the required permission is obtained, where applicable law requires it.</p>
  <hr>
  <h2>10. Legal Bases for Processing</h2>
  <h3>10.1. KVKK</h3>
  <p>For users in Turkey, personal data may be processed under one or more of the legal conditions for processing set out in the KVKK, depending on the nature of the activity.</p>
  <p>These legal bases may include:</p>
  <ul>
    <li>Being expressly provided for by law,</li>
    <li>Being necessary for the establishment or performance of a contract,</li>
    <li>Compliance with a legal obligation of the data controller,</li>
    <li>Processing being mandatory for the establishment, exercise, or protection of a right,</li>
    <li>The legitimate interest of the data controller,</li>
    <li>The explicit consent of the data subject.</li>
  </ul>
  <p>Under the KVKK, explicit consent is not a mandatory condition for every act of processing. The legal basis appropriate to the relevant activity is assessed separately.</p>
  <p>Under the KVKK, the user is informed about the identity of the data controller, the purposes of processing, the persons or groups to whom data may be transferred, the method and legal basis of collection, and the rights of the data subject.</p>
  <hr>
  <h3>10.2. GDPR / European Economic Area</h3>
  <p>Where the GDPR applies, personal data may be processed under one of the following legal bases, depending on the nature of the activity:</p>
  <ul>
    <li>The establishment or performance of the user's contract,</li>
    <li>Compliance with a legal obligation,</li>
    <li>Legitimate interest,</li>
    <li>The user's explicit consent,</li>
    <li>Other legal bases recognized under the GDPR, such as protecting the vital interests of the user or another person.</li>
  </ul>
  <p>Where processing is based on consent, the user may withdraw consent at any time. Withdrawal does not affect the lawfulness of processing carried out on the basis of consent before the withdrawal.</p>
  <p>Where the GDPR applies, processing of personal data is carried out in line with the principles of fairness, transparency, purpose limitation, data minimization, accuracy, storage limitation, and security.</p>
  <hr>
  <h2>11. Sharing of Personal Data</h2>
  <p>Personal data is not sold or rented.</p>
  <p>To the extent necessary for the service to work, data may still be shared with parties in the following categories:</p>
  <h3>Google</h3>
  <ul>
    <li>Google Sign-In,</li>
    <li>Google Play Billing,</li>
    <li>Google AdMob,</li>
    <li>Related Google SDKs and services.</li>
  </ul>
  <h3>Apple</h3>
  <p>For the App Store and in-app purchase services used on Apple devices, the related transaction verification information may be processed through Apple's systems.</p>
  <h3>Railway</h3>
  <p>Railway infrastructure is used to host Onyapp's application and server infrastructure.</p>
  <h3>Technical service providers</h3>
  <p>If other infrastructure, security, analytics, error-monitoring, or technical service providers become necessary for the application to work, those providers may access personal data according to the scope of that service.</p>
  <p>Such providers access, as far as possible, only the data required to perform the service given to them.</p>
  <p>For a third-party provider's own independent processing, that provider's privacy policy also applies.</p>
  <hr>
  <h2>12. Third-Party Services</h2>
  <p>The main categories of third-party services Onyapp uses, or may use, are:</p>
  <table>
    <thead>
      <tr><th>Service</th><th>Purpose</th></tr>
    </thead>
    <tbody>
      <tr><td>Google Sign-In</td><td>Account sign-in</td></tr>
      <tr><td>Google Play Billing</td><td>In-app purchases</td></tr>
      <tr><td>Google AdMob</td><td>Rewarded ads</td></tr>
      <tr><td>Apple App Store / StoreKit</td><td>iOS app distribution and in-app purchases</td></tr>
      <tr><td>Railway</td><td>Server and application infrastructure</td></tr>
    </tbody>
  </table>
  <p>Those services' own privacy policies may apply to their own processing.</p>
  <p>Onyapp does not control the independent processing activities of third-party service providers. Where a provider is used by Onyapp as a processor, the contractual and technical measures required by applicable law are sought.</p>
  <hr>
  <h2>13. International Data Transfers</h2>
  <p>The infrastructure of some service providers used by Onyapp may be located outside Turkey, the European Union, or the European Economic Area.</p>
  <p>Personal data may therefore be transferred to, or processed in, servers in different countries where that is technically necessary for the service.</p>
  <p>For users in Turkey, transfers of personal data abroad are carried out in line with the KVKK's cross-border transfer rules and applicable secondary legislation.</p>
  <p>Under the KVKK, standard contracts, binding corporate rules, or other appropriate safeguards provided by law may be used according to the legal structure of the transfer. After the 2024 amendments, the KVKK regulates standard contracts as one of the appropriate safeguard methods for transfers abroad.</p>
  <p>Where the GDPR applies, transfers to countries outside the European Economic Area may be carried out using mechanisms that comply with the GDPR's international transfer rules. These may include an adequacy decision or, where applicable, Standard Contractual Clauses (SCCs) adopted by the European Commission.</p>
  <hr>
  <h2>14. How Long Data Is Kept</h2>
  <p>Personal data is kept only for as long as it is needed for the purpose of processing, or for as long as a legal obligation requires.</p>
  <p>When the retention period is set, the following are taken into account:</p>
  <ul>
    <li>Whether the account is active,</li>
    <li>The service life of the game,</li>
    <li>Purchase verification requirements,</li>
    <li>Accounting and tax obligations,</li>
    <li>Security and prevention of abuse,</li>
    <li>Resolution of legal disputes,</li>
    <li>Legal retention obligations.</li>
  </ul>
  <p>In general:</p>
  <p><strong>Account data:</strong> For as long as the account is active, or until the user requests deletion.</p>
  <p><strong>Game data:</strong> For as long as it is needed to provide the service linked to the account.</p>
  <p><strong>Guest data:</strong> For as long as it is needed to provide the guest account and the related game service.</p>
  <p><strong>Purchase records:</strong> For as long as needed for purchase verification, accounting, tax, and legal obligations.</p>
  <p><strong>Ad reward verification records:</strong> For as long as needed to grant the reward only once and to prevent abuse.</p>
  <p><strong>Security and server logs:</strong> For a reasonable period needed for security, error detection, and prevention of abuse.</p>
  <p>When the retention period ends, the data is deleted, anonymized, or put into a form that can no longer identify the person.</p>
  <hr>
  <h2>15. Account and Data Deletion</h2>
  <p>The user may request deletion of their account and of the personal data linked to that account.</p>
  <p>A deletion request may be sent to:</p>
  <p><strong>Email:</strong> [Gizlilik / Veri Silme E-posta Adresi]</p>
  <p>After the request is verified, the relevant account and personal data are deleted or anonymized within the period required by applicable law, except for information that must be kept by law.</p>
  <p>Some information may not be deletable immediately because of legal obligations, fraud or security reviews, resolution of disputes, or the exercise of legal rights.</p>
  <p>Google Play requires apps that allow account creation to offer a way for users to delete their account and associated data. Onyapp's account deletion mechanism must therefore be reachable in the application and/or through a suitable web channel.</p>
  <hr>
  <h2>16. User Rights</h2>
  <p>Depending on applicable law, users may have the following rights.</p>
  <h3>16.1. Rights under the KVKK</h3>
  <p>Under the KVKK, users may have the right to:</p>
  <ul>
    <li>Learn whether their personal data is processed,</li>
    <li>Request information about the processing if it has been processed,</li>
    <li>Learn the purpose of processing and whether it is used in line with that purpose,</li>
    <li>Know the third parties to whom personal data is transferred in Turkey or abroad,</li>
    <li>Request correction of incomplete or inaccurate data,</li>
    <li>Request deletion or destruction of personal data under the conditions set out in the law,</li>
    <li>Request that correction, deletion, or destruction be notified to third parties to whom the data was transferred,</li>
    <li>Object to a result against them that arises from analysis of the processed data solely through automated systems,</li>
    <li>Request compensation for damage if they suffer damage because of unlawful processing.</li>
  </ul>
  <hr>
  <h2>17. Rights under the GDPR</h2>
  <p>Where the GDPR applies, users may, depending on the circumstances, have rights such as:</p>
  <ul>
    <li>Access to personal data,</li>
    <li>Correction of inaccurate personal data,</li>
    <li>Erasure of personal data,</li>
    <li>Restriction of processing,</li>
    <li>Data portability,</li>
    <li>Objection to processing,</li>
    <li>Withdrawal of consent where processing is based on consent,</li>
    <li>Rights related to automated decision-making and profiling.</li>
  </ul>
  <p>Some of these rights are not absolute and may be subject to the exceptions set out in the GDPR.</p>
  <p>For example, data that must be kept because of a legal obligation may not be deletable immediately when the user asks for it.</p>
  <hr>
  <h2>18. Users in the United Kingdom</h2>
  <p>Where United Kingdom data protection law applies, users may have rights of access, correction, erasure, restriction of processing, data portability, objection, and other applicable rights under that law.</p>
  <p>Users in the United Kingdom may also have the right to complain to the Information Commissioner's Office ("ICO"), where that applies.</p>
  <hr>
  <h2>19. Users in the United States</h2>
  <p>Privacy rights in the United States may vary by state.</p>
  <p>To the extent applicable, users may have some of the following rights under the consumer privacy laws of California, Virginia, Colorado, and other states:</p>
  <ul>
    <li>To learn which personal information is collected,</li>
    <li>To access personal information,</li>
    <li>To request deletion of personal information,</li>
    <li>To request correction of inaccurate information,</li>
    <li>To request a portable copy of personal data,</li>
    <li>To object to the sale or sharing of personal information,</li>
    <li>To opt out of the use of personal data for targeted advertising,</li>
    <li>In some cases, to opt out of profiling or automated decision-making,</li>
    <li>Not to be treated in a discriminatory way for exercising privacy rights.</li>
  </ul>
  <p>For California users, where the CCPA/CPRA applies, rights may include the right to know, delete, and correct, to opt out of sale/sharing, to opt out of targeted advertising, and to be protected against discrimination.</p>
  <p>In Virginia, where applicable, rights include access, correction, deletion, data portability, and opting out of targeted advertising, sale, or profiling.</p>
  <p>In Colorado, where applicable, rights include access, correction, deletion, portability, and opting out of sale or targeted advertising.</p>
  <p>These rights do not apply automatically to every user. The scope, thresholds, and exceptions in the relevant state law are taken into account.</p>
  <hr>
  <h2>20. California "Do Not Sell or Share"</h2>
  <p>Onyapp does not aim to sell personal information for a commercial purpose.</p>
  <p>If personal information is processed through advertising technologies in a way that could be treated as a "sale" or "sharing", users are given the choice and opt-out mechanisms required by law where California law applies.</p>
  <p>California law gives consumers certain rights, for applicable businesses, regarding the sale/sharing of personal information and targeted advertising.</p>
  <hr>
  <h2>21. Children's Privacy</h2>
  <p>Onyapp cares about the protection of children's personal information.</p>
  <p>Applicable children's privacy law is also taken into account as to whether Onyapp is directed at children, and in cases where it is known that a particular user is a child.</p>
  <p>In the United States, COPPA may apply to online services directed at children under 13, or that actually know they collect personal information from a child under 13. In those cases, obligations such as parental notice and, where applicable, verifiable parental consent may arise.</p>
  <p>If Onyapp is marketed to children, if data is collected from children, or if age information shows that the user is a child, additional technical and administrative measures may be applied under the relevant children's privacy requirements.</p>
  <p>In Europe, the GDPR and the special provisions on children in the relevant national law may apply to children's personal data.</p>
  <p>Apple's and Google's policies for apps directed at children, and their family policies, may also apply.</p>
  <hr>
  <h2>22. Special Category / Sensitive Data</h2>
  <p>Onyapp does not aim to request special-category or sensitive personal data that is not needed for the game service to work.</p>
  <p>Users should not enter sensitive information such as the following into profile fields inside the application:</p>
  <ul>
    <li>Health information,</li>
    <li>Biometric information,</li>
    <li>Genetic information,</li>
    <li>Religious or political opinions,</li>
    <li>Information about sex life or sexual orientation,</li>
    <li>Information about race or ethnic origin.</li>
  </ul>
  <p>If the user chooses to write such information in areas that are public or visible to other users, the user may be responsible for the consequences of that information being seen by third parties.</p>
  <p>Onyapp does not request this kind of information as part of the game service.</p>
  <hr>
  <h2>23. Profile and Content Shared by the User</h2>
  <p>Information such as a username, display name, and profile photo may be visible to other users through the application's social or competitive features.</p>
  <p>Users should not add unnecessary personal information about themselves or other people to profile fields.</p>
  <p>Information the user shares publicly, or in a way other users can access, may remain personal data depending on the nature of the sharing.</p>
  <hr>
  <h2>24. Cookies and Similar Technologies</h2>
  <p>Onyapp may not use web browser cookies directly.</p>
  <p>Third-party SDKs integrated into the application may still use similar technologies or device identifiers, including:</p>
  <ul>
    <li>Advertising identifier,</li>
    <li>Device identifiers,</li>
    <li>Identifiers created by the SDK,</li>
    <li>IP address,</li>
    <li>Ad interaction information,</li>
    <li>Technical device information.</li>
  </ul>
  <p>Use of these technologies may vary with the SDK's configuration and the user's country.</p>
  <hr>
  <h2>25. Apple App Store Privacy Disclosure</h2>
  <p>If Onyapp is published on the Apple App Store, the App Privacy information Apple requires in App Store Connect is declared accurately and kept up to date.</p>
  <p>These disclosures take into account not only Onyapp's own processing, but also the data collection and use of the relevant third-party SDKs integrated into the application. Apple requires privacy labels about the application's data collection and use practices to be provided on the App Store.</p>
  <p>If Onyapp's data practices change, the related privacy information in App Store Connect is intended to be updated as well.</p>
  <hr>
  <h2>26. Google Play Data Safety Disclosure</h2>
  <p>If Onyapp is published on Google Play, the Data Safety section in Google Play Console is completed in line with the actual data practices of the application and of integrated third-party SDKs.</p>
  <p>Google Play requires developers to describe accurately how their applications collect, use, and share data, and for that information to be consistent with the privacy policy.</p>
  <p>The updates needed are therefore made so that this Privacy Policy and the Google Play Data Safety disclosures do not contain different information.</p>
  <hr>
  <h2>27. Data Security</h2>
  <p>Reasonable technical and administrative security measures are applied to protect personal data against:</p>
  <ul>
    <li>Unauthorized access,</li>
    <li>Unauthorized alteration,</li>
    <li>Loss or destruction,</li>
    <li>Unauthorized disclosure.</li>
  </ul>
  <p>Where appropriate, these may include:</p>
  <ul>
    <li>Secure connections,</li>
    <li>Password hashing,</li>
    <li>Access controls,</li>
    <li>Authorization,</li>
    <li>Server security,</li>
    <li>Security logs,</li>
    <li>Detection of unauthorized access,</li>
    <li>Backup and recovery mechanisms.</li>
  </ul>
  <p>No internet connection, electronic storage system, or software infrastructure can be guaranteed to be fully secure.</p>
  <p>If a personal data security breach occurs, the assessment, notification, and corrective steps required by applicable law are carried out.</p>
  <hr>
  <h2>28. Data Minimization</h2>
  <p>Onyapp adopts the principle of not collecting or processing personal data that is not needed to provide the service.</p>
  <p>Information that is collected is kept relevant, necessary, and proportionate to the stated purposes.</p>
  <p>Under the GDPR, data minimization and purpose limitation are also among the core data protection principles.</p>
  <hr>
  <h2>29. Automated Decision-Making and Profiling</h2>
  <p>Onyapp does not aim to make automated decisions about users that produce legal effects or similarly significant effects.</p>
  <p>Automatic calculation of a game score, league ranking, achievements, or in-game results is not used, on its own, as a decision with legal or similarly significant effects.</p>
  <p>Ad personalization or profiling carried out by advertising services may take place within those third-party providers' own systems and policies.</p>
  <hr>
  <h2>30. Verification of User Requests</h2>
  <p>To complete requests for access to personal data, account deletion, correction, or similar requests securely, it may be necessary to verify that the person making the request is authorized on the relevant account.</p>
  <p>More personal data than needed is not requested for identity verification.</p>
  <p>If a request is assessed as likely to give unauthorized access to another person's data, the security checks required by applicable law may be carried out.</p>
  <hr>
  <h2>31. Completion of User Requests</h2>
  <p>User requests are assessed within the periods set by applicable law.</p>
  <p>Some requests may not be fulfilled in full, or immediately, because of:</p>
  <ul>
    <li>Legal retention obligations,</li>
    <li>Security requirements,</li>
    <li>Prevention of fraud and abuse,</li>
    <li>Legal disputes,</li>
    <li>The rights of third parties,</li>
    <li>Technical limitations.</li>
  </ul>
  <p>In that case, the user is told the reason to the extent applicable law allows.</p>
  <hr>
  <h2>32. Third-Party Websites and Services</h2>
  <p>Onyapp, or the application, may contain links to third-party websites or services.</p>
  <p>If those services are not operated by Onyapp, their own privacy policies and terms of use apply.</p>
  <p>The scope of personal data processing for a third-party service is determined by that third party's own policies.</p>
  <hr>
  <h2>33. Changes to the Privacy Policy</h2>
  <p>This Privacy Policy may be updated from time to time.</p>
  <p>Changes may be made because of:</p>
  <ul>
    <li>New features,</li>
    <li>New third-party services,</li>
    <li>Changes in the law,</li>
    <li>Changes in processing methods,</li>
    <li>Security or technical requirements.</li>
  </ul>
  <p>If there are important changes, users are informed to the extent applicable law requires.</p>
  <p>The current version of the policy is published on this page, and the date of the current version is shown at the top of the text.</p>
  <hr>
  <h2>34. Contacting the Data Controller</h2>
  <p>For questions about your personal data, your privacy rights, or this policy, you can contact us at:</p>
  <p><strong>Data controller:</strong> [Şirket Unvanı]<br>
  <strong>Email:</strong> [Gizlilik E-posta Adresi]<br>
  <strong>Address:</strong> [Şirket Adresi]<br>
  <strong>Web:</strong> [Web Sitesi]</p>
  <p>For account deletion or personal data requests, writing <strong>"Onyapp Veri Talebi"</strong> or <strong>"Onyapp Hesap Silme Talebi"</strong> in the subject line — or the English forms <strong>"Onyapp Data Request"</strong> and <strong>"Onyapp Account Deletion Request"</strong> — can help the request be reviewed faster.</p>
  <p>For users in Turkey, the applicable application methods and legal periods for requests under the KVKK are reserved.</p>
  <p>Users in the European Union/EEA or the United Kingdom also have the right, where applicable, to complain to the competent data protection authority in their own country.</p>
  <hr>
  <h2>35. Acceptance and Applicability</h2>
  <p>Use of Onyapp means that this Privacy Policy has been made available to the user, and that the rights granted to the user under applicable law remain reserved.</p>
  <p>This policy does not remove, limit, or cause a waiver of the mandatory rights users have under the law.</p>
  <p>If there is a mandatory difference between applicable law and this policy, the mandatory provisions of applicable law take priority.</p>
  <p><strong>Last updated:</strong> 27 September 2026</p>
</article>
</main>
<footer>
  <div class="footer-inner">
    <a href="/" class="logo"><span class="logo-mark" aria-hidden="true">🎮</span><span><b>Onyapp</b></span></a>
    <div class="footer-links">
      <a href="/" data-i18n="navHome">Ana Sayfa</a>
      <a href="/oyunlar" data-i18n="navGames">Oyunlar</a>
      <a href="/hakkimizda" data-i18n="navAbout">Hakkımızda</a>
      <a href="/iletisim" data-i18n="navContact">İletişim</a>
      <a href="https://onyapp.app/privacy" data-i18n="privacy">Gizlilik</a>
    </div>
    <div>© 2026 Onyapp</div>
  </div>
</footer>
<script src="https://onyapp.app/js/i18n.js?v=7"></script>
<script src="https://onyapp.app/js/main.js?v=7"></script>
<script>
  function showLegal() {
    var lang = 'tr';
    try { lang = currentLang(); } catch (e) {
      try { lang = localStorage.getItem('ony-lang') === 'en' ? 'en' : 'tr'; } catch (e2) {}
    }
    document.documentElement.classList.toggle('lang-en', lang === 'en');
    document.title = lang === 'en' ? 'Onyapp Privacy Policy' : 'Onyapp Gizlilik Politikası';
  }
  document.addEventListener('ony-lang', showLegal);
  showLegal();
</script>
</body>
</html>
''';
