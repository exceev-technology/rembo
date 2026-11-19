part of 'local_backend.dart';

/// The same engine with fictional people and expenses, kept in memory.
/// Nothing is saved and any password is accepted.
class DemoBackend extends LocalBackend {
  /// [autoApprove] lets the control approve compliant expenses itself;
  /// by default, as in a new company, a manager confirms them.
  DemoBackend({
    super.clock,
    super.latency = const Duration(milliseconds: 250),
    bool autoApprove = false,
  }) {
    _users.addAll([marius, ahmed, salma, nadia]);
    if (autoApprove) _autoApprove.add('c-atlas');
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
  Future<bool> _passwordMatches(AppUser user, String password) async =>
      password.isNotEmpty;

  /// A code shown as in the real app; no message is received in the demo,
  /// so it never links a number.
  @override
  Future<WhatsAppLinkCode> requestWhatsAppCode() async {
    await _latency();
    final code = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    return WhatsAppLinkCode(
      code: code,
      expiresAt: _now.add(const Duration(minutes: 10)),
    );
  }

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
