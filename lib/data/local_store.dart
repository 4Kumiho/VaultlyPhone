import 'package:sembast/sembast_memory.dart';

import 'db_factory_stub.dart' if (dart.library.js_interop) 'db_factory_web.dart';

/// Utente registrato su questo telefono. `data` è il blob cifrato con tutti i suoi dati.
class UserRecord {
  UserRecord({
    this.id = 0,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.dataSalt,
    required this.iterations,
    required this.createdAt,
    this.data,
    this.pinSalt,
    this.pinBlob,
    this.pinFailures = 0,
  });

  int id;
  final String username;
  final List<int> passwordHash;
  final List<int> salt;
  final List<int> dataSalt; // salt della chiave dei dati, diverso da quello del login
  final int iterations;
  final DateTime createdAt;
  List<int>? data;

  /// Codice di sicurezza: chiave dei dati cifrata col codice e poi con la chiave del dispositivo.
  List<int>? pinSalt;
  List<int>? pinBlob;
  int pinFailures; // codici sbagliati di fila

  bool get hasPin => pinBlob != null;

  Map<String, Object?> toMap() => {
        'username': username,
        'usernameLower': username.toLowerCase(),
        'passwordHash': passwordHash,
        'salt': salt,
        'dataSalt': dataSalt,
        'iterations': iterations,
        'createdAt': createdAt.toIso8601String(),
        'data': data,
        'pinSalt': pinSalt,
        'pinBlob': pinBlob,
        'pinFailures': pinFailures,
      };

  factory UserRecord.fromMap(int id, Map<String, Object?> m) => UserRecord(
        id: id,
        username: m['username'] as String,
        passwordHash: (m['passwordHash'] as List).cast<int>(),
        salt: (m['salt'] as List).cast<int>(),
        dataSalt: (m['dataSalt'] as List).cast<int>(),
        iterations: m['iterations'] as int,
        createdAt: DateTime.parse(m['createdAt'] as String),
        data: (m['data'] as List?)?.cast<int>(),
        pinSalt: (m['pinSalt'] as List?)?.cast<int>(),
        pinBlob: (m['pinBlob'] as List?)?.cast<int>(),
        pinFailures: (m['pinFailures'] as int?) ?? 0,
      );
}

/// Archivio locale: sul web IndexedDB del browser (dati solo sul telefono), nei test in memoria.
class LocalStore {
  LocalStore._(this._db);

  static const _dbName = 'vaultly.db';
  final Database _db;
  final _users = intMapStoreFactory.store('users');

  static Future<LocalStore> open() async => LocalStore._(await appDatabaseFactory.openDatabase(_dbName));

  /// Archivio vuoto in memoria, per i test.
  static Future<LocalStore> openInMemory() async =>
      LocalStore._(await databaseFactoryMemory.openDatabase(sembastInMemoryDatabasePath));

  Future<UserRecord?> findUser(String username) async {
    final record = await _users.findFirst(
      _db,
      finder: Finder(filter: Filter.equals('usernameLower', username.toLowerCase())),
    );
    return record == null ? null : UserRecord.fromMap(record.key, record.value);
  }

  Future<int> addUser(UserRecord user) => _users.add(_db, user.toMap());

  /// Tutti gli utenti di questo telefono, in ordine di creazione.
  Future<List<UserRecord>> users() async {
    final records = await _users.find(_db, finder: Finder(sortOrders: [SortOrder(Field.key)]));
    return [for (final r in records) UserRecord.fromMap(r.key, r.value)];
  }

  Future<void> savePin(UserRecord user) => _users.record(user.id).update(_db, {
        'pinSalt': user.pinSalt,
        'pinBlob': user.pinBlob,
        'pinFailures': user.pinFailures,
      });

  Future<void> saveData(int userId, List<int> data) =>
      _users.record(userId).update(_db, {'data': data});

  Future<void> close() => _db.close();
}
