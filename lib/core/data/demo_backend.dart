import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../format/formatters.dart';
import 'backend.dart';
import 'csv_export.dart';
import 'local_store.dart';
import 'models.dart';
import '../l10n/l10n.dart';

/// The automatic control, as the demo runs it. The real one is the SQL
/// function `submit_expense` (supabase/migrations): keep both in step.
List<ExpenseFlag> controlExpense(
  Expense expense, {
  required List<PolicyRule> policies,
  required Iterable<Expense> others,
  required DateTime today,
}) {
  final flags = <ExpenseFlag>[];
  final rule = policies.where((p) => p.category == expense.category);
  if (rule.isNotEmpty) {
    final over = expense.amountCents - rule.first.limitCents;
    if (over > 0) {
      flags.add(
        ExpenseFlag(
          FlagKind.policy,
          'Plafond ${expense.category} dépassé de ${formatMad(over)}',
        ),
      );
    }
    if (rule.first.receiptRequired && !expense.hasReceipt) {
      flags.add(const ExpenseFlag(FlagKind.policy, 'Justificatif manquant'));
    }
  }
  final duplicate = others.any(
    (o) =>
        o.id != expense.id &&
        o.employeeId == expense.employeeId &&
        o.date == expense.date &&
        o.amountCents == expense.amountCents &&
        o.status != ExpenseStatus.draft &&
        o.status != ExpenseStatus.rejected,
  );
  if (duplicate) {
    flags.add(
      const ExpenseFlag(
        FlagKind.duplicate,
        'Même date et même montant qu’une dépense déjà déclarée',
      ),
    );
  }
  if (expense.category == 'Autre') {
    flags.add(const ExpenseFlag(FlagKind.ambiguity, 'Catégorie à préciser'));
  }
  if (expense.date != null && today.difference(expense.date!).inDays > 60) {
    flags.add(
      const ExpenseFlag(
        FlagKind.ambiguity,
        'Dépense datée de plus de 60 jours',
      ),
    );
  }
  return flags;
}

class _Invitation {
  const _Invitation(this.email, this.role, this.companyId, this.companyName);
  final String email;
  final UserRole role;
  final String companyId;
  final String companyName;
}

/// REMBO without a server: real accounts, companies and expenses, kept on
/// this phone by a [LocalStore]. Same rules as the Supabase functions.
/// Several people can use it by signing in one after the other on the
/// same phone; nothing is shared between phones.
class LocalBackend extends RemboBackend {
  LocalBackend({
    DateTime Function()? clock,
    this.latency = Duration.zero,
    LocalStore? store,
  }) : _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _store = store;

  /// Opens the data saved on this phone, or starts empty.
  static Future<LocalBackend> open(
    LocalStore store, {
    DateTime Function()? clock,
  }) async {
    final backend = LocalBackend(store: store, clock: clock);
    await backend._load();
    return backend;
  }

  /// Simulated network delay.
  final Duration latency;

  final DateTime Function() _clock;
  final LocalStore? _store;

  static const _defaultPolicies = [
    PolicyRule(category: 'Repas', limitCents: 20000),
    // Petits taxis rarely give a receipt.
    PolicyRule(
      category: 'Transport',
      limitCents: 50000,
      receiptRequired: false,
    ),
    PolicyRule(category: 'Hébergement', limitCents: 120000),
    PolicyRule(
      category: 'Fournitures',
      limitCents: 100000,
      receiptRequired: false,
    ),
  ];

  final _users = <AppUser>[];
  final _passwords = <String, String>{}; // user id → salt:hash
  final _invitations = <_Invitation>[];
  final _expenses = <Expense>[];
  final _receipts = <String, Uint8List>{}; // only without a store
  final _createdIds = <String, String>{};
  final _policies = <String, List<PolicyRule>>{}; // by company
  final _exports = <String, List<ExportBatch>>{}; // by company
  final _exportByRequest = <String, ExportBatch>{};
  AppUser? _user;
  var _nextId = 1;

  /// Tests and the demo switch flip this to fail the next calls.
  bool offline = false;

  DateTime get _now => _clock();
  DateTime _day(int daysAgo) {
    final n = _now;
    return DateTime(n.year, n.month, n.day - daysAgo);
  }

  List<PolicyRule> _policiesOf(String company) =>
      _policies.putIfAbsent(company, () => List.of(_defaultPolicies));
  List<ExportBatch> _exportsOf(String company) =>
      _exports.putIfAbsent(company, () => []);

  // Storage ---------------------------------------------------------------

  Future<void> _load() async {
    final text = await _store?.read();
    if (text == null) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      throw RemboException(
        tr('Les données enregistrées sur ce téléphone sont illisibles.'),
      );
    }
    List<Map<String, dynamic>> rows(Object? list) => [
      for (final r in (list as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
    _nextId = (data['next_id'] as num?)?.toInt() ?? 1;
    for (final u in rows(data['users'])) {
      final user = appUserFromJson(u);
      _users.add(user);
      _passwords[user.id] = (u['password'] as String?) ?? '';
    }
    for (final i in rows(data['invitations'])) {
      _invitations.add(
        _Invitation(
          i['email'] as String,
          UserRole.parse(i['role'] as String?),
          i['company_id'] as String,
          (i['company_name'] as String?) ?? '',
        ),
      );
    }
    _expenses.addAll(rows(data['expenses']).map(Expense.fromJson));
    (data['policies'] as Map? ?? const {}).forEach((company, list) {
      _policies['$company'] = rows(list).map(PolicyRule.fromJson).toList();
    });
    (data['exports'] as Map? ?? const {}).forEach((company, list) {
      _exports['$company'] = [
        for (final b in rows(list))
          ExportBatch.fromJson(b, csv: b['csv'] as String?),
      ];
    });
    final session = data['session'] as String?;
    _user = _users.where((u) => u.id == session).firstOrNull;
  }

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    await store.write(
      jsonEncode({
        'version': 1,
        'next_id': _nextId,
        'session': _user?.id,
        'users': [
          for (final u in _users) {...u.toJson(), 'password': _passwords[u.id]},
        ],
        'invitations': [
          for (final i in _invitations)
            {
              'email': i.email,
              'role': i.role.name,
              'company_id': i.companyId,
              'company_name': i.companyName,
            },
        ],
        'expenses': [for (final e in _expenses) e.toJson()],
        'policies': {
          for (final p in _policies.entries)
            p.key: [for (final r in p.value) r.toJson()],
        },
        'exports': {
          for (final x in _exports.entries)
            x.key: [for (final b in x.value) b.toJson()],
        },
      }),
    );
  }

  static String _hash(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password'));
    for (var i = 0; i < 5000; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return '$salt:$digest';
  }

  static String _newSalt() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// The demo accepts any password; real accounts check theirs.
  bool _passwordMatches(AppUser user, String password) {
    final stored = _passwords[user.id] ?? '';
    final salt = stored.split(':').first;
    return stored.isNotEmpty && _hash(password, salt) == stored;
  }

  Future<void> _latency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline) {
      throw RemboException(
        tr('Connexion impossible. Vérifiez votre réseau puis réessayez.'),
        network: true,
      );
    }
  }

  AppUser get _me => _user ?? (throw RemboException(tr('Session expirée.')));

  void _replaceMe(AppUser updated) {
    _users[_users.indexWhere((u) => u.id == updated.id)] = updated;
    _user = updated;
  }

  @override
  bool get isDemo => false;

  @override
  bool get isLocal => true;

  // Session ---------------------------------------------------------------

  @override
  Future<AppUser?> restoreSession() async => _user;

  @override
  Future<AppUser> signIn(String email, String password) async {
    await _latency();
    final found = _users.where((u) => u.email == email.trim().toLowerCase());
    if (found.isEmpty || !_passwordMatches(found.first, password)) {
      throw RemboException(tr('E-mail ou mot de passe incorrect.'));
    }
    _user = found.first;
    await _save();
    return _user!;
  }

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _latency();
    final address = email.trim().toLowerCase();
    if (_users.any((u) => u.email == address)) {
      throw RemboException(tr('Un compte existe déjà pour cet e-mail.'));
    }
    final invited = _invitations.where((i) => i.email == address).firstOrNull;
    final user = AppUser(
      id: 'u-${_users.length + 1}-${_newSalt().substring(0, 6)}',
      email: address,
      fullName: fullName.trim(),
      role: invited?.role ?? UserRole.employee,
      companyId: invited?.companyId,
      companyName: invited?.companyName ?? '',
    );
    _invitations.removeWhere((i) => i.email == address);
    _users.add(user);
    _passwords[user.id] = _hash(password, _newSalt());
    _user = user;
    await _save();
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _latency();
    throw RemboException(
      tr(
        'Les comptes sont enregistrés sur ce téléphone uniquement : '
        'aucun e-mail de réinitialisation ne peut être envoyé.',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    _user = null;
    await _save();
  }

  @override
  Future<AppUser> createCompany({
    required String name,
    String ice = '',
    String city = '',
  }) async {
    await _latency();
    final me = _me;
    if (me.companyId != null) {
      throw RemboException(tr('Vous faites déjà partie d’une entreprise.'));
    }
    if (name.trim().isEmpty) {
      throw RemboException(tr('Le nom de l’entreprise est obligatoire.'));
    }
    _replaceMe(
      AppUser(
        id: me.id,
        email: me.email,
        fullName: me.fullName,
        role: UserRole.manager,
        companyId: 'c-${me.id}',
        companyName: name.trim(),
        whatsappPhone: me.whatsappPhone,
      ),
    );
    await _save();
    return _user!;
  }

  // Expenses --------------------------------------------------------------

  String? _companyOf(Expense e) =>
      _users.where((u) => u.id == e.employeeId).firstOrNull?.companyId;

  bool _visible(Expense e) {
    final me = _me;
    if (e.employeeId == me.id) return true;
    if (me.companyId == null || _companyOf(e) != me.companyId) return false;
    return switch (me.role) {
      UserRole.employee => false,
      UserRole.manager => e.status != ExpenseStatus.draft,
      UserRole.accountant =>
        e.status == ExpenseStatus.approved ||
            e.status == ExpenseStatus.exported,
    };
  }

  @override
  Future<List<Expense>> fetchExpenses() async {
    await _latency();
    return _expenses.where(_visible).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Position of an expense the current user may see.
  int _indexOf(String id) {
    final i = _expenses.indexWhere((e) => e.id == id);
    if (i < 0 || !_visible(_expenses[i])) {
      throw RemboException(tr('Dépense introuvable.'));
    }
    return i;
  }

  @override
  Future<Expense> saveDraft(
    Expense draft, {
    Uint8List? receiptBytes,
    String? receiptName,
    String? createId,
  }) async {
    await _latency();
    final me = _me;
    if (me.companyId == null) {
      throw RemboException(tr('Créez ou rejoignez d’abord une entreprise.'));
    }
    Expense saved;
    final created = createId == null ? null : _createdIds[createId];
    if (draft.id.isEmpty && created != null) {
      saved = _expenses[_indexOf(created)];
    } else if (draft.id.isEmpty) {
      final id = 'EXP-${(_nextId++).toString().padLeft(4, '0')}';
      if (createId != null) _createdIds[createId] = id;
      saved = Expense(
        id: id,
        employeeId: me.id,
        employeeName: me.fullName,
        createdAt: _now,
      );
      _expenses.add(saved);
    } else {
      saved = _expenses[_indexOf(draft.id)];
      if (saved.employeeId != me.id || !saved.status.editable) {
        throw RemboException(tr('Cette dépense ne peut plus être modifiée.'));
      }
    }
    if (receiptBytes != null) {
      if (_store == null) {
        _receipts[saved.id] = receiptBytes;
      } else {
        await _store.writeBlob(saved.id, receiptBytes);
      }
    }
    saved = saved.copyWith(
      supplier: draft.supplier.trim(),
      supplierIce: draft.supplierIce.trim(),
      date: draft.date,
      amountCents: draft.amountCents,
      vatCents: draft.vatCents,
      category: draft.category,
      project: draft.project.trim(),
      reason: draft.reason.trim(),
      receiptPath: receiptBytes != null
          ? 'local/${saved.id}'
          : saved.receiptPath,
    );
    _expenses[_indexOf(saved.id)] = saved;
    await _save();
    return saved;
  }

  @override
  Future<void> deleteDraft(String id) async {
    await _latency();
    final e = _expenses[_indexOf(id)];
    if (e.employeeId != _me.id || e.status != ExpenseStatus.draft) {
      throw RemboException(tr('Seul un brouillon peut être supprimé.'));
    }
    _expenses.removeAt(_indexOf(id));
    _receipts.remove(id);
    await _store?.deleteBlob(id);
    await _save();
  }

  @override
  Future<Expense> submit(String id) async {
    await _latency();
    final me = _me;
    final i = _indexOf(id);
    var e = _expenses[i];
    if (e.employeeId != me.id) {
      throw RemboException(tr('Vous ne pouvez soumettre que vos dépenses.'));
    }
    if (!e.status.editable) return e; // Already submitted: a retry is a no-op.
    if (e.missingFields.isNotEmpty) {
      throw RemboException(
        tr('Complétez d’abord : {join}.', {'join': e.missingFields.join(', ')}),
      );
    }
    final flags = controlExpense(
      e,
      policies: _policiesOf(me.companyId!),
      others: _expenses,
      today: _day(0),
    );
    final decided = flags.isEmpty
        ? ExpenseStatus.approved
        : ExpenseStatus.needsReview;
    e = e.copyWith(
      status: decided,
      flags: flags,
      events: [
        ...e.events,
        ExpenseEvent(
          status: ExpenseStatus.submitted,
          at: _now,
          actorName: me.fullName,
        ),
        ExpenseEvent(
          status: decided,
          at: _now.add(const Duration(seconds: 1)),
          actorName: 'Contrôle automatique',
          byAgent: true,
        ),
      ],
    );
    _expenses[i] = e;
    await _save();
    return e;
  }

  @override
  Future<Expense> decide(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _latency();
    final me = _me;
    if (me.role != UserRole.manager) {
      throw RemboException(tr('Cette action est réservée aux responsables.'));
    }
    final i = _indexOf(id);
    final e = _expenses[i];
    if (e.employeeId == me.id) {
      throw RemboException(
        tr('Vous ne pouvez pas décider de votre propre dépense.'),
      );
    }
    if (e.status != ExpenseStatus.needsReview) {
      throw RemboException(tr('Cette dépense a déjà été traitée.'));
    }
    if ((reason ?? '').trim().isEmpty && !approve) {
      throw RemboException(tr('Le motif du rejet est obligatoire.'));
    }
    final status = approve ? ExpenseStatus.approved : ExpenseStatus.rejected;
    _expenses[i] = e.copyWith(
      status: status,
      events: [
        ...e.events,
        ExpenseEvent(
          status: status,
          at: _now,
          actorName: me.fullName,
          reason: (reason ?? '').trim().isEmpty ? null : reason!.trim(),
        ),
      ],
    );
    await _save();
    return _expenses[i];
  }

  /// No reader on the phone: the person types what the receipt says.
  @override
  Future<ReceiptReading?> readReceipt(Uint8List bytes, String name) async =>
      null;

  @override
  Future<String?> receiptUrl(Expense expense) async => null;

  @override
  Uint8List? receiptBytes(Expense expense) => _receipts[expense.id];

  @override
  Future<Uint8List?> loadReceipt(Expense expense) async {
    if (_store == null || !expense.hasReceipt) return null;
    _indexOf(expense.id);
    return _store.readBlob(expense.id);
  }

  @override
  Future<AppUser> linkWhatsApp(String? phone) async {
    await _latency();
    _replaceMe(_me.withWhatsApp(phone));
    await _save();
    return _user!;
  }

  // Company ---------------------------------------------------------------

  @override
  Future<List<Member>> fetchMembers() async {
    await _latency();
    final company = _me.companyId;
    if (company == null) return [];
    return [
      for (final u in _users.where((u) => u.companyId == company))
        Member(name: u.fullName, email: u.email, role: u.role),
      for (final i in _invitations.where((i) => i.companyId == company))
        Member(name: i.email, email: i.email, role: i.role, pending: true),
    ];
  }

  @override
  Future<void> invite(String email, UserRole role) async {
    await _latency();
    final me = _me;
    if (me.role != UserRole.manager || me.companyId == null) {
      throw RemboException(tr('Cette action est réservée aux responsables.'));
    }
    final address = email.trim().toLowerCase();
    final existing = _users.where((u) => u.email == address).firstOrNull;
    if (existing?.companyId == me.companyId ||
        _invitations.any(
          (i) => i.email == address && i.companyId == me.companyId,
        )) {
      throw RemboException(tr('Cette personne est déjà dans l’équipe.'));
    }
    if (existing != null) {
      throw RemboException(
        tr('Un compte existe déjà pour cet e-mail dans une autre entreprise.'),
      );
    }
    _invitations
      ..removeWhere((i) => i.email == address)
      ..add(_Invitation(address, role, me.companyId!, me.companyName));
    await _save();
  }

  @override
  Future<List<PolicyRule>> fetchPolicies() async {
    await _latency();
    final company = _me.companyId;
    return company == null ? [] : List.of(_policiesOf(company));
  }

  @override
  Future<void> savePolicy(PolicyRule rule) async {
    await _latency();
    final me = _me;
    if (me.role != UserRole.manager || me.companyId == null) {
      throw RemboException(tr('Cette action est réservée aux responsables.'));
    }
    if (rule.limitCents <= 0) {
      throw RemboException(tr('Le plafond doit être supérieur à zéro.'));
    }
    _policiesOf(me.companyId!)
      ..removeWhere((p) => p.category == rule.category)
      ..add(rule);
    await _save();
  }

  // Exports ---------------------------------------------------------------

  @override
  Future<ExportBatch> createExport(
    List<String> ids, {
    required String requestId,
    String delimiter = ';',
  }) async {
    await _latency();
    final done = _exportByRequest[requestId];
    if (done != null) return done;
    final me = _me;
    if (me.role != UserRole.accountant || me.companyId == null) {
      throw RemboException(tr('Cette action est réservée aux comptables.'));
    }
    final chosen = [for (final id in ids.toSet()) _expenses[_indexOf(id)]];
    if (chosen.isEmpty ||
        chosen.any((e) => e.status != ExpenseStatus.approved)) {
      throw RemboException(
        tr(
          'Seules des dépenses validées et non exportées peuvent être '
          'exportées.',
        ),
      );
    }
    final batches = _exportsOf(me.companyId!);
    final batchId = 'B-${(batches.length + 1).toString().padLeft(4, '0')}';
    final batch = ExportBatch(
      id: batchId,
      fileName: CsvExport.fileName(_now),
      createdAt: _now,
      count: chosen.length,
      totalCents: chosen.fold(0, (s, e) => s + e.amountCents),
      csv: CsvExport.build(chosen, batchId: batchId, delimiter: delimiter),
    );
    for (final e in chosen) {
      _expenses[_indexOf(e.id)] = e.copyWith(
        status: ExpenseStatus.exported,
        events: [
          ...e.events,
          ExpenseEvent(
            status: ExpenseStatus.exported,
            at: _now,
            actorName: me.fullName,
          ),
        ],
      );
    }
    batches.insert(0, batch);
    await _save();
    return _exportByRequest[requestId] = batch;
  }

  @override
  Future<List<ExportBatch>> fetchExports() async {
    await _latency();
    final company = _me.companyId;
    return company == null ? [] : List.of(_exportsOf(company));
  }
}

/// The same engine with fictional people and expenses, kept in memory.
/// Nothing is saved and any password is accepted.
class DemoBackend extends LocalBackend {
  DemoBackend({
    super.clock,
    super.latency = const Duration(milliseconds: 250),
  }) {
    _users.addAll([marius, ahmed, salma, nadia]);
    _nextId = 1043;
    _seed();
  }

  static const companyName = 'Atlas Conseil';
  static const marius = AppUser(
    id: 'u-marius',
    email: 'marius@atlas-conseil.ma',
    fullName: 'Marius Bennani',
    companyId: 'c-atlas',
    companyName: companyName,
  );
  static const ahmed = AppUser(
    id: 'u-ahmed',
    email: 'ahmed@atlas-conseil.ma',
    fullName: 'Ahmed El Fassi',
    companyId: 'c-atlas',
    companyName: companyName,
  );
  static const salma = AppUser(
    id: 'u-salma',
    email: 'salma@atlas-conseil.ma',
    fullName: 'Salma Idrissi',
    role: UserRole.manager,
    companyId: 'c-atlas',
    companyName: companyName,
  );
  static const nadia = AppUser(
    id: 'u-nadia',
    email: 'nadia@atlas-conseil.ma',
    fullName: 'Nadia Tazi',
    role: UserRole.accountant,
    companyId: 'c-atlas',
    companyName: companyName,
  );

  @override
  bool get isDemo => true;

  @override
  bool get isLocal => false;

  @override
  bool _passwordMatches(AppUser user, String password) => password.isNotEmpty;

  @override
  Future<void> sendPasswordReset(String email) => _latency();

  @override
  Future<ReceiptReading?> readReceipt(Uint8List bytes, String name) async {
    await _latency();
    if (name.contains('illisible')) {
      return const ReceiptReading(unreadable: true, simulated: true);
    }
    return ReceiptReading(
      supplier: 'Café Atlas',
      supplierIce: '001234567000089',
      date: _day(1),
      amountCents: 24000,
      vatCents: 2182,
      simulated: true,
    );
  }

  void _seed() {
    Expense make(
      String id,
      AppUser who,
      String supplier,
      int daysAgo,
      int cents,
      String category,
      String reason,
      ExpenseStatus status, {
      List<ExpenseFlag> flags = const [],
      String project = 'Mission Rabat',
      String? rejection,
    }) {
      final day = _day(daysAgo);
      final events = <ExpenseEvent>[
        if (status != ExpenseStatus.draft)
          ExpenseEvent(
            status: ExpenseStatus.submitted,
            at: day.add(const Duration(hours: 12, minutes: 21)),
            actorName: who.fullName,
          ),
        if (status == ExpenseStatus.needsReview)
          ExpenseEvent(
            status: ExpenseStatus.needsReview,
            at: day.add(const Duration(hours: 12, minutes: 22)),
            actorName: 'Contrôle automatique',
            byAgent: true,
          ),
        if (status == ExpenseStatus.approved ||
            status == ExpenseStatus.exported)
          ExpenseEvent(
            status: ExpenseStatus.approved,
            at: day.add(const Duration(hours: 12, minutes: 22)),
            actorName: 'Contrôle automatique',
            byAgent: true,
          ),
        if (status == ExpenseStatus.rejected)
          ExpenseEvent(
            status: ExpenseStatus.rejected,
            at: day.add(const Duration(hours: 17, minutes: 24)),
            actorName: salma.fullName,
            reason: rejection,
          ),
        if (status == ExpenseStatus.exported)
          ExpenseEvent(
            status: ExpenseStatus.exported,
            at: day.add(const Duration(days: 1, hours: 9)),
            actorName: nadia.fullName,
          ),
      ];
      return Expense(
        id: id,
        employeeId: who.id,
        employeeName: who.fullName,
        supplier: supplier,
        date: day,
        amountCents: cents,
        vatCents: (cents / 11).round(),
        category: category,
        project: project,
        reason: reason,
        status: status,
        receiptPath: 'demo/$id.jpg',
        flags: flags,
        events: events,
        createdAt: day.add(const Duration(hours: 12, minutes: 17)),
      );
    }

    _expenses.addAll([
      make(
        'EXP-1042',
        marius,
        'Café Atlas',
        1,
        24000,
        'Repas',
        'Déjeuner client',
        ExpenseStatus.draft,
      ),
      make(
        'EXP-1041',
        marius,
        'Taxi Bleu',
        2,
        8500,
        'Transport',
        'Trajet vers le client',
        ExpenseStatus.approved,
      ),
      make(
        'EXP-1040',
        marius,
        'Bureau Plus',
        4,
        36000,
        'Fournitures',
        'Fournitures de bureau',
        ExpenseStatus.approved,
      ),
      make(
        'EXP-1039',
        marius,
        'Hôtel Mogador',
        9,
        90000,
        'Hébergement',
        'Nuit sur place, mission Rabat',
        ExpenseStatus.exported,
      ),
      make(
        'EXP-1038',
        marius,
        'Café Central',
        3,
        18000,
        'Repas',
        'Déjeuner équipe',
        ExpenseStatus.rejected,
        rejection: 'Merci de joindre un justificatif lisible.',
      ),
      make(
        'EXP-1037',
        marius,
        'Restaurant Le Jardin',
        2,
        24000,
        'Repas',
        'Déjeuner client projet Mission Rabat',
        ExpenseStatus.needsReview,
        flags: [
          const ExpenseFlag(
            FlagKind.policy,
            'Plafond Repas dépassé de 40,00 MAD',
          ),
        ],
      ),
      make(
        'EXP-1036',
        ahmed,
        'Petit Taxi',
        1,
        8500,
        'Autre',
        'Course client',
        ExpenseStatus.needsReview,
        flags: [const ExpenseFlag(FlagKind.ambiguity, 'Catégorie à préciser')],
      ),
      make(
        'EXP-1035',
        salma,
        'Train Al Boraq',
        5,
        24900,
        'Transport',
        'Déplacement Tanger',
        ExpenseStatus.approved,
        project: 'Client Tanger Med',
      ),
    ]);
    // Sent by WhatsApp: a voice note already turned into a draft.
    _expenses.add(
      Expense(
        id: 'EXP-1034',
        employeeId: marius.id,
        employeeName: marius.fullName,
        supplier: 'Taxi',
        date: _day(0),
        amountCents: 4500,
        category: 'Transport',
        project: 'Client Atlas',
        reason: 'Déplacement client',
        source: ExpenseSource.whatsapp,
        transcript: 'Taxi, 45 dirhams, client Atlas.',
        voicePath: 'demo/EXP-1034.ogg',
        createdAt: _now.subtract(const Duration(minutes: 20)),
      ),
    );
    _exportsOf('c-atlas').add(
      ExportBatch(
        id: 'B-0001',
        fileName: CsvExport.fileName(_day(8)),
        createdAt: _day(8).add(const Duration(hours: 9)),
        count: 1,
        totalCents: 90000,
      ),
    );
  }
}
