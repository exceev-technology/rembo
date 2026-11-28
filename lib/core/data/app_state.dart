import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'models.dart';

/// What the activity tab shows, derived from the status history.
class ActivityItem {
  const ActivityItem(this.expense, this.event);
  final Expense expense;
  final ExpenseEvent event;

  String get key => '${expense.id}/${event.status.code}/${event.at}';
}

/// Session and data shared by every screen. Screens read it through
/// [AppScope] and never talk to the backend directly.
class AppState extends ChangeNotifier {
  AppState(this.backend);
  final RemboBackend backend;

  AppUser? user;
  List<Expense> expenses = const [];
  List<PolicyRule> policies = const [];
  List<Member> members = const [];

  /// True once [members] has been read from the backend for this session:
  /// an empty list then means an empty team, not a failed load.
  bool membersLoaded = false;
  List<ExportBatch> exports = const [];

  /// The control approves compliant expenses itself (company setting).
  bool autoApprove = false;

  /// Managers declare their own expenses too (company setting).
  bool managersDeclare = false;

  /// Deadline, project rule and imported policy document of the company.
  CompanyPolicy companyPolicy = CompanyPolicy.defaults;

  /// This person may declare expenses: a manager only when the company
  /// allows it. The server applies the same rule.
  bool get canDeclare => role != UserRole.manager || managersDeclare;

  /// Accounting account of each category (company setting).
  Map<String, String> accounts = const {};
  bool loading = false;

  /// The company that invited the person, while they belong to none: shown
  /// to them, joined only with [acceptInvitation].
  CompanyInvitation? invitation;

  /// Last loading problem, shown by the tabs with a retry.
  RemboException? loadError;
  final _read = <String>{};

  /// Everything that happened up to this moment is read: kept on the phone
  /// for each person, so it survives a sign-out and a restart.
  DateTime? _readUntil;
  String? _readUntilOf;

  bool get isDemo => backend.isDemo;
  bool get isLocal => backend.isLocal;
  UserRole get role => user?.role ?? UserRole.employee;

  /// Finds the session again. With [wait] false it returns as soon as the
  /// person is known and loads their data behind: the opening of the app
  /// must not hang on a slow network.
  Future<void> restore({bool wait = true}) async {
    try {
      user = await backend.restoreSession();
    } on RemboException {
      user = null;
    }
    notifyListeners();
    if (user == null) return;
    if (user!.companyId == null) return _loadInvitation();
    final loaded = refresh();
    if (wait) await loaded;
  }

  Future<void> signIn(String email, String password) async {
    user = await backend.signIn(email, password);
    notifyListeners();
    user!.companyId != null ? await refresh() : await _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    try {
      invitation = await backend.pendingInvitation();
    } on RemboException {
      // Not reachable now: the person can still create a company.
      invitation = null;
    }
    notifyListeners();
  }

  /// Joins the company of [invitation], on the person's answer.
  Future<void> acceptInvitation() async {
    user = await backend.acceptInvitation();
    invitation = null;
    notifyListeners();
    await refresh();
  }

  /// Returns false when the address must be confirmed before signing in.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final created = await backend.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    if (created == null) return false;
    user = created;
    notifyListeners();
    created.companyId != null ? await refresh() : await _loadInvitation();
    return true;
  }

  /// Signs in with the code that confirms a new account.
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    user = await backend.confirmSignUp(email: email, code: code);
    notifyListeners();
    user!.companyId != null ? await refresh() : await _loadInvitation();
  }

  /// Sets a new password with the e-mailed code, and signs in.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    user = await backend.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    notifyListeners();
    user!.companyId != null ? await refresh() : await _loadInvitation();
  }

  Future<void> createCompany({
    required String name,
    String ice = '',
    String city = '',
  }) async {
    user = await backend.createCompany(name: name, ice: ice, city: city);
    invitation = null;
    notifyListeners();
    await refresh();
  }

  Future<void> signOut() async {
    await backend.signOut();
    user = null;
    invitation = null;
    expenses = const [];
    members = const [];
    membersLoaded = false;
    exports = const [];
    policies = const [];
    accounts = const {};
    autoApprove = false;
    managersDeclare = false;
    companyPolicy = CompanyPolicy.defaults;
    _read.clear();
    _readUntil = null;
    _readUntilOf = null;
    notifyListeners();
  }

  String _readKey(String userId) => 'rembo.activity.read_until.$userId';

  /// Reads the person's read mark once per session. Without storage (tests,
  /// a blocked plug-in) everything simply stays unread.
  Future<void> _loadReadMark() async {
    final id = user?.id;
    if (id == null || _readUntilOf == id) return;
    _readUntilOf = id;
    _readUntil = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_readKey(id));
      _readUntil = saved == null ? null : DateTime.tryParse(saved);
    } catch (_) {}
  }

  Future<void> _saveReadMark(String id, DateTime until) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readKey(id), until.toUtc().toIso8601String());
    } catch (_) {}
  }

  /// Reloads everything the current role can see.
  Future<void> refresh() async {
    if (user == null) return;
    loading = true;
    loadError = null;
    notifyListeners();
    await _loadReadMark();
    try {
      expenses = await backend.fetchExpenses();
      policies = await backend.fetchPolicies();
      companyPolicy = await backend.fetchCompanyPolicy();
      if (role == UserRole.manager) {
        members = await backend.fetchMembers();
        membersLoaded = true;
        autoApprove = await backend.fetchAutoApprove();
        managersDeclare = await backend.fetchManagersDeclare();
      }
      if (role == UserRole.accountant) exports = await backend.fetchExports();
      if (role != UserRole.employee) accounts = await backend.fetchAccounts();
    } on RemboException catch (e) {
      loadError = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _put(Expense expense) {
    final list = List.of(expenses);
    final i = list.indexWhere((e) => e.id == expense.id);
    i < 0 ? list.insert(0, expense) : list[i] = expense;
    expenses = list;
    notifyListeners();
  }

  Expense? byId(String id) {
    for (final e in expenses) {
      if (e.id == id) return e;
    }
    return null;
  }

  // Views --------------------------------------------------------------------
  List<Expense> get mine =>
      expenses.where((e) => e.employeeId == user?.id).toList();

  /// Received by WhatsApp, waiting for their author's confirmation.
  List<Expense> get whatsappToConfirm => mine
      .where((e) => e.fromWhatsApp && e.status == ExpenseStatus.draft)
      .toList();

  /// Waiting for this manager's decision. Never their own expenses: another
  /// manager decides on those.
  List<Expense> get toReview => role != UserRole.manager
      ? const []
      : expenses
            .where(
              (e) =>
                  e.status == ExpenseStatus.needsReview &&
                  e.employeeId != user?.id,
            )
            .toList();

  /// Waiting only for a manager's confirmation: nothing was found.
  List<Expense> get compliantToConfirm =>
      toReview.where((e) => e.compliantToConfirm).toList();

  /// Waiting for a decision because the control found something.
  List<Expense> get exceptions =>
      toReview.where((e) => !e.compliantToConfirm).toList();

  List<Expense> get toExport =>
      expenses.where((e) => e.status == ExpenseStatus.approved).toList();

  PolicyRule? policyOf(String category) {
    for (final p in policies) {
      if (p.category == category) return p;
    }
    return null;
  }

  /// Another expense of the same person with the same day and amount.
  Expense? possibleDuplicateOf(Expense draft) {
    if (draft.date == null || draft.amountCents <= 0) return null;
    for (final e in mine) {
      if (e.id != draft.id &&
          e.date == draft.date &&
          e.amountCents == draft.amountCents &&
          e.status != ExpenseStatus.rejected) {
        return e;
      }
    }
    return null;
  }

  // Actions ------------------------------------------------------------------
  Future<Expense> saveDraft(
    Expense draft, {
    Uint8List? receiptBytes,
    String? receiptName,
    String? createId,
  }) async {
    final saved = await backend.saveDraft(
      draft,
      receiptBytes: receiptBytes,
      receiptName: receiptName,
      createId: createId,
    );
    _put(saved);
    return saved;
  }

  Future<void> deleteDraft(String id) async {
    await backend.deleteDraft(id);
    expenses = expenses.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<Expense> submit(String id) async {
    final result = await backend.submit(id);
    _put(result);
    return result;
  }

  Future<Expense> decide(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    final result = await backend.decide(id, approve: approve, reason: reason);
    _put(result);
    return result;
  }

  /// Confirms the compliant expenses waiting for the manager.
  Future<int> approveCompliant(List<String> ids) async {
    final n = await backend.approveCompliant(ids);
    await refresh();
    return n;
  }

  Future<void> saveAccount(String category, String code) async {
    await backend.saveAccount(category, code);
    accounts = await backend.fetchAccounts();
    notifyListeners();
  }

  Future<void> setAutoApprove(bool on) async {
    await backend.setAutoApprove(on);
    autoApprove = on;
    notifyListeners();
  }

  Future<void> setManagersDeclare(bool on) async {
    await backend.setManagersDeclare(on);
    managersDeclare = on;
    notifyListeners();
  }

  Future<ExportBatch> createExport(
    List<String> ids, {
    required String requestId,
    String delimiter = ';',
  }) async {
    final batch = await backend.createExport(
      ids,
      requestId: requestId,
      delimiter: delimiter,
    );
    await refresh();
    return batch;
  }

  Future<void> invite(String email, UserRole role) async {
    await backend.invite(email, role);
    members = await backend.fetchMembers();
    membersLoaded = true;
    notifyListeners();
  }

  Future<WhatsAppLinkCode> requestWhatsAppCode() =>
      backend.requestWhatsAppCode();

  /// Reads the person again, to see a number linked from WhatsApp.
  Future<void> checkWhatsAppLink() async {
    user = await backend.restoreSession() ?? user;
    notifyListeners();
  }

  Future<void> unlinkWhatsApp() async {
    user = await backend.unlinkWhatsApp();
    notifyListeners();
  }

  Future<void> savePolicy(PolicyRule rule) async {
    await backend.savePolicy(rule);
    policies = await backend.fetchPolicies();
    notifyListeners();
  }

  /// Proposals read in a policy document; nothing changes yet.
  Future<PolicyProposal> readPolicy(PolicySource source) =>
      backend.readPolicy(source);

  Future<void> applyPolicy(PolicyProposal proposal) async {
    await backend.applyPolicy(proposal);
    await _reloadPolicy();
  }

  Future<void> saveCompanyRules({
    required int deadlineDays,
    required bool projectRequired,
  }) async {
    await backend.saveCompanyRules(
      deadlineDays: deadlineDays,
      projectRequired: projectRequired,
    );
    await _reloadPolicy();
  }

  Future<void> resetPolicy() async {
    await backend.resetPolicy();
    await _reloadPolicy();
  }

  Future<void> _reloadPolicy() async {
    policies = await backend.fetchPolicies();
    companyPolicy = await backend.fetchCompanyPolicy();
    notifyListeners();
  }

  // Activity -----------------------------------------------------------------
  /// Status changes that concern the current user, newest first.
  List<ActivityItem> get activity {
    final items = <ActivityItem>[];
    for (final e in expenses) {
      for (final ev in e.events) {
        final relevant = switch (role) {
          UserRole.employee =>
            e.employeeId == user?.id && ev.status != ExpenseStatus.submitted,
          UserRole.manager =>
            e.employeeId == user?.id
                ? ev.status != ExpenseStatus.submitted
                : ev.status == ExpenseStatus.needsReview ||
                      ev.status == ExpenseStatus.approved ||
                      ev.status == ExpenseStatus.rejected,
          UserRole.accountant =>
            ev.status == ExpenseStatus.approved ||
                ev.status == ExpenseStatus.exported,
        };
        if (relevant) items.add(ActivityItem(e, ev));
      }
    }
    return items..sort((a, b) => b.event.at.compareTo(a.event.at));
  }

  bool isUnread(ActivityItem item) =>
      !_read.contains(item.key) &&
      (_readUntil == null || item.event.at.isAfter(_readUntil!));
  int get unreadCount => activity.where(isUnread).length;

  void markAllRead() {
    final items = activity;
    _read.addAll(items.map((a) => a.key));
    final id = user?.id;
    if (id != null && items.isNotEmpty) {
      final latest = items
          .map((a) => a.event.at)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (_readUntil == null || latest.isAfter(_readUntil!)) {
        _readUntil = latest;
        _saveReadMark(id, latest);
      }
    }
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  /// Rebuilds the caller when the state changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks: no rebuild subscription.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
