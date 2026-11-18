import '../format/formatters.dart';
import 'models.dart';

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
