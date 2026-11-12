import 'package:flutter/foundation.dart';

import '../../core/demo/demo_expenses.dart';

class ApprovalRequest {
  ApprovalRequest({
    required this.id,
    required this.employee,
    required this.supplier,
    required this.date,
    required this.amountCentimes,
    required this.category,
    this.status = DemoExpenseStatus.submitted,
    this.alerts = const [],
    this.mine = false,
  });
  final String id;
  final String employee;
  final String supplier;
  final DateTime date;
  final int amountCentimes;
  final String category;
  DemoExpenseStatus status;
  final List<String> alerts;

  /// The manager's own expense: they cannot approve it themselves.
  final bool mine;
}

class Decision {
  const Decision({
    required this.employee,
    required this.supplier,
    required this.amountCentimes,
    required this.approved,
    required this.at,
    this.reason,
  });
  final String employee;
  final String supplier;
  final int amountCentimes;
  final bool approved;
  final DateTime at;
  final String? reason;
}

/// Local, in-memory state of the manager space. Nothing is saved.
class ApprovalStore extends ChangeNotifier {
  ApprovalStore(this.requests, this.history);

  factory ApprovalStore.demo() => ApprovalStore(
    [
      ApprovalRequest(
        id: 'req-101',
        employee: 'Youssef Benali',
        supplier: 'Train Al Boraq',
        date: DateTime(2026, 10, 27),
        amountCentimes: 24900,
        category: 'Transport',
      ),
      ApprovalRequest(
        id: 'req-102',
        employee: 'Salma Idrissi',
        supplier: 'Restaurant Dar Naji',
        date: DateTime(2026, 10, 28),
        amountCentimes: 61000,
        category: 'Repas',
        alerts: ['Montant au-dessus du plafond repas de 500,00 MAD.'],
      ),
      ApprovalRequest(
        id: 'req-103',
        employee: 'Karim Alaoui',
        supplier: 'Papeterie Al Andalous',
        date: DateTime(2026, 10, 28),
        amountCentimes: 8750,
        category: 'Fournitures',
        alerts: ['ICE du fournisseur absent du justificatif.'],
      ),
      ApprovalRequest(
        id: 'req-104',
        employee: 'Nadia Tazi (vous)',
        supplier: 'Hôtel Atlas Agadir',
        date: DateTime(2026, 10, 25),
        amountCentimes: 132000,
        category: 'Hébergement',
        mine: true,
      ),
      ApprovalRequest(
        id: 'req-105',
        employee: 'Youssef Benali',
        supplier: 'Parking Marina',
        date: DateTime(2026, 10, 24),
        amountCentimes: 3000,
        category: 'Transport',
        status: DemoExpenseStatus.approved,
      ),
    ],
    [
      Decision(
        employee: 'Youssef Benali',
        supplier: 'Parking Marina',
        amountCentimes: 3000,
        approved: true,
        at: DateTime(2026, 10, 25, 9, 12),
      ),
      Decision(
        employee: 'Salma Idrissi',
        supplier: 'Boutique Cadeaux Fès',
        amountCentimes: 45000,
        approved: false,
        at: DateTime(2026, 10, 22, 17, 40),
        reason: 'Cadeau client hors politique de dépenses.',
      ),
    ],
  );

  final List<ApprovalRequest> requests;
  final List<Decision> history;

  ApprovalRequest byId(String id) => requests.firstWhere((r) => r.id == id);

  List<ApprovalRequest> get pending =>
      requests.where((r) => r.status == DemoExpenseStatus.submitted).toList();

  void approve(String id) => _decide(id, approved: true);

  void reject(String id, String reason) =>
      _decide(id, approved: false, reason: reason);

  void _decide(String id, {required bool approved, String? reason}) {
    final request = byId(id);
    assert(!request.mine, 'Self-approval is not allowed.');
    request.status = approved
        ? DemoExpenseStatus.approved
        : DemoExpenseStatus.rejected;
    history.insert(
      0,
      Decision(
        employee: request.employee,
        supplier: request.supplier,
        amountCentimes: request.amountCentimes,
        approved: approved,
        reason: reason,
        at: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
