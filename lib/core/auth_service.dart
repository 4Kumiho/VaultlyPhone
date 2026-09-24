import '../data/crypto.dart';
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
  AuthResult.ok(this.session) : error = null;
  AuthResult.fail(this.error) : session = null;
  final Session? session;
  final String? error;
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
  AuthService(this._store, this._crypto);

  static const minPasswordLength = 6;
  static const _saltBytes = 16;

  final LocalStore _store;
  final VaultCrypto _crypto;

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
    return AuthResult.ok(Session(user, key, UserData.fromJson(json)));
  }

  /// Salva (cifrati) i dati della sessione.
  Future<void> save(Session session) async {
    final blob = await _crypto.encryptJson(session.key, session.data.toJson());
    session.user.data = blob;
    await _store.saveData(session.user.id, blob);
  }
}
