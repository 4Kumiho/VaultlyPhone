import 'dart:typed_data';

import 'crypto.dart';
import 'device_keys.dart';

/// Fuori dal browser (test): chiavi casuali in memoria, come quelle del browser ma non persistenti.
class PlatformDeviceKeys implements DeviceKeys {
  final _crypto = VaultCrypto();
  final _keys = <String, List<int>>{};

  @override
  Future<Uint8List> encrypt(String id, List<int> data) {
    final key = _keys[id] = _crypto.randomBytes(32);
    return _crypto.encrypt(key, data);
  }

  @override
  Future<List<int>?> decrypt(String id, List<int> data) async {
    final key = _keys[id];
    return key == null ? null : _crypto.decrypt(key, data);
  }

  @override
  Future<void> remove(String id) async => _keys.remove(id);
}
