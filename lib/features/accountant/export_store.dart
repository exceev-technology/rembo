import 'package:flutter/foundation.dart';

import '../../core/format/formatters.dart';

class AccountingExpense {
  const AccountingExpense({
    required this.id,
    required this.date,
    required this.supplier,
    required this.employee,
    required this.amountCentimes,
    required this.vatCentimes,
    required this.category,
    this.project,
  });
  final String id;
  final DateTime date;
  final String supplier;
  final String employee;
  final int amountCentimes;
  final int vatCentimes;
  final String category;
  final String? project;
}

class ExportRecord {
  const ExportRecord({
    required this.fileName,
    required this.at,
    required this.count,
    required this.totalCentimes,
  });
  final String fileName;
  final DateTime at;
  final int count;
  final int totalCentimes;
}

/// Approved expenses waiting for export, the current selection and the
/// export history. In memory only: no file is written in V1.
class ExportStore extends ChangeNotifier {
  ExportStore(this.toExport, this.history);

  factory ExportStore.demo() => ExportStore(
    [
      AccountingExpense(
        id: 'acc-201',
        date: DateTime(2026, 10, 20),
        supplier: 'Train Al Boraq',
        employee: 'Youssef Benali',
        amountCentimes: 24900,
        vatCentimes: 2264,
        category: 'Transport',
        project: 'Client Atlas Logistique',
      ),
      AccountingExpense(
        id: 'acc-202',
        date: DateTime(2026, 10, 21),
        supplier: 'Le Zellige · Rabat',
        employee: 'Amina Berrada',
        amountCentimes: 38000,
        vatCentimes: 3455,
        category: 'Repas',
        project: 'Client Atlas Logistique',
      ),
      AccountingExpense(
        id: 'acc-203',
        date: DateTime(2026, 10, 22),
        supplier: 'Hôtel Atlas Agadir',
        employee: 'Nadia Tazi',
        amountCentimes: 132000,
        vatCentimes: 12000,
        category: 'Hébergement',
      ),
      AccountingExpense(
        id: 'acc-204',
        date: DateTime(2026, 10, 23),
        supplier: 'Papeterie Al Andalous',
        employee: 'Karim Alaoui',
        amountCentimes: 8750,
        vatCentimes: 1458,
        category: 'Fournitures',
        project: 'Projet interne',
      ),
      AccountingExpense(
        id: 'acc-205',
        date: DateTime(2026, 10, 24),
        supplier: 'Parking Marina',
        employee: 'Youssef Benali',
        amountCentimes: 3000,
        vatCentimes: 500,
        category: 'Transport',
      ),
    ],
    [
      ExportRecord(
        fileName: 'rembo-export-2026-10-15.csv',
        at: DateTime(2026, 10, 15, 18, 5),
        count: 7,
        totalCentimes: 412300,
      ),
    ],
  );

  static const categories = [
    'Repas',
    'Transport',
    'Hébergement',
    'Fournitures',
  ];

  final List<AccountingExpense> toExport;
  final List<ExportRecord> history;
  final selected = <String>{};

  List<AccountingExpense> get selection =>
      toExport.where((e) => selected.contains(e.id)).toList();

  int get selectedTotal =>
      selection.fold(0, (sum, e) => sum + e.amountCentimes);

  int get pendingTotal => toExport.fold(0, (sum, e) => sum + e.amountCentimes);

  void toggle(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  /// Selects every [visible] expense, or clears them when all are selected.
  void toggleAll(Iterable<AccountingExpense> visible) {
    final ids = visible.map((e) => e.id).toSet();
    if (selected.containsAll(ids)) {
      selected.removeAll(ids);
    } else {
      selected.addAll(ids);
    }
    notifyListeners();
  }

  /// Simulates the export: the selection leaves the list and joins history.
  ExportRecord export(DateTime now) {
    final chosen = selection;
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final record = ExportRecord(
      fileName: 'rembo-export-$day.csv',
      at: now,
      count: chosen.length,
      totalCentimes: chosen.fold(0, (sum, e) => sum + e.amountCentimes),
    );
    toExport.removeWhere((e) => selected.contains(e.id));
    selected.clear();
    history.insert(0, record);
    notifyListeners();
    return record;
  }

  static const csvHeader = 'date;fournisseur;montant_ttc;tva;categorie;projet';

  /// The lines the CSV file would contain (semicolons, decimal comma).
  static List<String> csvLines(List<AccountingExpense> expenses) {
    String amount(int c) => formatMad(c).replaceAll(RegExp(r' |MAD'), '');
    String date(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return [
      csvHeader,
      for (final e in expenses)
        [
          date(e.date),
          e.supplier,
          amount(e.amountCentimes),
          amount(e.vatCentimes),
          e.category,
          e.project ?? '',
        ].join(';'),
    ];
  }
}
