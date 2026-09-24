import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analytics.dart';
import 'auth_service.dart';
import 'countries.dart';
import 'models.dart';

/// Nome di etichetta ripulito: spazi in più e '#' iniziali tolti.
String normalizeTagName(String name) {
  var s = name.trim();
  while (s.startsWith('#')) {
    s = s.substring(1);
  }
  return s.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Dati dell'utente connesso, con le stesse regole di validazione del desktop.
/// Ogni modifica viene salvata subito (cifrata) e notificata all'interfaccia.
/// I metodi che modificano restituiscono un messaggio d'errore, o null se è andato tutto bene.
class AppData extends ChangeNotifier {
  AppData(this._auth, this._session);

  static const maxTags = 10;
  static const maxTagLength = 30;

  final AuthService _auth;
  final Session _session;
  final _random = Random.secure();

  String get username => _session.user.username;
  String get email => _d.profile.email;
  String get phoneCountry => _d.profile.phoneCountry;
  String get phone => _d.profile.phone; // senza prefisso

  /// Numero completo da mostrare, es. "+39 3331234567".
  String get phoneFull => phone.isEmpty ? '' : '${countryFor(phoneCountry)?.dial ?? ''} $phone'.trim();
  UserData get _d => _session.data;

  // ---- Lettura -------------------------------------------------------------------------

  // Si restituiscono sempre copie: i dati cambiano solo con i metodi save*/delete*.

  List<Account> get accounts =>
      _d.accounts.map((a) => a.copy()).toList(); // ordine di creazione

  Account? account(String id) => _d.accounts.where((a) => a.id == id).firstOrNull?.copy();

  /// Movimenti di un conto, dal più recente.
  List<Txn> transactionsOf(String accountId) =>
      _d.transactions.where((t) => t.accountId == accountId).map((t) => t.copy()).toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  int balanceOf(Account account) => Analytics.currentBalance(account, _d.transactions);

  List<Tag> get tags => _d.tags.map((t) => t.copy()).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<String> get tagNames => tags.map((t) => t.name).toList();

  int tagUsage(Tag tag) =>
      _d.transactions.where((t) => t.tags.any((x) => x.toLowerCase() == tag.name.toLowerCase())).length;

  Tag? tagNamed(String name) => _d.tags.where((t) => t.name.toLowerCase() == name.toLowerCase()).firstOrNull?.copy();

  /// Etichette che un movimento in data `at` può avere (le una tantum solo tra le loro date).
  List<String> tagNamesFor(DateTime at) => tags.where((t) => Analytics.fitsDate(t, at)).map((t) => t.name).toList();

  BudgetStatus budgetStatus(Tag tag, {DateTime? now}) =>
      Analytics.budgetStatus(tag, _d.accounts, _d.transactions, now ?? DateTime.now());

  /// Periodo in corso e precedenti (ricorrenti), dal più recente.
  List<BudgetStatus> tagHistory(Tag tag, {DateTime? now}) =>
      Analytics.history(tag, _d.accounts, _d.transactions, now ?? DateTime.now());

  /// Uscite con l'etichetta in [from, to] sui conti nella sua valuta (quelle che contano), dalla più recente.
  List<Txn> tagExpenses(Tag tag, DateTime from, DateTime to) => _d.transactions
      .where((t) =>
          t.type == TxType.expense &&
          account(t.accountId)?.currency == tag.currency &&
          !t.occurredAt.isBefore(from) &&
          !t.occurredAt.isAfter(to) &&
          t.tags.any((x) => x.toLowerCase() == tag.name.toLowerCase()))
      .map((t) => t.copy())
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  List<VaultItem> get vault =>
      _d.vault.map((v) => v.copy()).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  /// Valute dei conti dell'utente (per il tetto delle etichette).
  List<Currency> get accountCurrencies {
    final codes = {for (final a in _d.accounts) a.currency};
    final list = kCurrencies.where((c) => codes.contains(c.code)).toList();
    return list.isEmpty ? List.of(kCurrencies) : list;
  }

  // ---- Codice di sicurezza ---------------------------------------------------------------

  Future<String?> changePin(String pin, String confirm) => _auth.setPin(_session, pin, confirm);

  // ---- Profilo -------------------------------------------------------------------------

  Future<String?> saveProfile({required String email, required String phoneCountry, required String phone}) async {
    final cleanEmail = normalizeEmail(email);
    if (cleanEmail == null) return "Inserisci un'email valida, es. nome@esempio.it.";
    final cleanPhone = normalizePhone(phoneCountry, phone);
    if (cleanPhone == null) return phoneError;
    _d.profile
      ..email = cleanEmail
      ..phoneCountry = phoneCountry
      ..phone = cleanPhone;
    return _commit();
  }

  // ---- Conti ---------------------------------------------------------------------------

  Future<String?> saveAccount({String? id, required String name, String? currency, required int initialBalance}) async {
    final clean = name.trim();
    if (clean.isEmpty) return 'Inserisci un nome per il conto.';
    if (_d.accounts.any((a) => a.id != id && a.name.toLowerCase() == clean.toLowerCase())) {
      return 'Hai già un conto con questo nome.';
    }
    if (id == null) {
      _d.accounts.add(Account(
        id: _newId(),
        name: clean,
        currency: currency ?? 'EUR',
        initialBalance: initialBalance,
        createdAt: DateTime.now(),
      ));
    } else {
      final a = _d.accounts.where((x) => x.id == id).firstOrNull;
      if (a == null) return 'Conto non trovato.';
      a
        ..name = clean
        ..initialBalance = initialBalance;
    }
    return _commit();
  }

  /// Elimina il conto e tutti i suoi movimenti.
  Future<String?> deleteAccount(String id) async {
    _d.accounts.removeWhere((a) => a.id == id);
    _d.transactions.removeWhere((t) => t.accountId == id);
    return _commit();
  }

  // ---- Movimenti -----------------------------------------------------------------------

  /// Crea (se `draft.id` è vuoto) o aggiorna un movimento. Le etichette devono esistere già
  /// (si creano dalla scheda etichetta, scegliendo se è una tantum o ricorrente).
  Future<String?> saveTransaction(Txn draft) async {
    if (account(draft.accountId) == null) return 'Conto non trovato.';
    if (draft.amount <= 0) return "L'importo deve essere maggiore di zero.";
    final category = categoryFor(draft.categoryId);
    if (category == null) return 'Scegli una categoria.';
    if (category.type != draft.type) return 'La categoria non corrisponde al tipo di movimento.';

    final tags = <String>[];
    for (final raw in draft.tags) {
      final tag = normalizeTagName(raw);
      if (tag.isEmpty) continue;
      if (tag.length > maxTagLength) return "Un'etichetta può avere al massimo $maxTagLength caratteri.";
      if (!tags.any((t) => t.toLowerCase() == tag.toLowerCase())) tags.add(tag);
    }
    if (tags.length > maxTags) return 'Puoi usare al massimo $maxTags etichette per movimento.';
    final index = draft.id.isEmpty ? -1 : _d.transactions.indexWhere((t) => t.id == draft.id);
    if (draft.id.isNotEmpty && index < 0) return 'Movimento non trovato.';
    if (index >= 0 && _d.transactions[index].accountId != draft.accountId) return 'Un movimento non può cambiare conto.';

    // Si usa il nome dell'etichetta (con le sue maiuscole); una tantum solo tra le sue date.
    final resolved = <String>[];
    for (final name in tags) {
      final tag = _d.tags.where((t) => t.name.toLowerCase() == name.toLowerCase()).firstOrNull;
      if (tag == null) return "L'etichetta \"$name\" non esiste: creala prima.";
      if (!Analytics.fitsDate(tag, draft.occurredAt)) {
        return "L'etichetta \"${tag.name}\" vale solo dal ${_date(tag.start)} al ${_date(tag.end!)}.";
      }
      resolved.add(tag.name);
    }
    resolved.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final saved = draft.copy()
      ..description = draft.description.trim()
      ..tags = resolved;
    if (draft.id.isEmpty) {
      _d.transactions.add(Txn(
        id: _newId(),
        accountId: saved.accountId,
        type: saved.type,
        categoryId: saved.categoryId,
        amount: saved.amount,
        occurredAt: saved.occurredAt,
        description: saved.description,
        tags: saved.tags,
      ));
    } else {
      _d.transactions[index] = saved;
    }
    return _commit();
  }

  Future<String?> deleteTransaction(String id) async {
    _d.transactions.removeWhere((t) => t.id == id);
    return _commit();
  }

  // ---- Etichette -----------------------------------------------------------------------

  Future<String?> saveTag(Tag draft) async {
    final name = normalizeTagName(draft.name);
    if (name.isEmpty) return "Inserisci un nome per l'etichetta.";
    if (name.length > maxTagLength) return 'Il nome può avere al massimo $maxTagLength caratteri.';
    if (_d.tags.any((t) => t.id != draft.id && t.name.toLowerCase() == name.toLowerCase())) {
      return "Hai già un'etichetta con questo nome.";
    }
    final i = _d.tags.indexWhere((t) => t.id == draft.id);
    if (draft.id.isNotEmpty && i < 0) return 'Etichetta non trovata.';
    final tag = draft.copy()
      ..name = name
      ..start = DateTime(draft.start.year, draft.start.month, draft.start.day);
    if (!kCurrencies.any((c) => c.code == tag.currency)) return 'Scegli la valuta.';
    if (tag.budget != null && tag.budget! <= 0) return 'Il tetto di spesa deve essere maggiore di zero.';

    if (tag.recurring) {
      if (tag.every < 1 || tag.every > 365) return 'La ricorrenza deve essere tra 1 e 365.';
      tag.end = null;
    } else {
      tag
        ..end = Analytics.oneShotEnd(tag.start, tag.span, draft.end)
        ..every = 1;
      if (tag.end!.isBefore(tag.start)) return 'La data di fine deve essere uguale o successiva a quella di inizio.';
      // I movimenti che hanno già l'etichetta devono restare dentro le date.
      if (i >= 0) {
        final oldName = _d.tags[i].name.toLowerCase();
        final outside = _d.transactions
            .where((t) => t.tags.any((x) => x.toLowerCase() == oldName) && !Analytics.fitsDate(tag, t.occurredAt))
            .length;
        if (outside > 0) {
          return outside == 1
              ? "1 movimento con questa etichetta è fuori da queste date: cambia le date o togli l'etichetta dal movimento."
              : "$outside movimenti con questa etichetta sono fuori da queste date: cambia le date o togli l'etichetta dai movimenti.";
        }
      }
    }

    if (i < 0) {
      final created = tag.copy();
      _d.tags.add(Tag(
        id: _newId(),
        name: created.name,
        kind: created.kind,
        start: created.start,
        end: created.end,
        span: created.span,
        unit: created.unit,
        every: created.every,
        budget: created.budget,
        currency: created.currency,
      ));
    } else {
      // Rinominata: il nuovo nome va anche sui movimenti.
      final oldName = _d.tags[i].name.toLowerCase();
      for (final t in _d.transactions) {
        t.tags = [for (final x in t.tags) x.toLowerCase() == oldName ? tag.name : x]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _d.tags[i] = tag;
    }
    return _commit();
  }

  /// Elimina l'etichetta e la toglie dai movimenti (i movimenti restano).
  Future<String?> deleteTag(String id) async {
    final tag = _d.tags.where((t) => t.id == id).firstOrNull;
    if (tag == null) return 'Etichetta non trovata.';
    final name = tag.name.toLowerCase();
    for (final t in _d.transactions) {
      t.tags = t.tags.where((x) => x.toLowerCase() != name).toList();
    }
    _d.tags.removeWhere((t) => t.id == id);
    return _commit();
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ---- Area password -------------------------------------------------------------------

  Future<String?> saveVaultItem(VaultItem draft) async {
    final item = draft.copy()
      ..title = draft.title.trim()
      ..url = draft.url.trim()
      ..username = draft.username.trim()
      ..notes = draft.notes.trim()
      ..updatedAt = DateTime.now();
    if (item.title.isEmpty) return 'Inserisci un nome, es. "Gmail".';
    if (item.username.isEmpty && item.password.isEmpty) return 'Inserisci almeno lo username o la password.';
    final i = _d.vault.indexWhere((v) => v.id == draft.id);
    if (i < 0) {
      _d.vault.add(VaultItem(
        id: _newId(),
        title: item.title,
        url: item.url,
        username: item.username,
        password: item.password,
        notes: item.notes,
        updatedAt: item.updatedAt,
      ));
    } else {
      _d.vault[i] = item;
    }
    return _commit();
  }

  Future<String?> deleteVaultItem(String id) async {
    _d.vault.removeWhere((v) => v.id == id);
    return _commit();
  }

  /// Password casuale con minuscole, maiuscole, cifre e (se richiesto) simboli, senza caratteri ambigui.
  String generatePassword({int length = 20, bool symbols = true}) {
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const symbolChars = '!@#\$%&*-_=+?';
    final classes = [lower, upper, digits, if (symbols) symbolChars];
    final all = classes.join();
    while (true) {
      final pw = List.generate(max(length, classes.length), (_) => all[_random.nextInt(all.length)]).join();
      if (classes.every((c) => pw.split('').any(c.contains))) return pw;
    }
  }

  // ---- Interni -------------------------------------------------------------------------

  String _newId() => List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Future<String?> _commit() async {
    try {
      await _auth.save(_session);
    } catch (_) {
      return 'Impossibile salvare i dati sul telefono.';
    }
    notifyListeners();
    return null;
  }
}
