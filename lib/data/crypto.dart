import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Primitive crittografiche. Sul web `cryptography` usa la Web Crypto API del browser.
/// Stessi algoritmi del desktop: PBKDF2-SHA256 e AES-256-GCM.
class VaultCrypto {
  VaultCrypto({this.iterations = defaultIterations});

  static const defaultIterations = 100000;
  static const _nonceBytes = 12;
  static const _macBytes = 16;

  final int iterations;
  final _aes = AesGcm.with256bits();
  final _random = Random.secure();

  List<int> randomBytes(int count) => List<int>.generate(count, (_) => _random.nextInt(256));

  /// PBKDF2-SHA256 → 32 byte.
  Future<List<int>> deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
    final key = await pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  /// Cifra e autentica: nonce (12) | testo cifrato | tag (16).
  Future<Uint8List> encrypt(List<int> key, List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: SecretKey(key), nonce: randomBytes(_nonceBytes));
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// null se la chiave è sbagliata o i dati sono stati alterati.
  Future<List<int>?> decrypt(List<int> key, List<int> blob) async {
    if (blob.length < _nonceBytes + _macBytes) return null;
    final box = SecretBox(
      blob.sublist(_nonceBytes, blob.length - _macBytes),
      nonce: blob.sublist(0, _nonceBytes),
      mac: Mac(blob.sublist(blob.length - _macBytes)),
    );
    try {
      return await _aes.decrypt(box, secretKey: SecretKey(key));
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  Future<Uint8List> encryptJson(List<int> key, Map<String, dynamic> json) =>
      encrypt(key, utf8.encode(jsonEncode(json)));

  Future<Map<String, dynamic>?> decryptJson(List<int> key, List<int> blob) async {
    final plain = await decrypt(key, blob);
    if (plain == null) return null;
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  /// Confronto a tempo costante.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
