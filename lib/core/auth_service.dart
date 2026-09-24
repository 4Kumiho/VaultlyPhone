import '../data/crypto.dart';
import '../data/device_keys.dart';
import '../data/local_store.dart';
import 'countries.dart';
import 'models.dart';

/// Utente connesso. La chiave dei dati esiste solo qui, in memoria, finché dura la sessione.
class Session {
  Session(this.user, this.key, this.data);
  final UserRecord user;
  final List<int> key;
  final UserData data;
}

class AuthResult {
  AuthResult.ok(this.session)
      : error = null,
        pinDisabled = false;
  AuthResult.fail(this.error, {this.pinDisabled = false}) : session = null;
  final Session? session;
  final String? error;
  final bool pinDisabled; // il codice non vale più: serve la password
}

/// Email ripulita, o null se non valida.
String? normalizeEmail(String email) {
  final e = email.trim().toLowerCase();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e) ? e : null;
}

/// Numero senza prefisso (solo cifre), o null se non valido. Se l'utente ha scritto anche il
/// prefisso del paese scelto (+39 o 0039) viene tolto. Prefisso + numero: al massimo 15 cifre.
String? normalizePhone(String country, String phone) {
  final c = countryFor(country);
  if (c == null) return null;
  var p = phone.trim().replaceAll(RegExp(r'[\s\-./()]'), '');
  final dial = c.dial.substring(1);
  if (p.startsWith('+$dial')) {
    p = p.substring(dial.length + 1);
  } else if (p.startsWith('00$dial')) {
    p = p.substring(dial.length + 2);
  }
  if (!RegExp(r'^[0-9]{4,14}$').hasMatch(p) || dial.length + p.length > 15) return null;
  return p;
}

const phoneError = 'Inserisci un numero di telefono valido, es. 333 1234567.';

/// Registrazione e accesso. Stesse regole del desktop (AuthService), più email e telefono
/// obbligatori alla registrazione (salvati nel profilo, dentro i dati cifrati).
class AuthService {
  AuthService(this._store, this._crypto, [DeviceKeys? device]) : _device = device ?? DeviceKeys();

  static const minPasswordLength = 6;
  static const pinLength = 6;
  static const maxPinFailures = 5;
  static const _saltBytes = 16;

  final LocalStore _store;
  final VaultCrypto _crypto;
  final DeviceKeys _device;

  Future<AuthResult> register({
    required String username,
    required String email,
    String phoneCountry = 'IT',
    required String phone,
    required String password,
    required String confirm,
  }) async {
    final name = username.trim();
    if (name.isEmpty) return AuthResult.fail('Inserisci uno username.');
    final cleanEmail = normalizeEmail(email);
    if (cleanEmail == null) return AuthResult.fail("Inserisci un'email valida, es. nome@esempio.it.");
    final cleanPhone = normalizePhone(phoneCountry, phone);
    if (cleanPhone == null) return AuthResult.fail(phoneError);
    if (password.length < minPasswordLength) {
      return AuthResult.fail('La password deve avere almeno $minPasswordLength caratteri.');
    }
    if (password != confirm) return AuthResult.fail('Le password non coincidono.');
    if (await _store.findUser(name) != null) return AuthResult.fail('Username già in uso.');

    final salt = _crypto.randomBytes(_saltBytes);
    final dataSalt = _crypto.randomBytes(_saltBytes);
    final user = UserRecord(
      username: name,
      passwordHash: await _crypto.deriveKey(password, salt),
      salt: salt,
      dataSalt: dataSalt,
      iterations: _crypto.iterations,
      createdAt: DateTime.now(),
    );
    final key = await _crypto.deriveKey(password, dataSalt);
    final session = Session(user, key, UserData(profile: UserProfile(email: cleanEmail, phoneCountry: phoneCountry, phone: cleanPhone)));
    user.data = await _crypto.encryptJson(key, session.data.toJson());
    user.id = await _store.addUser(user);
    return AuthResult.ok(session);
  }

  Future<AuthResult> login(String username, String password) async {
    // Stesso messaggio per utente inesistente e password errata.
    const wrong = 'Username o password errati.';
    final user = await _store.findUser(username.trim());
    if (user == null) return AuthResult.fail(wrong);
    final crypto = VaultCrypto(iterations: user.iterations);
    final hash = await crypto.deriveKey(password, user.salt);
    if (!VaultCrypto.constantTimeEquals(hash, user.passwordHash)) return AuthResult.fail(wrong);

    final key = await crypto.deriveKey(password, user.dataSalt);
    final stored = user.data;
    final json = stored == null ? null : await crypto.decryptJson(key, stored);
    if (json == null) return AuthResult.fail('I dati di questo utente non sono leggibili.');
    if (user.pinFailures != 0) {
      user.pinFailures = 0;
      await _store.savePin(user);
    }
    return AuthResult.ok(Session(user, key, UserData.fromJson(json)));
  }

  // ---- Codice di sicurezza -------------------------------------------------------------
  //
  // La chiave dei dati viene cifrata con una chiave ricavata dal codice (PBKDF2, come la
  // password) e poi con la chiave del dispositivo, che il browser non lascia copiare: i codici
  // si possono provare solo da questo telefono, e dopo `maxPinFailures` errori il codice si
  // disattiva e serve la password.

  /// Tutti gli utenti di questo telefono (solo username e se hanno il codice).
  Future<List<UserRecord>> users() => _store.users();

  /// Motivo per cui il codice non va bene, o null.
  static String? pinProblem(String pin) {
    if (!RegExp('^[0-9]{$pinLength}\$').hasMatch(pin)) return 'Il codice deve avere $pinLength cifre.';
    if (pin.split('').toSet().length == 1) return 'Troppo facile: non usare la stessa cifra ripetuta.';
    const up = '0123456789012345', down = '9876543210987654'; // anche 890123, 210987...
    if (up.contains(pin) || down.contains(pin)) return 'Troppo facile: non usare cifre in fila come 123456.';
    return null;
  }

  static String _deviceId(UserRecord user) => 'user-${user.id}';

  /// Attiva (o cambia) il codice per l'utente della sessione.
  Future<String?> setPin(Session session, String pin, String confirm) async {
    final problem = pinProblem(pin);
    if (problem != null) return problem;
    if (pin != confirm) return 'I due codici non coincidono.';
    final user = session.user;
    final crypto = VaultCrypto(iterations: user.iterations);
    final salt = crypto.randomBytes(_saltBytes);
    final inner = await crypto.encrypt(await crypto.deriveKey(pin, salt), session.key);
    final blob = await _device.encrypt(_deviceId(user), inner);
    user
      ..pinSalt = salt
      ..pinBlob = blob
      ..pinFailures = 0;
    await _store.savePin(user);
    return null;
  }

  Future<void> removePin(UserRecord user) async {
    await _device.remove(_deviceId(user));
    user
      ..pinSalt = null
      ..pinBlob = null
      ..pinFailures = 0;
    await _store.savePin(user);
  }

  Future<AuthResult> unlockWithPin(String username, String pin) async {
    final user = await _store.findUser(username);
    if (user == null || !user.hasPin) {
      return AuthResult.fail('Il codice non è attivo per questo utente: accedi con la password.', pinDisabled: true);
    }
    final inner = await _device.decrypt(_deviceId(user), user.pinBlob!);
    if (inner == null) {
      await removePin(user);
      return AuthResult.fail('Il codice non è più valido su questo telefono: accedi con la password.', pinDisabled: true);
    }
    final crypto = VaultCrypto(iterations: user.iterations);
    final key = pinProblem(pin) == null ? await crypto.decrypt(await crypto.deriveKey(pin, user.pinSalt!), inner) : null;
    if (key == null) {
      user.pinFailures++;
      if (user.pinFailures >= maxPinFailures) {
        await removePin(user);
        return AuthResult.fail(
            'Codice sbagliato $maxPinFailures volte: per sicurezza il codice è stato disattivato. '
            'Accedi con la password.',
            pinDisabled: true);
      }
      await _store.savePin(user);
      final left = maxPinFailures - user.pinFailures;
      return AuthResult.fail(left == 1
          ? 'Codice errato. Ultimo tentativo, poi servirà la password.'
          : 'Codice errato. Restano $left tentativi.');
    }
    final json = user.data == null ? null : await crypto.decryptJson(key, user.data!);
    if (json == null) return AuthResult.fail('I dati di questo utente non sono leggibili.');
    if (user.pinFailures != 0) {
      user.pinFailures = 0;
      await _store.savePin(user);
    }
    return AuthResult.ok(Session(user, key, UserData.fromJson(json)));
  }

  /// Salva (cifrati) i dati della sessione.
  Future<void> save(Session session) async {
    final blob = await _crypto.encryptJson(session.key, session.data.toJson());
    session.user.data = blob;
    await _store.saveData(session.user.id, blob);
  }
}
