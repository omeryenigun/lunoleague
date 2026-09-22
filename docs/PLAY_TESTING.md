# Google Play ile Luno League test ettirme

Play, oyunu mağazada herkese açmadan test ettirmen için resmi kanallar verir. Testçi Play Store’dan (test sürümü olarak) indirir; güncellemeler aynı linkten gelir. Telefonda **davet edilen Google hesabı** Play Store’da açık olmalıdır.

Paket adı (`com.kelimelig.kelimelig`) ilk AAB yüklemesinde kilitlenir; değiştirilemez.

## Hangi kanal

| Kanal | Kim indirir | İnceleme | Ne zaman |
| --- | --- | --- | --- |
| **Internal testing** | Gmail listesi, en fazla ~100 kişi | Neredeyse yok; dakikalar | Kendin ve arkadaşlar. **Üretime geçiş sayılmaz.** |
| **Closed testing** | E-posta listesi veya Google Grubu | Mağaza kaydı tamam olmalı | Kontrollü grup. 13 Kas 2023 sonrası kişisel hesaplarda production öncesi şart: **en az 12 testçi, kesintisiz 14 gün**. |
| **Open testing** | Linki olan herkes | Politika incelemesi | Geniş beta. İlk günler için gerekmez. |

Akış: AAB yükle → Internal (hızlı QA) → Closed (12 kişi / 14 gün) → production başvurusu → mağaza. Closed sonrası isteğe bağlı Open testing.

## Play olmadan (daha hızlı)

Play hesabı (~25 USD) ve inceleme istemiyorsan:

```powershell
$env:Path = "C:\src\flutter\bin;$env:Path"
flutter build apk --release
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`. Drive / WhatsApp ile paylaş. Testçi “bilinmeyen kaynaklar” iznini açar. Play koruması, otomatik güncelleme ve gerçek mağaza davranışı yoktur.

Alternatif: [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) (e-posta listesi + indirme linki). Bu projede Firebase henüz yok.

## Bu repoda imza

Release hâlâ debug key ile imzalanır **ancak** `android/key.properties` varsa Play’e uygun upload keystore kullanılır.

1. Bir kez (Windows, Java `keytool` gerekir):

```powershell
powershell -ExecutionPolicy Bypass -File tool/create_upload_keystore.ps1
```

2. **Yedekle:** `android/upload-keystore.jks` ve `android/key.properties`. Kaybolursa aynı uygulama olarak güncelleme yüklenemez. İkisi de git’te yok.

3. AAB (Play Console’a bunu yükle):

```powershell
$env:Path = "C:\src\flutter\bin;$env:Path"
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`.

Arkadaşlara Play’siz APK için aynı imza ile:

```powershell
flutter build apk --release
```

`android/key.properties.example` alanların şablonudur; gerçek şifreleri commit etme.

## Play Console sırası (Internal)

1. [Play Console](https://play.google.com/console) geliştirici hesabı (kimlik + ~25 USD).
2. Uygulama oluştur. Paket: `com.kelimelig.kelimelig`.
3. **Test → Internal testing → Create new release** → `app-release.aab` yükle. Play App Signing’i aç (önerilen).
4. Testers e-posta listesine kendi Gmail’ini (ve arkadaşları) ekle.
5. Opt-in linkini paylaş. Testçi “Become a tester” der, sonra Store’dan yükler.

Internal için tam mağaza listing şart değil. Closed / Open / production için ikon, ekran görüntüleri, açıklama, gizlilik politikası URL’si ve içerik formları gerekir.

## Production notu

Yeni kişisel hesaplarda Internal yetmez. Closed testing’de 12 kişi 14 gün katıldıktan sonra Dashboard’dan production başvurusu açılır.

Ürün hatırlatması: Google girişi şu an yerel/sahte hesap; reklamlar mock. Mağaza metninde “Google ile giriş” kafa karıştırabilir; Closed öncesi gerçek OAuth veya metin düzeltmesi düşün.

Sürüm: `pubspec.yaml` içindeki `1.0.0+1` (`versionName+versionCode`). Her yüklemede `+` sonrası tam sayı artmalı.
