/// Export agent: prepares the accounting batch and checks it.
///
/// Before the export it adds up the batch (count, amount with taxes, VAT,
/// amount without taxes) and points out what an accountant would stop on.
/// After the export it compares those totals with the batch the server
/// recorded: they must be identical (Testing Protocol, control C3). It
/// never runs the accounting import: the accountant stays responsible.
library;

import '../data/models.dart';

/// Accounts commonly used in the Moroccan chart of accounts (CGNC) for
/// these categories. A proposal only: the company's accountant decides.
const suggestedAccounts = <String, String>{
  'Transport': '6142',
  'Repas': '6143',
  'Hébergement': '6143',
  'Fournitures': '6125',
};

/// Something an accountant would look at before importing. [message] is
/// French, shown through `trData`.
class ExportIssue {
  const ExportIssue(this.expense, this.message);
  final Expense expense;
  final String message;
}

class ExportCheck {
  const ExportCheck({
    required this.count,
    required this.totalCents,
    required this.vatCents,
    required this.issues,
    required this.missingAccounts,
  });

  final int count;
  final int totalCents;
  final int vatCents;
  final List<ExportIssue> issues;

  /// Categories of the batch without an accounting account.
  final Set<String> missingAccounts;

  int get netCents => totalCents - vatCents;

  /// The batch the server recorded holds exactly these totals.
  bool matches(ExportBatch batch) =>
      batch.count == count &&
      batch.totalCents == totalCents &&
      batch.vatCents == vatCents;
}

ExportCheck prepareExport(
  List<Expense> expenses, {
  required Map<String, String> accounts,
}) {
  final issues = <ExportIssue>[];
  final missing = <String>{};
  for (final e in expenses) {
    if (e.vatCents > 0 && e.supplierIce.isEmpty) {
      issues.add(
        ExportIssue(e, 'TVA non récupérable : ICE du fournisseur absent'),
      );
    }
    if (!e.hasReceipt) issues.add(ExportIssue(e, 'Sans justificatif'));
    if (e.foreignCurrency) {
      issues.add(ExportIssue(e, 'Payée en devise : conversion à reporter'));
    }
    if ((accounts[e.category] ?? '').isEmpty) missing.add(e.category);
  }
  return ExportCheck(
    count: expenses.length,
    totalCents: expenses.fold(0, (s, e) => s + e.amountCents),
    vatCents: expenses.fold(0, (s, e) => s + e.vatCents),
    issues: issues,
    missingAccounts: missing,
  );
}
