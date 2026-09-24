import 'dart:typed_data';

import 'device_keys_stub.dart' if (dart.library.js_interop) 'device_keys_web.dart' as impl;

/// Chiavi legate a questo dispositivo, una per utente, usate per il codice di sicurezza.
/// Sul web sono chiavi AES "non estraibili" del browser (web/device_key.js): si possono usare
/// ma non leggere o copiare. Nei test sono in memoria.
abstract class DeviceKeys {
  factory DeviceKeys() = impl.PlatformDeviceKeys;

  /// Cifra con una chiave nuova per `id`, che sostituisce la precedente.
  Future<Uint8List> encrypt(String id, List<int> data);

  /// null se la chiave non c'è o il contenuto non torna.
  Future<List<int>?> decrypt(String id, List<int> data);

  Future<void> remove(String id);
}
