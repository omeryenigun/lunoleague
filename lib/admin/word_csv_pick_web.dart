import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

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
