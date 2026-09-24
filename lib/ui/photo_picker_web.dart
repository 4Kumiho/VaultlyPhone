import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Apre la scelta della foto del telefono (galleria, fotocamera o file) e ne restituisce i byte.
/// Il file viene letto nel browser: non viene caricato da nessuna parte.
Future<Uint8List?> pickPhoto() {
  final completer = Completer<Uint8List?>();
  void done(Uint8List? bytes) {
    if (!completer.isCompleted) completer.complete(bytes);
  }

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  input.addEventListener(
      'change',
      ((web.Event _) {
        final file = input.files?.item(0);
        if (file == null) return done(null);
        file.arrayBuffer().toDart.then((buffer) => done(buffer.toDart.asUint8List()), onError: (_) => done(null));
      }).toJS);
  input.addEventListener('cancel', ((web.Event _) => done(null)).toJS);
  input.click();
  return completer.future;
}
