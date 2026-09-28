Future<String?> pickWordCsv() async => null;

class PickedCsv {
  const PickedCsv({required this.name, required this.text, this.tooBig = false, this.notCsv = false});

  final String name;
  final String text;
  final bool tooBig;
  final bool notCsv;
}

Future<PickedCsv?> pickCsvFile() async => null;

void downloadTextFile(String filename, String content) {}
