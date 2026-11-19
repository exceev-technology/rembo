import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cg;

import 'backend.dart';
import 'csv_export.dart';
import 'local_store.dart';
import 'models.dart';
import '../l10n/l10n.dart';
import '../agents/compliance_agent.dart';

part 'demo_backend.dart';

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

  /// Companies that let the control approve compliant expenses itself.
  final _autoApprove = <String>{};
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
    _autoApprove.addAll([
      for (final c in (data['auto_approve'] as List? ?? const [])) '$c',
    ]);
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
        'auto_approve': _autoApprove.toList(),
      }),
    );
  }

  /// PBKDF2-HMAC-SHA256 rounds for a password kept on this phone.
  static const passwordRounds = 120000;
  static const _scheme = 'pbkdf2-sha256';

  /// « pbkdf2-sha256$rounds$salt$hash », salt and hash in base64.
  static Future<String> _hash(
    String password, {
    List<int>? salt,
    int rounds = passwordRounds,
  }) async {
    final random = Random.secure();
    final nonce = salt ?? List.generate(16, (_) => random.nextInt(256));
    final key = await cg.Pbkdf2(
      macAlgorithm: cg.Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: nonce);
    final hash = base64Encode(await key.extractBytes());
    return '$_scheme\$$rounds\$${base64Encode(nonce)}\$$hash';
  }

  /// How passwords were kept before PBKDF2: « salt:sha256 », hashed 5 000
  /// times. Still checked, and replaced at the next sign-in.
  static String _legacyHash(String password, String salt) {
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

  /// Compares in a time that does not depend on where they differ.
  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// The demo accepts any password; real accounts check theirs.
  Future<bool> _passwordMatches(AppUser user, String password) async {
    final stored = _passwords[user.id] ?? '';
    if (stored.startsWith('$_scheme\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final again = await _hash(
        password,
        salt: base64Decode(parts[2]),
        rounds: int.parse(parts[1]),
      );
      return _same(again, stored);
    }
    final salt = stored.split(':').first;
    if (stored.isEmpty || !_same(_legacyHash(password, salt), stored)) {
      return false;
    }
    // Right password kept the old way: kept from now on with PBKDF2.
    _passwords[user.id] = await _hash(password);
    return true;
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
    if (found.isEmpty || !await _passwordMatches(found.first, password)) {
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
    // An invitation to this address waits for the person's answer
    // (acceptInvitation): the account starts without a company.
    final user = AppUser(
      id: 'u-${_users.length + 1}-${_newSalt().substring(0, 6)}',
      email: address,
      fullName: fullName.trim(),
    );
    _users.add(user);
    _passwords[user.id] = await _hash(password);
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

  _Invitation? _invitationOf(AppUser me) => me.companyId != null
      ? null
      : _invitations.where((i) => i.email == me.email).firstOrNull;

  @override
  Future<CompanyInvitation?> pendingInvitation() async {
    final invited = _invitationOf(_me);
    return invited == null
        ? null
        : CompanyInvitation(
            companyName: invited.companyName,
            role: invited.role,
          );
  }

  @override
  Future<AppUser> acceptInvitation() async {
    await _latency();
    final me = _me;
    final invited = _invitationOf(me);
    if (invited == null) {
      throw RemboException(tr('Cette invitation n’est plus valable.'));
    }
    _replaceMe(
      AppUser(
        id: me.id,
        email: me.email,
        fullName: me.fullName,
        role: invited.role,
        companyId: invited.companyId,
        companyName: invited.companyName,
        whatsappPhone: me.whatsappPhone,
      ),
    );
    _invitations.removeWhere((i) => i.email == me.email);
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
      vatRate: draft.vatRate,
      currency: draft.currency,
      foreignAmountCents: draft.foreignCurrency
          ? draft.foreignAmountCents
          : null,
      category: draft.category,
      project: draft.project.trim(),
      // What the agents proposed and the start are written once.
      agentProposal: saved.agentProposal ?? draft.agentProposal,
      captureStartedAt: saved.captureStartedAt ?? draft.captureStartedAt,
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
    final decided = flags.isEmpty && _autoApprove.contains(me.companyId)
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
          reason: flags.isEmpty && decided == ExpenseStatus.needsReview
              ? 'Conforme aux règles'
              : null,
        ),
      ],
    );
    _expenses[i] = e;
    await _save();
    return e;
  }

  @override
  Future<int> approveCompliant(List<String> ids) async {
    await _latency();
    final me = _me;
    if (me.role != UserRole.manager) {
      throw RemboException(tr('Cette action est réservée aux responsables.'));
    }
    var done = 0;
    for (final id in ids.toSet()) {
      final i = _expenses.indexWhere((e) => e.id == id);
      if (i < 0 || !_visible(_expenses[i])) continue;
      final e = _expenses[i];
      if (!e.compliantToConfirm || e.employeeId == me.id) continue;
      _expenses[i] = e.copyWith(
        status: ExpenseStatus.approved,
        events: [
          ...e.events,
          ExpenseEvent(
            status: ExpenseStatus.approved,
            at: _now,
            actorName: me.fullName,
            reason: 'Validation groupée des dépenses conformes',
          ),
        ],
      );
      done++;
    }
    await _save();
    return done;
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

  /// No server receives WhatsApp messages here: nothing can be linked.
  @override
  Future<WhatsAppLinkCode> requestWhatsAppCode() async {
    await _latency();
    throw RemboException(
      tr(
        'WhatsApp demande un serveur : il sera disponible quand votre '
        'entreprise sera connectée à REMBO en ligne.',
      ),
    );
  }

  @override
  Future<AppUser> unlinkWhatsApp() async {
    await _latency();
    _replaceMe(_me.withWhatsApp(null));
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

  @override
  Future<bool> fetchAutoApprove() async {
    await _latency();
    return _autoApprove.contains(_me.companyId);
  }

  @override
  Future<void> setAutoApprove(bool on) async {
    await _latency();
    final me = _me;
    if (me.role != UserRole.manager || me.companyId == null) {
      throw RemboException(tr('Cette action est réservée aux responsables.'));
    }
    on ? _autoApprove.add(me.companyId!) : _autoApprove.remove(me.companyId);
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
