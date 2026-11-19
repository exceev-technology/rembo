import 'models.dart';

/// Accounting CSV as documented in the wiki (Architecture → CSV export):
/// UTF-8, header row, decimal point, ISO dates, one row per expense.
abstract final class CsvExport {
  static const columns = [
    'expense_id',
    'expense_date',
    'employee',
    'supplier_name',
    'supplier_ice',
    'category',
    'allocation',
    'amount_ttc_mad',
    'vat_rate',
    'vat_amount_mad',
    'amount_ht_mad',
    'currency',
    'amount_paid',
    'reason',
    'approved_by',
    'approved_at',
    'export_batch_id',
  ];

  static String fileName(DateTime day) => 'rembo_${isoDay(day)}.csv';

  static String build(
    List<Expense> expenses, {
    required String batchId,
    String delimiter = ';',
  }) {
    final rows = <List<String>>[
      columns,
      for (final e in expenses)
        [
          e.id,
          e.date == null ? '' : isoDay(e.date!),
          e.employeeName,
          e.supplier,
          e.supplierIce,
          e.category,
          e.project,
          _amount(e.amountCents),
          e.vatRate?.toString() ?? '',
          _amount(e.vatCents),
          _amount(e.amountCents - e.vatCents),
          e.currency,
          e.foreignCurrency && e.foreignAmountCents != null
              ? _amount(e.foreignAmountCents!)
              : '',
          e.reason,
          e.lastDecision == null
              ? ''
              : (e.lastDecision!.byAgent
                    ? 'Contrôle automatique'
                    : e.lastDecision!.actorName),
          e.lastDecision == null ? '' : isoDay(e.lastDecision!.at),
          batchId,
        ],
    ];
    return rows
        .map((r) => r.map((c) => _cell(c, delimiter)).join(delimiter))
        .join('\r\n');
  }

  static String _amount(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// Quotes a cell when needed, and neutralises spreadsheet formulas.
  static String _cell(String value, String delimiter) {
    var v = value;
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0]) && !_isNumber(v)) v = "'$v";
    final mustQuote =
        v.contains(delimiter) ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    return mustQuote ? '"${v.replaceAll('"', '""')}"' : v;
  }

  static bool _isNumber(String v) => RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v);
}
