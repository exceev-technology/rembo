/// Shared REMBO domain model. Amounts are integer centimes of MAD and dates
/// are civil days; the JSON shape matches the Supabase tables.
library;

import 'dart:typed_data';

import '../l10n/l10n.dart';

enum UserRole {
  employee('Collaborateur'),
  manager('Responsable'),
  accountant('Comptable');

  const UserRole(this._label);
  final String _label;

  /// Name of the role in the current language.
  String get label => tr(_label);

  static UserRole parse(String? name) =>
      values.firstWhere((r) => r.name == name, orElse: () => employee);
}

/// Life cycle of an expense. Only the server moves an expense past `draft`.
enum ExpenseStatus {
  draft('draft', 'Brouillon'),
  submitted('submitted', 'Soumise'),
  needsReview('needs_review', 'À examiner'),
  approved('approved', 'Validée'),
  rejected('rejected', 'Rejetée'),
  exported('exported', 'Exportée');

  const ExpenseStatus(this.code, this._label);
  final String code;
  final String _label;

  /// Name of the status in the current language.
  String get label => tr(_label);

  static ExpenseStatus parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => draft);

  /// The owner may still edit the expense.
  bool get editable => this == draft || this == rejected;
}

/// How the expense reached REMBO.
enum ExpenseSource {
  app,
  whatsapp;

  static ExpenseSource parse(String? name) =>
      name == 'whatsapp' ? whatsapp : app;
}

enum FlagKind {
  policy('Écart aux règles'),
  ambiguity('Ambiguïté'),
  duplicate('Doublon possible');

  const FlagKind(this._label);
  final String _label;

  String get label => tr(_label);

  static FlagKind parse(String? name) =>
      values.firstWhere((k) => k.name == name, orElse: () => ambiguity);
}

/// Why the automatic control sent an expense to a manager.
class ExpenseFlag {
  const ExpenseFlag(this.kind, this.message);
  final FlagKind kind;
  final String message;

  factory ExpenseFlag.fromJson(Map<String, dynamic> json) => ExpenseFlag(
    FlagKind.parse(json['kind'] as String?),
    '${json['message']}',
  );
}

/// One step of the status history, written by the server.
class ExpenseEvent {
  const ExpenseEvent({
    required this.status,
    required this.at,
    required this.actorName,
    this.byAgent = false,
    this.reason,
  });
  final ExpenseStatus status;
  final DateTime at;
  final String actorName;
  final bool byAgent;
  final String? reason;

  factory ExpenseEvent.fromJson(Map<String, dynamic> json) => ExpenseEvent(
    status: ExpenseStatus.parse(json['to_status'] as String?),
    at: DateTime.parse(json['created_at'] as String).toLocal(),
    actorName: (json['actor_name'] as String?) ?? '',
    byAgent: json['actor_kind'] == 'agent',
    reason: json['reason'] as String?,
  );
}

/// Moroccan VAT rates, in percent; 0 when the receipt says exempt.
const vatRates = [20, 14, 10, 7, 0];

/// Currencies a receipt can be paid in. The amount reimbursed is always in
/// dirhams: another currency also keeps what was paid in it.
const receiptCurrencies = ['MAD', 'EUR', 'USD', 'GBP'];

/// Marks a field [Expense.copyWith] keeps; null means « clear it ».
const _keep = Object();

const expenseCategories = [
  'Repas',
  'Transport',
  'Hébergement',
  'Fournitures',
  'Autre',
];

class Expense {
  const Expense({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.supplier = '',
    this.supplierIce = '',
    this.date,
    this.amountCents = 0,
    this.vatCents = 0,
    this.vatRate,
    this.currency = 'MAD',
    this.foreignAmountCents,
    this.category = '',
    this.project = '',
    this.reason = '',
    this.status = ExpenseStatus.draft,
    this.receiptPath,
    this.flags = const [],
    this.events = const [],
    this.source = ExpenseSource.app,
    this.transcript,
    this.voicePath,
    this.agentProposal,
    this.captureStartedAt,
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String supplier;
  final String supplierIce;
  final DateTime? date;
  final int amountCents;
  final int vatCents;

  /// VAT rate printed on the receipt, in percent (see [vatRates]).
  final int? vatRate;

  /// Currency of the receipt. [amountCents] stays in MAD; when the receipt
  /// is in another currency, [foreignAmountCents] is what was paid in it.
  final String currency;
  final int? foreignAmountCents;
  final String category;
  final String project;
  final String reason;
  final ExpenseStatus status;
  final String? receiptPath;
  final List<ExpenseFlag> flags;
  final List<ExpenseEvent> events;
  final ExpenseSource source;

  /// Text of the WhatsApp message, or transcription of the voice note.
  final String? transcript;

  /// Voice note kept next to the receipts, when there is one.
  final String? voicePath;

  /// What the agents proposed when the form opened, kept as it was to
  /// measure what the person accepted or corrected:
  /// `{engine, fields: {field: {value, confidence, reason, agent}}}`.
  final Map<String, dynamic>? agentProposal;

  /// When the person started declaring (picture taken, form opened).
  final DateTime? captureStartedAt;
  final DateTime createdAt;

  bool get fromWhatsApp => source == ExpenseSource.whatsapp;
  bool get hasVoice => voicePath != null && voicePath!.isNotEmpty;

  bool get hasReceipt => receiptPath != null && receiptPath!.isNotEmpty;

  bool get foreignCurrency => currency != 'MAD';

  /// What lists show: the reason when given, else the supplier.
  String get title => supplier.isNotEmpty
      ? supplier
      : (reason.isNotEmpty ? reason : tr('Dépense sans titre'));

  /// The fields a submission needs; empty when the draft is complete.
  List<String> get missingFields => [
    if (supplier.trim().isEmpty) tr('fournisseur'),
    if (date == null) tr('date'),
    if (amountCents <= 0) tr('montant'),
    if (category.trim().isEmpty) tr('catégorie'),
    if (reason.trim().isEmpty) tr('motif'),
    if (foreignCurrency && (foreignAmountCents ?? 0) <= 0)
      tr('montant payé en devise'),
  ];

  ExpenseEvent? get lastDecision {
    for (final e in events.reversed) {
      if (e.status == ExpenseStatus.approved ||
          e.status == ExpenseStatus.rejected) {
        return e;
      }
    }
    return null;
  }

  bool get approvedByAgent => lastDecision?.byAgent ?? false;

  /// The control found nothing to say: it waits only for a manager to
  /// confirm it (when the company does not let the control approve).
  bool get compliantToConfirm =>
      status == ExpenseStatus.needsReview && flags.isEmpty;

  Expense copyWith({
    String? id,
    String? supplier,
    String? supplierIce,
    DateTime? date,
    int? amountCents,
    int? vatCents,
    Object? vatRate = _keep,
    String? currency,
    Object? foreignAmountCents = _keep,
    String? category,
    String? project,
    String? reason,
    ExpenseStatus? status,
    String? receiptPath,
    List<ExpenseFlag>? flags,
    List<ExpenseEvent>? events,
    Map<String, dynamic>? agentProposal,
    DateTime? captureStartedAt,
  }) => Expense(
    id: id ?? this.id,
    employeeId: employeeId,
    employeeName: employeeName,
    supplier: supplier ?? this.supplier,
    supplierIce: supplierIce ?? this.supplierIce,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    vatCents: vatCents ?? this.vatCents,
    vatRate: identical(vatRate, _keep) ? this.vatRate : vatRate as int?,
    currency: currency ?? this.currency,
    foreignAmountCents: identical(foreignAmountCents, _keep)
        ? this.foreignAmountCents
        : foreignAmountCents as int?,
    category: category ?? this.category,
    project: project ?? this.project,
    reason: reason ?? this.reason,
    status: status ?? this.status,
    receiptPath: receiptPath ?? this.receiptPath,
    flags: flags ?? this.flags,
    events: events ?? this.events,
    source: source,
    transcript: transcript,
    voicePath: voicePath,
    agentProposal: agentProposal ?? this.agentProposal,
    captureStartedAt: captureStartedAt ?? this.captureStartedAt,
    createdAt: createdAt,
  );

  factory Expense.fromJson(Map<String, dynamic> json) {
    final events = [
      for (final e in (json['status_events'] as List? ?? const []))
        ExpenseEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return Expense(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName:
          (json['employee_name'] as String?) ??
          ((json['profiles'] as Map?)?['full_name'] as String?) ??
          '',
      supplier: (json['supplier_name'] as String?) ?? '',
      supplierIce: (json['supplier_ice'] as String?) ?? '',
      date: json['expense_date'] == null
          ? null
          : DateTime.parse(json['expense_date'] as String),
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      vatCents: (json['vat_cents'] as num?)?.toInt() ?? 0,
      vatRate: (json['vat_rate'] as num?)?.toInt(),
      currency: (json['currency'] as String?) ?? 'MAD',
      foreignAmountCents: (json['foreign_amount_cents'] as num?)?.toInt(),
      category: (json['category'] as String?) ?? '',
      project: (json['project'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      status: ExpenseStatus.parse(json['status'] as String?),
      receiptPath: json['receipt_path'] as String?,
      flags: [
        for (final f in (json['flags'] as List? ?? const []))
          ExpenseFlag.fromJson(Map<String, dynamic>.from(f as Map)),
      ],
      events: events,
      source: ExpenseSource.parse(json['source'] as String?),
      transcript: json['transcript'] as String?,
      voicePath: json['voice_path'] as String?,
      agentProposal: json['agent_proposal'] is Map
          ? Map<String, dynamic>.from(json['agent_proposal'] as Map)
          : null,
      captureStartedAt: json['capture_started_at'] == null
          ? null
          : DateTime.parse(json['capture_started_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  /// Columns the owner is allowed to write. Status, flags and history are
  /// never sent: the server owns them.
  Map<String, dynamic> toWritableJson() => {
    'supplier_name': supplier.trim(),
    'supplier_ice': supplierIce.trim(),
    'expense_date': date == null ? null : isoDay(date!),
    'amount_cents': amountCents,
    'vat_cents': vatCents,
    'vat_rate': vatRate,
    'currency': currency,
    'foreign_amount_cents': foreignCurrency ? foreignAmountCents : null,
    'category': category,
    'project': project.trim(),
    'reason': reason.trim(),
    if (agentProposal != null) 'agent_proposal': agentProposal,
    if (captureStartedAt != null)
      'capture_started_at': captureStartedAt!.toUtc().toIso8601String(),
  };
}

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = UserRole.employee,
    this.companyId,
    this.companyName = '',
    this.whatsappPhone,
  });
  final String id;
  final String email;
  final String fullName;
  final UserRole role;

  /// Null until the account creates or joins a company.
  final String? companyId;
  final String companyName;

  /// Number allowed to send expenses by WhatsApp, as +212600000000.
  final String? whatsappPhone;

  AppUser withWhatsApp(String? phone) => AppUser(
    id: id,
    email: email,
    fullName: fullName,
    role: role,
    companyId: companyId,
    companyName: companyName,
    whatsappPhone: phone,
  );

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
  String get initial =>
      fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();
}

/// A company waiting for the signed-in person to join it, with the role
/// it gives them. Joined only when the person accepts.
class CompanyInvitation {
  const CompanyInvitation({required this.companyName, required this.role});
  final String companyName;
  final UserRole role;
}

/// One-time code that links a WhatsApp number: the person sends
/// « LIER [code] » from that number before [expiresAt].
class WhatsAppLinkCode {
  const WhatsAppLinkCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;

  /// The message to send, as typed in WhatsApp.
  String get message => 'LIER $code';

  factory WhatsAppLinkCode.fromJson(Map<String, dynamic> json) =>
      WhatsAppLinkCode(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      );
}

class Member {
  const Member({
    required this.name,
    required this.email,
    required this.role,
    this.pending = false,
  });
  final String name;
  final String email;
  final UserRole role;

  /// Invited, has not created an account yet.
  final bool pending;
}

/// Reimbursement rule of one category.
class PolicyRule {
  const PolicyRule({
    required this.category,
    required this.limitCents,
    this.receiptRequired = true,
  });
  final String category;
  final int limitCents;
  final bool receiptRequired;

  factory PolicyRule.fromJson(Map<String, dynamic> json) => PolicyRule(
    category: json['category'] as String,
    limitCents: (json['limit_cents'] as num).toInt(),
    receiptRequired: (json['receipt_required'] as bool?) ?? true,
  );
}

/// The company's policy that imported or typed rules can change, besides
/// the limits per category. Without any, REMBO's defaults.
class CompanyPolicy {
  const CompanyPolicy({
    this.deadlineDays = 60,
    this.projectRequired = false,
    this.document,
  });
  static const defaults = CompanyPolicy();

  /// An expense older than this is flagged at submission.
  final int deadlineDays;

  /// An expense without project or client is flagged at submission.
  final bool projectRequired;

  /// The imported document the rules come from; null with REMBO's rules.
  final PolicyDocument? document;

  factory CompanyPolicy.fromJson(Map<String, dynamic> json) => CompanyPolicy(
    deadlineDays: (json['deadline_days'] as num?)?.toInt() ?? 60,
    projectRequired: json['project_required'] == true,
    document: json['policy_document'] is Map
        ? PolicyDocument.fromJson(
            Map<String, dynamic>.from(json['policy_document'] as Map),
          )
        : null,
  );

  Map<String, Object?> toJson() => {
    'deadline_days': deadlineDays,
    'project_required': projectRequired,
    'policy_document': document?.toJson(),
  };
}

/// An imported policy, as applied by a manager.
class PolicyDocument {
  const PolicyDocument({
    required this.name,
    this.summary = '',
    this.notApplied = const [],
    this.appliedAt,
    this.appliedBy = '',
  });
  final String name;
  final String summary;

  /// Rules read in the document that REMBO does not check by itself.
  final List<String> notApplied;
  final DateTime? appliedAt;
  final String appliedBy;

  factory PolicyDocument.fromJson(Map<String, dynamic> json) => PolicyDocument(
    name: json['name'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    notApplied: [
      for (final n in json['not_applied'] as List? ?? const [])
        if (n is String) n,
    ],
    appliedAt: DateTime.tryParse(json['applied_at'] as String? ?? '')
        ?.toLocal(),
    appliedBy: json['applied_by'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'summary': summary,
    'not_applied': notApplied,
    'applied_at': appliedAt?.toUtc().toIso8601String(),
    'applied_by': appliedBy,
  };
}

/// What the reader understood in a policy document: proposals, applied
/// only once a manager has checked them. A null value: the document says
/// nothing about it, the current rule stays.
class PolicyProposal {
  const PolicyProposal({
    required this.documentName,
    this.summary = '',
    this.deadlineDays,
    this.projectRequired,
    this.rules = const [],
    this.notApplied = const [],
  });
  final String documentName;
  final String summary;
  final int? deadlineDays;
  final bool? projectRequired;
  final List<PolicyRule> rules;
  final List<String> notApplied;

  bool get isEmpty =>
      deadlineDays == null &&
      projectRequired == null &&
      rules.isEmpty &&
      notApplied.isEmpty;

  factory PolicyProposal.fromJson(
    Map<String, dynamic> json, {
    required String documentName,
  }) => PolicyProposal(
    documentName: documentName,
    summary: json['summary'] as String? ?? '',
    deadlineDays: (json['deadline_days'] as num?)?.toInt(),
    projectRequired: json['project_required'] as bool?,
    rules: [
      for (final r in json['rules'] as List? ?? const [])
        if (r is Map) PolicyRule.fromJson(Map<String, dynamic>.from(r)),
    ],
    notApplied: [
      for (final n in json['not_applied'] as List? ?? const [])
        if (n is String) n,
    ],
  );

  /// As apply_policy reads it.
  Map<String, Object?> toJson() => {
    'deadline_days': ?deadlineDays,
    'project_required': ?projectRequired,
    'rules': [for (final r in rules) r.toJson()],
    'document': {
      'name': documentName,
      'summary': summary,
      'not_applied': notApplied,
    },
  };
}

/// A policy document picked by a manager, ready for the reader: its text,
/// or its pages as pictures (PNG or JPEG).
class PolicySource {
  const PolicySource.text(this.fileName, String this.text) : pages = const [];
  const PolicySource.pages(this.fileName, this.pages) : text = null;
  final String fileName;
  final String? text;
  final List<Uint8List> pages;
}

class ExportBatch {
  const ExportBatch({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.count,
    required this.totalCents,
    this.vatCents = 0,
    this.csv,
  });
  final String id;
  final String fileName;
  final DateTime createdAt;
  final int count;
  final int totalCents;

  /// VAT total recorded by the server for the batch.
  final int vatCents;

  /// File content, available for the batch created in this session.
  final String? csv;

  factory ExportBatch.fromJson(Map<String, dynamic> json, {String? csv}) =>
      ExportBatch(
        id: json['id'] as String,
        fileName: json['file_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        count: (json['expense_count'] as num).toInt(),
        totalCents: (json['total_cents'] as num).toInt(),
        vatCents: (json['vat_cents'] as num?)?.toInt() ?? 0,
        csv: csv,
      );
}

/// How sure an agent is of a value it proposes.
enum Confidence {
  high('Sûr'),
  medium('Probable'),
  low('À vérifier');

  const Confidence(this._label);
  final String _label;
  String get label => tr(_label);

  static Confidence parse(String? name) =>
      values.firstWhere((c) => c.name == name, orElse: () => medium);
}

/// Why an agent proposes a value, and how sure it is. [reason] is French,
/// shown through [trData].
class FieldNote {
  const FieldNote(this.confidence, this.reason);
  final Confidence confidence;
  final String reason;

  Map<String, dynamic> toJson() => {
    'confidence': confidence.name,
    'reason': reason,
  };
}

/// Values read on a receipt, when a reader is available.
class ReceiptReading {
  const ReceiptReading({
    this.supplier,
    this.supplierIce,
    this.date,
    this.amountCents,
    this.vatCents,
    this.vatRate,
    this.currency,
    this.unreadable = false,
    this.simulated = false,
    this.notes = const {},
    this.engine = 'device',
  });
  final String? supplier;
  final String? supplierIce;
  final DateTime? date;
  final int? amountCents;
  final int? vatCents;

  /// VAT rate printed on the receipt, in percent.
  final int? vatRate;

  /// Currency printed on the receipt (MAD, EUR, USD, GBP), when it says.
  final String? currency;
  final bool unreadable;

  /// Demo values, not read from the picture.
  final bool simulated;

  /// For each field read (supplier, ice, date, amount, vat, rate,
  /// currency): how it was found and how sure the reader is.
  final Map<String, FieldNote> notes;

  /// Who read it: `device` (on the phone) or `server`.
  final String engine;

  /// The fields a submission needs that the reader could not find.
  List<String> get missing => [
    if (supplier == null) 'supplier',
    if (date == null) 'date',
    if (amountCents == null) 'amount',
  ];
}

/// A problem the user can act on; [message] is shown as is.
class RemboException implements Exception {
  const RemboException(this.message, {this.network = false});
  final String message;

  /// The request did not reach the server: the action can be retried.
  final bool network;

  @override
  String toString() => message;
}

// --- Full JSON, used by the on-device store --------------------------------

extension ExpenseStorage on Expense {
  /// Every field, in the shape [Expense.fromJson] reads.
  Map<String, dynamic> toJson() => {
    ...toWritableJson(),
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'status': status.code,
    'receipt_path': receiptPath,
    'flags': [
      for (final f in flags) {'kind': f.kind.name, 'message': f.message},
    ],
    'status_events': [
      for (final e in events)
        {
          'to_status': e.status.code,
          'created_at': e.at.toUtc().toIso8601String(),
          'actor_name': e.actorName,
          'actor_kind': e.byAgent ? 'agent' : 'user',
          'reason': e.reason,
        },
    ],
    'source': source.name,
    'transcript': transcript,
    'voice_path': voicePath,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

extension AppUserStorage on AppUser {
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'company_id': companyId,
    'company_name': companyName,
    'whatsapp_phone': whatsappPhone,
  };
}

AppUser appUserFromJson(Map<String, dynamic> json) => AppUser(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: (json['full_name'] as String?) ?? '',
  role: UserRole.parse(json['role'] as String?),
  companyId: json['company_id'] as String?,
  companyName: (json['company_name'] as String?) ?? '',
  whatsappPhone: json['whatsapp_phone'] as String?,
);

extension PolicyRuleStorage on PolicyRule {
  Map<String, dynamic> toJson() => {
    'category': category,
    'limit_cents': limitCents,
    'receipt_required': receiptRequired,
  };
}

extension ExportBatchStorage on ExportBatch {
  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'created_at': createdAt.toUtc().toIso8601String(),
    'expense_count': count,
    'total_cents': totalCents,
    'vat_cents': vatCents,
    'csv': csv,
  };
}
