class WordImportResult {
  const WordImportResult({
    required this.imported,
    required this.skipped,
    required this.invalid,
  });

  final int imported;
  final int skipped;
  final int invalid;

  Map<String, dynamic> toMap() => {
        'imported': imported,
        'skipped': skipped,
        'invalid': invalid,
      };

  factory WordImportResult.fromMap(Map<dynamic, dynamic> map) {
    int read(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.parse('$value');
    }

    return WordImportResult(
      imported: read('imported'),
      skipped: read('skipped'),
      invalid: read('invalid'),
    );
  }
}
