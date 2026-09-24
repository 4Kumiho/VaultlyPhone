// Modelli dei dati. Importi sempre in unità minime intere (centesimi), mai double.

enum TxType { income, expense }

/// Scadenza di un'etichetta: su quale periodo si conta la spesa rispetto al tetto.
/// Una tantum (es. "viaggio a Rimini": vale solo tra due date) o ricorrente (es. "autostrada":
/// il conteggio riparte ogni periodo e si tiene lo storico dei periodi passati).
enum TagKind { oneShot, recurring }

/// Durata di un'etichetta una tantum a partire dalla data di inizio.
enum TagSpan { week, month, custom }

/// Unità della ricorrenza: ogni `every` giorni / settimane (da lunedì) / mesi (dal 1°) / anni (dal 1° gennaio).
enum TagUnit { day, week, month, year }

class Currency {
  const Currency(this.code, this.symbol, this.minorUnits);
  final String code;
  final String symbol;
  final int minorUnits;
}

/// Stesse valute del desktop.
const kCurrencies = [
  Currency('EUR', '€', 2),
  Currency('USD', r'$', 2),
  Currency('GBP', '£', 2),
  Currency('CHF', 'CHF', 2),
  Currency('JPY', '¥', 0),
];

Currency currencyFor(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

class Category {
  const Category(this.id, this.name, this.type);
  final int id;
  final String name;
  final TxType type;
}

/// Stesse categorie (e stesso ordine) del desktop.
const kCategories = [
  Category(1, 'Stipendio', TxType.income),
  Category(2, 'Regali', TxType.income),
  Category(3, 'Rimborsi', TxType.income),
  Category(4, 'Investimenti', TxType.income),
  Category(5, 'Altro', TxType.income),
  Category(6, 'Casa', TxType.expense),
  Category(7, 'Spesa', TxType.expense),
  Category(8, 'Trasporti', TxType.expense),
  Category(9, 'Bollette', TxType.expense),
  Category(10, 'Salute', TxType.expense),
  Category(11, 'Svago', TxType.expense),
  Category(12, 'Ristoranti', TxType.expense),
  Category(13, 'Abbonamenti', TxType.expense),
  Category(14, 'Altro', TxType.expense),
];

Category? categoryFor(int id) {
  for (final c in kCategories) {
    if (c.id == id) return c;
  }
  return null;
}

List<Category> categoriesOf(TxType type) => kCategories.where((c) => c.type == type).toList();

class Account {
  Account({
    required this.id,
    required this.name,
    required this.currency,
    required this.initialBalance,
    required this.createdAt,
  });

  final String id;
  String name;
  final String currency; // non si cambia dopo la creazione
  int initialBalance;
  final DateTime createdAt;

  Account copy() =>
      Account(id: id, name: name, currency: currency, initialBalance: initialBalance, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'initialBalance': initialBalance,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        currency: j['currency'] as String,
        initialBalance: j['initialBalance'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class Txn {
  Txn({
    required this.id,
    required this.accountId,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.occurredAt,
    this.description = '',
    List<String>? tags,
  }) : tags = tags ?? [];

  final String id;
  final String accountId;
  TxType type;
  int categoryId;
  int amount; // > 0, il segno lo dà `type`
  DateTime occurredAt;
  String description;
  List<String> tags; // nomi delle etichette, in ordine alfabetico

  int get signedAmount => type == TxType.income ? amount : -amount;

  Txn copy() => Txn(
        id: id,
        accountId: accountId,
        type: type,
        categoryId: categoryId,
        amount: amount,
        occurredAt: occurredAt,
        description: description,
        tags: List.of(tags),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'type': type.name,
        'categoryId': categoryId,
        'amount': amount,
        'occurredAt': occurredAt.toIso8601String(),
        'description': description,
        'tags': tags,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        accountId: j['accountId'] as String,
        type: TxType.values.byName(j['type'] as String),
        categoryId: j['categoryId'] as int,
        amount: j['amount'] as int,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        description: (j['description'] as String?) ?? '',
        tags: ((j['tags'] as List?) ?? const []).cast<String>().toList(),
      );
}

class Tag {
  Tag({
    required this.id,
    required this.name,
    this.kind = TagKind.recurring,
    DateTime? start,
    this.end,
    this.span = TagSpan.custom,
    this.unit = TagUnit.month,
    this.every = 1,
    this.budget,
    this.currency = 'EUR',
  }) : start = start ?? _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  final String id;
  String name;
  TagKind kind;

  /// Una tantum: primo giorno. Ricorrente: giorno da cui si contano i periodi (conta solo se `every` > 1).
  DateTime start;

  /// Solo una tantum: ultimo giorno (compreso).
  DateTime? end;
  TagSpan span; // una tantum
  TagUnit unit; // ricorrente
  int every; // ricorrente, >= 1
  int? budget; // tetto per periodo (ricorrente) o per l'intera durata (una tantum), in unità minime
  String currency; // valuta in cui si contano le spese

  bool get recurring => kind == TagKind.recurring;

  Tag copy() => Tag(
        id: id,
        name: name,
        kind: kind,
        start: start,
        end: end,
        span: span,
        unit: unit,
        every: every,
        budget: budget,
        currency: currency,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'span': span.name,
        'unit': unit.name,
        'every': every,
        'budget': budget,
        'currency': currency,
      };

  factory Tag.fromJson(Map<String, dynamic> j) {
    DateTime? date(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    final tag = Tag(
      id: j['id'] as String,
      name: j['name'] as String,
      kind: TagKind.values.asNameMap()[j['kind']] ?? TagKind.recurring,
      start: date('start'),
      end: date('end'),
      span: TagSpan.values.asNameMap()[j['span']] ?? TagSpan.custom,
      unit: TagUnit.values.asNameMap()[j['unit']] ?? TagUnit.month,
      every: (j['every'] as int?) ?? 1,
      budget: j['budget'] as int?,
      currency: (j['currency'] as String?) ?? 'EUR',
    );
    // Formato precedente ("period": none / weekly / monthly / range).
    switch (j['period']) {
      case 'weekly':
        tag.unit = TagUnit.week;
      case 'range':
        tag.kind = TagKind.oneShot;
    }
    return tag;
  }
}

class VaultItem {
  VaultItem({
    required this.id,
    required this.title,
    this.url = '',
    this.username = '',
    this.password = '',
    this.notes = '',
    required this.updatedAt,
  });

  final String id;
  String title;
  String url;
  String username;
  String password;
  String notes;
  DateTime updatedAt;

  VaultItem copy() => VaultItem(
        id: id,
        title: title,
        url: url,
        username: username,
        password: password,
        notes: notes,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'username': username,
        'password': password,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
        id: j['id'] as String,
        title: j['title'] as String,
        url: (j['url'] as String?) ?? '',
        username: (j['username'] as String?) ?? '',
        password: (j['password'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// Contatti dell'utente. Stanno dentro i dati cifrati: senza la password non si leggono.
class UserProfile {
  UserProfile({this.email = '', this.phoneCountry = 'IT', this.phone = '', this.avatar, this.avatarColor = 0});
  String email;
  String phoneCountry; // ISO del paese del prefisso (il +1 è di più paesi)
  String phone; // numero senza prefisso, solo cifre
  String? avatar; // foto quadrata PNG in base64 (cifrata con il resto dei dati)
  int avatarColor; // colore dell'avatar con l'iniziale, indice in kAvatarColors

  Map<String, dynamic> toJson() => {
        'email': email,
        'phoneCountry': phoneCountry,
        'phone': phone,
        'avatar': avatar,
        'avatarColor': avatarColor,
      };

  factory UserProfile.fromJson(Map<String, dynamic>? j) => UserProfile(
        email: (j?['email'] as String?) ?? '',
        phoneCountry: (j?['phoneCountry'] as String?) ?? 'IT',
        phone: (j?['phone'] as String?) ?? '',
        avatar: j?['avatar'] as String?,
        avatarColor: (j?['avatarColor'] as int?) ?? 0,
      );
}

/// Colori per l'avatar con l'iniziale (ARGB).
const kAvatarColors = [0xFF5B8CFF, 0xFF34D399, 0xFFF5A524, 0xFFFF6B6B, 0xFFB57BFF, 0xFF2EC5CE, 0xFFFF8FC7, 0xFF8B93A7];

/// Tutti i dati di un utente: vengono salvati insieme, cifrati con la sua chiave.
class UserData {
  UserData({UserProfile? profile, List<Account>? accounts, List<Txn>? transactions, List<Tag>? tags, List<VaultItem>? vault})
      : profile = profile ?? UserProfile(),
        accounts = accounts ?? [],
        transactions = transactions ?? [],
        tags = tags ?? [],
        vault = vault ?? [];

  static const formatVersion = 1;

  final UserProfile profile;
  final List<Account> accounts;
  final List<Txn> transactions;
  final List<Tag> tags;
  final List<VaultItem> vault;

  Map<String, dynamic> toJson() => {
        'version': formatVersion,
        'profile': profile.toJson(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'tags': tags.map((t) => t.toJson()).toList(),
        'vault': vault.map((v) => v.toJson()).toList(),
      };

  factory UserData.fromJson(Map<String, dynamic> j) => UserData(
        profile: UserProfile.fromJson(j['profile'] as Map<String, dynamic>?),
        accounts: ((j['accounts'] as List?) ?? const [])
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList(),
        transactions: ((j['transactions'] as List?) ?? const [])
            .map((e) => Txn.fromJson(e as Map<String, dynamic>))
            .toList(),
        tags: ((j['tags'] as List?) ?? const []).map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList(),
        vault: ((j['vault'] as List?) ?? const [])
            .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
