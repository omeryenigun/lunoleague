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
  <style>
    body { font-family: Georgia, serif; max-width: 46rem; margin: 2rem auto; padding: 0 1.25rem 3rem; line-height: 1.55; color: #1a1a1a; }
    h1 { font-size: 1.7rem; }
    h2 { font-size: 1.2rem; margin-top: 1.8rem; }
    h3 { font-size: 1.05rem; margin-top: 1.4rem; }
    h4 { font-size: 1rem; margin-top: 1.2rem; }
    p, li { font-size: 1rem; }
    table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
    th, td { border: 1px solid #ccc; padding: 0.45rem 0.6rem; text-align: left; vertical-align: top; }
    hr { border: 0; border-top: 1px solid #ddd; margin: 1.5rem 0; }
  </style>
</head>
<body>
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
</body>
</html>
''';
