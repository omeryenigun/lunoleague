import 'package:kelimelig/core/utils/turkish_text.dart';

/// Exact Turkish headwords. Substrings are not matched, so lookalikes stay.
const trProfanity = <String>{
  'SİK',
  'SİKMEK',
  'SİKİŞ',
  'SİKİŞMEK',
  'SİKTİR',
  'SİKTİRMEK',
  'SİKER',
  'SİKEYİM',
  'SİKİK',
  'YARRAK',
  'YARAK',
  'TAŞAK',
  'TAŞŞAK',
  'DÖL',
  'AMCİK',
  'AMCIK',
  'GÖT',
  'GÖTÜN',
  'GÖTLEK',
  'GÖTVEREN',
  'OROSPU',
  'OROSPUÇOCUĞU',
  'PEZEVENK',
  'PİÇ',
  'PUŞT',
  'İBNE',
  'GAVAT',
  'KAHPE',
  'KALTAK',
  'ŞEREFSİZ',
};

bool isTurkishProfanity(String word) =>
    trProfanity.contains(TurkishText.toUpper(word));
