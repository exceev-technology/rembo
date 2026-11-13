/// Fictional, immutable fixtures only. Amounts are integer centimes of MAD.
enum DemoExpenseStatus { draft, submitted, approved, rejected }

class DemoExpense {
  const DemoExpense({
    required this.id,
    required this.supplier,
    required this.date,
    required this.amountCentimes,
    required this.status,
  });
  final String id;
  final String supplier;
  final DateTime date;
  final int amountCentimes;
  final DemoExpenseStatus status;
}

final demoExpenses = List<DemoExpense>.unmodifiable([
  DemoExpense(
    id: 'demo-001',
    supplier: 'Café Atlas',
    date: DateTime(2026, 10, 26),
    amountCentimes: 16500,
    status: DemoExpenseStatus.draft,
  ),
  DemoExpense(
    id: 'demo-002',
    supplier: 'Transport Horizon',
    date: DateTime(2026, 10, 27),
    amountCentimes: 4500,
    status: DemoExpenseStatus.submitted,
  ),
  DemoExpense(
    id: 'demo-003',
    supplier: 'Hôtel Mogador',
    date: DateTime(2026, 10, 27),
    amountCentimes: 76000,
    status: DemoExpenseStatus.approved,
  ),
  DemoExpense(
    id: 'demo-004',
    supplier: 'Librairie Al Kitab',
    date: DateTime(2026, 10, 28),
    amountCentimes: 12000,
    status: DemoExpenseStatus.rejected,
  ),
]);
