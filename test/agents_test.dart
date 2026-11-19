import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/agents/classification_agent.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/ocr/receipt_parser.dart';

final _today = DateTime(2026, 11, 20);

Expense _past(
  String supplier,
  String category, {
  String project = '',
  String ice = '',
  ExpenseStatus status = ExpenseStatus.approved,
  int daysAgo = 3,
}) => Expense(
  id: '$supplier-$category-$daysAgo',
  employeeId: 'u1',
  employeeName: 'Omar',
  supplier: supplier,
  supplierIce: ice,
  category: category,
  project: project,
  status: status,
  createdAt: _today.subtract(Duration(days: daysAgo)),
);

void main() {
  group('Reading agent', () {
    test('each field says how it was found and how sure it is', () {
      final r = parseReceiptText([
        'CAFE ATLAS',
        'ICE : 001234567000089',
        'Date : 10/11/2026',
        'TOTAL HT 218,18',
        'TVA 10% 21,82',
        'TOTAL TTC 240,00 DH',
      ], today: _today);
      expect(r.notes['amount']!.confidence, Confidence.high);
      expect(r.notes['date']!.confidence, Confidence.high);
      expect(r.notes['ice']!.confidence, Confidence.high);
      expect(r.notes['rate']!.confidence, Confidence.high);
      expect(r.notes['supplier']!.confidence, Confidence.medium);
      expect(r.missing, isEmpty);
    });

    test('a total guessed from the largest amount is to be checked', () {
      final r = parseReceiptText([
        'EPICERIE DU COIN',
        'Le 10/11/2026',
        'Pain 3,00',
        'Lait 12,50',
      ], today: _today);
      expect(r.amountCents, 1250);
      expect(r.notes['amount']!.confidence, Confidence.low);
    });

    test('what could not be read is listed', () {
      final r = parseReceiptText([
        '12/11/2026 ticket n 45',
        'merci de votre visite',
      ], today: _today);
      expect(r.unreadable, isFalse);
      expect(r.missing, containsAll(['amount']));
    });
  });

  group('Classification agent', () {
    test('suppliers are compared without case, accents or spacing', () {
      expect(normalizeSupplier('  HÔTEL   Farah '), 'hotel farah');
      expect(normalizeSupplier('Café-Atlas'), 'cafe atlas');
    });

    test('the person\'s history wins, with the project of the last time', () {
      final history = [
        _past('Taxi Bleu', 'Repas', daysAgo: 9),
        _past('TAXI BLEU', 'Fournitures', project: 'Mission Rabat', daysAgo: 5),
        _past('taxi bleu', 'Fournitures', project: 'Client Atlas', daysAgo: 2),
      ];
      final c = classifyExpense(supplier: 'Taxi  Bleu', history: history);
      expect(c.category!.value, 'Fournitures');
      expect(c.category!.note.confidence, Confidence.high);
      expect(c.project!.value, 'Client Atlas');
    });

    test('the ICE recognises a supplier whose name was read differently', () {
      final c = classifyExpense(
        supplier: 'Libr. Nationale',
        ice: '002345678000012',
        history: [
          _past('Librairie Nationale', 'Fournitures', ice: '002345678000012'),
        ],
      );
      expect(c.category!.value, 'Fournitures');
    });

    test('without history, the kind of shop is recognised by its name', () {
      for (final (name, category) in [
        ('Petit Taxi Casa', 'Transport'),
        ('ONCF Al Boraq', 'Transport'),
        ('Station Afriquia Maarif', 'Transport'),
        ('Pâtisserie Bennis', 'Repas'),
        ('Riad Salam', 'Hébergement'),
        ('Librairie Papeterie Agdal', 'Fournitures'),
        ('مطعم الأندلس', 'Repas'),
      ]) {
        final c = classifyExpense(supplier: name, history: const []);
        expect(c.category?.value, category, reason: name);
        expect(c.category!.note.confidence, Confidence.medium);
      }
    });

    test('rejected or draft expenses teach nothing; unknown stays empty', () {
      final c = classifyExpense(
        supplier: 'Société XYZ',
        history: [
          _past('Société XYZ', 'Repas', status: ExpenseStatus.rejected),
          _past('Société XYZ', 'Repas', status: ExpenseStatus.draft),
        ],
      );
      expect(c.isEmpty, isTrue);
    });
  });
}
