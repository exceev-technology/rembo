import 'package:flutter/foundation.dart';

enum ReceiptSource { camera, import }

enum DraftField {
  supplier('Fournisseur', required: true),
  date('Date', required: true),
  amount('Montant TTC', required: true),
  vat('TVA'),
  ice('ICE du fournisseur'),
  category('Catégorie', required: true),
  reason('Motif', required: true),
  project('Client ou projet');

  const DraftField(this.label, {this.required = false});
  final String label;
  final bool required;

  /// Fields the simulated reading can fill from the receipt.
  static const readable = [supplier, date, amount, vat, ice];
}

const expenseCategories = [
  'Repas',
  'Transport',
  'Hébergement',
  'Fournitures',
  'Autre',
];

/// The expense being declared. Lives only in memory for the demo: it is
/// shared by capture, review and summary so going back keeps every value.
class ExpenseDraft extends ChangeNotifier {
  ReceiptSource? receipt;
  bool unreadable = false;
  bool analyzed = false;

  /// Typed by hand, without a receipt to read.
  bool manual = false;
  final values = <DraftField, String>{};
  final proposed = <DraftField>{};

  bool get hasReceipt => receipt != null;

  String value(DraftField field) => values[field] ?? '';

  void attach(ReceiptSource source, {bool unreadable = false}) {
    receipt = source;
    manual = false;
    this.unreadable = unreadable;
    analyzed = false;
    values.clear();
    proposed.clear();
    notifyListeners();
  }

  void startManual() {
    receipt = null;
    unreadable = false;
    manual = true;
    analyzed = true;
    values.clear();
    proposed.clear();
    notifyListeners();
  }

  void clearReceipt() {
    manual = false;
    receipt = null;
    unreadable = false;
    analyzed = false;
    values.clear();
    proposed.clear();
    notifyListeners();
  }

  /// Fills the fields a reader would find on the fictional receipt.
  void simulateReading() {
    analyzed = true;
    if (!unreadable) {
      const read = {
        DraftField.supplier: 'Le Zellige · Rabat',
        DraftField.date: '27/10/2026',
        DraftField.amount: '380,00',
        DraftField.vat: '34,55',
        DraftField.ice: '001234567000089',
      };
      values.addAll(read);
      proposed.addAll(read.keys);
    }
    notifyListeners();
  }

  void set(DraftField field, String text) {
    values[field] = text;
    proposed.remove(field);
    notifyListeners();
  }

  /// Amount in centimes, or null when missing or not a positive number.
  int? get amountCentimes => parseAmount(value(DraftField.amount));

  /// Up to 9 digits and 2 decimals, read as integers: no floating point.
  static int? parseAmount(String text) {
    final normalized = text
        .replaceAll(RegExp(r'[\s\u202F]'), '')
        .replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final cents =
        int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return cents > 0 ? cents : null;
  }

  /// A real calendar day (rejects 31/02), between 2000 and [today].
  static DateTime? parseDate(String text, {DateTime? today}) {
    final m = _date.firstMatch(text.trim());
    if (m == null) return null;
    final day = int.parse(m[1]!);
    final month = int.parse(m[2]!);
    final year = int.parse(m[3]!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    final now = today ?? DateTime.now();
    if (year < 2000 || date.isAfter(DateTime(now.year, now.month, now.day))) {
      return null;
    }
    return date;
  }

  static final _date = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

  Map<DraftField, String> errors() {
    final errors = <DraftField, String>{};
    for (final field in DraftField.values) {
      if (field.required && value(field).trim().isEmpty) {
        errors[field] = field == DraftField.amount
            ? 'Montant absent : indiquez le total TTC du reçu.'
            : 'Champ obligatoire.';
      }
    }
    final date = value(DraftField.date).trim();
    if (date.isNotEmpty) {
      if (parseDate(date) == null) {
        errors[DraftField.date] =
            'Date invalide : une date passée au format JJ/MM/AAAA.';
      }
    }
    if (value(DraftField.amount).trim().isNotEmpty && amountCentimes == null) {
      errors[DraftField.amount] =
          'Montant invalide : 2 décimales au plus, ex. 380,00.';
    }
    return errors;
  }
}
