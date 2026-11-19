/// Compliance agent: what the automatic control finds on an expense.
///
/// The control that decides runs on the server (SQL `control_expense`,
/// supabase/migrations). This Dart copy runs it on the phone, for the
/// local and demo backends and to show the person, before submitting,
/// what will be reported. Keep both in step.
library;

import '../data/models.dart';
import '../format/formatters.dart';

/// « Hôtel  Farah » and « hôtel farah » are the same supplier, as the SQL
/// control compares them.
String _sameSupplier(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

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
  bool counts(Expense o) =>
      o.id != expense.id &&
      o.employeeId == expense.employeeId &&
      o.amountCents == expense.amountCents &&
      o.status != ExpenseStatus.draft &&
      o.status != ExpenseStatus.rejected;
  if (others.any((o) => counts(o) && o.date == expense.date)) {
    flags.add(
      const ExpenseFlag(
        FlagKind.duplicate,
        'Même date et même montant qu’une dépense déjà déclarée',
      ),
    );
  } else if (expense.date != null &&
      others.any(
        (o) =>
            counts(o) &&
            o.date != null &&
            o.date!.difference(expense.date!).inDays.abs() <= 3 &&
            _sameSupplier(o.supplier) == _sameSupplier(expense.supplier),
      )) {
    flags.add(
      const ExpenseFlag(
        FlagKind.duplicate,
        'Même fournisseur et même montant à quelques jours d’intervalle',
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
  if (expense.foreignCurrency) {
    flags.add(
      const ExpenseFlag(
        FlagKind.ambiguity,
        'Dépense en devise : conversion en dirhams à vérifier',
      ),
    );
  }
  final rate = expense.vatRate ?? 0;
  if (rate > 0 && expense.vatCents > 0) {
    final expected = expense.amountCents * rate / (100 + rate);
    final tolerance = expected * .02 > 100 ? expected * .02 : 100;
    if ((expense.vatCents - expected).abs() > tolerance) {
      flags.add(
        const ExpenseFlag(
          FlagKind.ambiguity,
          'TVA incohérente avec le taux indiqué',
        ),
      );
    }
  }
  if (expense.supplierIce.isNotEmpty &&
      !RegExp(r'^\d{15}$').hasMatch(expense.supplierIce)) {
    flags.add(
      const ExpenseFlag(
        FlagKind.ambiguity,
        'ICE du fournisseur invalide : 15 chiffres attendus',
      ),
    );
  }
  return flags;
}
