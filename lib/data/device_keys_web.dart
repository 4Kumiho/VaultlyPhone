import 'dart:js_interop';
import 'dart:typed_data';

import 'device_keys.dart';

@JS('vaultlyDevice.encrypt')
external JSPromise<JSUint8Array> _encrypt(String id, JSUint8Array data);

@JS('vaultlyDevice.decrypt')
external JSPromise<JSUint8Array?> _decrypt(String id, JSUint8Array data);

@JS('vaultlyDevice.remove')
external JSPromise<JSAny?> _remove(String id);

class PlatformDeviceKeys implements DeviceKeys {
  @override
  Future<Uint8List> encrypt(String id, List<int> data) async =>
      (await _encrypt(id, Uint8List.fromList(data).toJS).toDart).toDart;

  @override
  Future<List<int>?> decrypt(String id, List<int> data) async =>
      (await _decrypt(id, Uint8List.fromList(data).toJS).toDart)?.toDart;

  @override
  Future<void> remove(String id) => _remove(id).toDart;
}
