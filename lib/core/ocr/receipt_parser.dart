import '../data/models.dart';

/// Turns the text recognised on a receipt into proposals: supplier, date,
/// total with taxes, VAT and ICE. Pure Dart, no phone needed: the rules
/// are tested on written receipts.
///
/// [rows] are the lines of the receipt from top to bottom, each one being
/// what is printed on the same height (« TOTAL TTC   240,00 »).
///
/// A proposal is only made when the receipt says it; nothing is guessed
/// from a category or a usual rate. The person checks everything on the
/// form afterwards.
ReceiptReading parseReceiptText(List<String> rows, {DateTime? today}) {
  final lines = [
    for (final r in rows)
      if (r.trim().isNotEmpty) r.replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  final letters = lines.join().replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;
  final notes = <String, FieldNote>{};
  final total = _total(lines, notes);
  final date = _date(lines, today ?? DateTime.now());
  if (letters < 8 || (total == null && date == null)) {
    return const ReceiptReading(unreadable: true);
  }
  final vat = total == null ? null : _vat(lines, total, notes);
  final supplier = _supplier(lines);
  final ice = _ice(lines);
  final rate = _vatRate(lines, total, vat, notes);
  final currency = _currency(lines);
  if (date != null) {
    notes['date'] = const FieldNote(
      Confidence.high,
      'Date imprimée sur le ticket',
    );
  }
  if (supplier != null) {
    notes['supplier'] = const FieldNote(
      Confidence.medium,
      'Première ligne du ticket qui ressemble à un nom',
    );
  }
  if (ice != null) {
    notes['ice'] = const FieldNote(
      Confidence.high,
      'Lu après la mention « ICE »',
    );
  }
  if (currency != null) {
    notes['currency'] = const FieldNote(
      Confidence.high,
      'Devise imprimée sur le ticket',
    );
  }
  return ReceiptReading(
    supplier: supplier,
    supplierIce: ice,
    date: date,
    amountCents: total,
    vatCents: vat,
    vatRate: rate,
    currency: currency,
    notes: notes,
  );
}

// Currency and VAT rate ----------------------------------------------------

final _mad = RegExp(
  r'\b(?:mad|dhs?|dirhams?)\b|درهم|د\.م',
  caseSensitive: false,
);
final _foreign = <String, RegExp>{
  'EUR': RegExp(r'€|\beur(?:os?)?\b', caseSensitive: false),
  'USD': RegExp(r'\$|\busd\b', caseSensitive: false),
  'GBP': RegExp(r'£|\bgbp\b', caseSensitive: false),
};

/// The currency the receipt prints. Dirhams win when they appear at all:
/// a Moroccan receipt may quote a euro price as a reminder.
String? _currency(List<String> lines) {
  final text = lines.join(' ');
  if (_mad.hasMatch(text)) return 'MAD';
  for (final e in _foreign.entries) {
    if (e.value.hasMatch(text)) return e.key;
  }
  return null;
}

/// The rate printed on the VAT lines, when there is a single one; else the
/// Moroccan rate that the printed VAT and total agree on.
int? _vatRate(
  List<String> lines,
  int? total,
  int? vat,
  Map<String, FieldNote> notes,
) {
  final printed = <int>{};
  for (final line in lines) {
    if (!_vatLine.hasMatch(line)) continue;
    for (final m in _rate.allMatches(line)) {
      final r = int.parse(m[1]!);
      if (vatRates.contains(r)) printed.add(r);
    }
  }
  if (printed.length == 1) {
    notes['rate'] = const FieldNote(
      Confidence.high,
      'Taux imprimé sur le ticket',
    );
    return printed.single;
  }
  if (total == null || vat == null || vat <= 0) return null;
  for (final r in vatRates.where((r) => r > 0)) {
    final expected = total * r / (100 + r);
    if ((vat - expected).abs() <= (expected * .005).clamp(2, 100)) {
      notes['rate'] = const FieldNote(
        Confidence.medium,
        'Taux qui correspond à la TVA et au total imprimés',
      );
      return r;
    }
  }
  return null;
}

// Amounts ---------------------------------------------------------------

/// « 1 240,00 », « 1.240,00 », « 240.00 », « 240,5 » — always with decimals:
/// a number without them is a quantity, a table or a ticket number.
final _money = RegExp(
  r'(?<![\d.,])(\d{1,3}(?:[ .]\d{3})+|\d{1,7})[.,](\d{1,2})(?![\d.,]|\s?%)',
);

List<int> _amounts(String line) => [
  for (final m in _money.allMatches(line))
    int.parse(m[1]!.replaceAll(RegExp(r'[ .]'), '')) * 100 +
        int.parse(m[2]!.padRight(2, '0')),
];

final _strongTotal = RegExp(
  r'net\s*[àa]\s*payer|total\s*t\.?t\.?c|montant\s*t\.?t\.?c|\bt\.?t\.?c\b|'
  r'total\s*[àa]\s*payer|montant\s*[àa]\s*payer',
  caseSensitive: false,
);
final _plainTotal = RegExp(r'\btotal\b|\bmontant\b', caseSensitive: false);
final _notTotal = RegExp(
  r'\bh\.?t\b|hors\s*taxe|t\.?v\.?a|sous.?total|remise|rendu|esp[eè]ces|'
  r're[çc]u\b|carte|cb\b|monnaie',
  caseSensitive: false,
);

/// Amount on [index], or on the next line when the label stands alone.
int? _amountAt(List<String> lines, int index) {
  final here = _amounts(lines[index]);
  if (here.isNotEmpty) return here.last;
  if (index + 1 < lines.length) {
    final next = _amounts(lines[index + 1]);
    if (next.length == 1 &&
        !RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(lines[index + 1])) {
      return next.single;
    }
  }
  return null;
}

int? _total(List<String> lines, Map<String, FieldNote> notes) {
  // The last « net à payer / total TTC » wins: it closes the receipt.
  for (var i = lines.length - 1; i >= 0; i--) {
    if (_strongTotal.hasMatch(lines[i])) {
      final amount = _amountAt(lines, i);
      if (amount != null && amount > 0) {
        notes['amount'] = const FieldNote(
          Confidence.high,
          'Lu sur la ligne du total TTC ou du net à payer',
        );
        return amount;
      }
    }
  }
  for (var i = lines.length - 1; i >= 0; i--) {
    if (_plainTotal.hasMatch(lines[i]) && !_notTotal.hasMatch(lines[i])) {
      final amount = _amountAt(lines, i);
      if (amount != null && amount > 0) {
        notes['amount'] = const FieldNote(
          Confidence.medium,
          'Lu sur une ligne « total » sans mention TTC',
        );
        return amount;
      }
    }
  }
  // No label at all: the largest amount that is not what was handed over.
  var largest = 0;
  for (final line in lines) {
    if (RegExp(
      r'rendu|esp[eè]ces|re[çc]u\b|monnaie',
      caseSensitive: false,
    ).hasMatch(line)) {
      continue;
    }
    for (final a in _amounts(line)) {
      if (a > largest) largest = a;
    }
  }
  if (largest <= 0) return null;
  notes['amount'] = const FieldNote(
    Confidence.low,
    'Aucun total imprimé : plus grand montant du ticket',
  );
  return largest;
}

final _vatLine = RegExp(r't\.?\s?v\.?\s?a\b|\bvat\b', caseSensitive: false);
final _rate = RegExp(r'(\d{1,2})(?:[.,]\d{1,2})?\s?%');

/// VAT printed on the receipt. A line often carries the base and the tax
/// (« TVA 20% 200,00 40,00 »): the tax is the amount that matches the rate
/// when one is printed, else the smallest. Several rates are added up.
int? _vat(List<String> lines, int total, Map<String, FieldNote> notes) {
  int? pick(String line) {
    final amounts = _amounts(line).where((a) => a > 0 && a < total).toList();
    if (amounts.isEmpty) return null;
    final rate = _rate.firstMatch(line);
    if (rate != null) {
      final r = int.parse(rate[1]!);
      for (final a in amounts) {
        // From the base (a = base × r) or from the total with taxes.
        final fromTotal = (total * r / (100 + r)).round();
        if ((a - fromTotal).abs() <= 2) return a;
        for (final base in amounts) {
          if (base != a && (a - (base * r / 100).round()).abs() <= 2) return a;
        }
      }
    }
    return amounts.reduce((a, b) => a < b ? a : b);
  }

  for (final line in lines) {
    if (RegExp(
      r'total\s*t\.?\s?v\.?\s?a',
      caseSensitive: false,
    ).hasMatch(line)) {
      final v = pick(line);
      if (v != null) {
        notes['vat'] = const FieldNote(
          Confidence.high,
          'Lu sur la ligne du total de TVA',
        );
        return v;
      }
    }
  }
  var sum = 0;
  for (final line in lines) {
    if (!_vatLine.hasMatch(line)) continue;
    // « Total TTC dont TVA » style lines are handled by pick: the total
    // itself is excluded because it is not below the total.
    final v = pick(line);
    if (v != null) sum += v;
  }
  if (sum <= 0 || sum >= total) return null;
  notes['vat'] = const FieldNote(
    Confidence.medium,
    'Somme des lignes de TVA du ticket',
  );
  return sum;
}

// Date --------------------------------------------------------------------

const _months = {
  'jan': 1,
  'fev': 2,
  'fév': 2,
  'mar': 3,
  'avr': 4,
  'mai': 5,
  'juin': 6,
  'jun': 6,
  'juil': 7,
  'jul': 7,
  'aou': 8,
  'aoû': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
  'déc': 12,
};

DateTime? _valid(int year, int month, int day, DateTime today) {
  if (year < 100) year += 2000;
  final d = DateTime(year, month, day);
  if (d.year != year || d.month != month || d.day != day) return null;
  if (year < 2000 || d.isAfter(DateTime(today.year, today.month, today.day))) {
    return null;
  }
  return d;
}

DateTime? _date(List<String> lines, DateTime today) {
  final numeric = RegExp(
    r'(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)',
  );
  final iso = RegExp(r'(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)');
  final written = RegExp(
    r'(?<!\d)(\d{1,2})\s+([A-Za-zéûÉÛ]{3,9})\.?\s+(\d{4})(?!\d)',
  );
  for (final line in lines) {
    for (final m in iso.allMatches(line)) {
      final d = _valid(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
        today,
      );
      if (d != null) return d;
    }
    for (final m in numeric.allMatches(line)) {
      final d = _valid(
        int.parse(m[3]!),
        int.parse(m[2]!),
        int.parse(m[1]!),
        today,
      );
      if (d != null) return d;
    }
    for (final m in written.allMatches(line)) {
      final name = m[2]!.toLowerCase();
      final month = _months.entries
          .where((e) => name.startsWith(e.key))
          .map((e) => e.value)
          .firstOrNull;
      if (month == null) continue;
      final d = _valid(int.parse(m[3]!), month, int.parse(m[1]!), today);
      if (d != null) return d;
    }
  }
  return null;
}

// Supplier and ICE --------------------------------------------------------

/// The ICE is the 15-digit company identifier printed on Moroccan invoices.
String? _ice(List<String> lines) {
  for (final line in lines) {
    final m = RegExp(
      r'\bI\.?C\.?E\b\D{0,6}((?:\d\s?){15})(?!\d)',
      caseSensitive: false,
    ).firstMatch(line);
    if (m != null) return m[1]!.replaceAll(' ', '');
  }
  return null;
}

final _notAName = RegExp(
  r'ticket|facture|re[çc]u|bienvenue|merci|t[ée]l|fax|adresse|www\.|http|@|'
  r'caisse|table|serveur|date|heure|\bice\b|\bif\b|\brc\b|patente|tva|total|'
  r'duplicata|client',
  caseSensitive: false,
);

/// The shop's name is printed at the top: the first line that reads as a
/// name, not as a date, a number, an address detail or a heading.
String? _supplier(List<String> lines) {
  for (final line in lines.take(6)) {
    final letters = line.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length;
    final digits = line.replaceAll(RegExp(r'\D'), '').length;
    if (letters < 3 || digits > letters || _notAName.hasMatch(line)) continue;
    final name = line.replaceAll(
      RegExp(r'^[^A-Za-zÀ-ÿ0-9]+|[^A-Za-zÀ-ÿ0-9.)]+$'),
      '',
    );
    if (name.length < 3) continue;
    final short = name.length > 60 ? name.substring(0, 60).trim() : name;
    // « CAFE ATLAS » reads better as « Cafe Atlas » in a list.
    return short == short.toUpperCase()
        ? short
              .toLowerCase()
              .split(' ')
              .map(
                (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
              )
              .join(' ')
        : short;
  }
  return null;
}
