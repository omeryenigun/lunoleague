import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

class PickedCsv {
  const PickedCsv({required this.name, required this.text, this.tooBig = false, this.notCsv = false});

  final String name;
  final String text;
  final bool tooBig;
  final bool notCsv;
}

Future<String?> pickWordCsv() {
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv';
  final done = Completer<String?>();
  input.addEventListener(
    'change',
    (Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        if (!done.isCompleted) done.complete(null);
        return;
      }
      file.text().toDart.then((value) {
        if (!done.isCompleted) done.complete(value.toDart);
      });
    }.toJS,
  );
  input.click();
  return done.future;
}

Future<PickedCsv?> pickCsvFile() {
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv';
  final done = Completer<PickedCsv?>();
  input.addEventListener(
    'change',
    (Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        if (!done.isCompleted) done.complete(null);
        return;
      }
      final name = file.name;
      if (!name.toLowerCase().endsWith('.csv')) {
        if (!done.isCompleted) done.complete(PickedCsv(name: name, text: '', notCsv: true));
        return;
      }
      if (file.size > 10 * 1024 * 1024) {
        if (!done.isCompleted) done.complete(PickedCsv(name: name, text: '', tooBig: true));
        return;
      }
      file.text().toDart.then((value) {
        if (!done.isCompleted) done.complete(PickedCsv(name: name, text: value.toDart));
      });
    }.toJS,
  );
  input.click();
  return done.future;
}

void downloadTextFile(String filename, String content) {
  final bytes = Uint8List.fromList(utf8.encode('\uFEFF$content'));
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
