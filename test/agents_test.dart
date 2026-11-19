import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/agents/agent_metrics.dart';
import 'package:rembo/core/agents/classification_agent.dart';
import 'package:rembo/core/agents/compliance_agent.dart';
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

  group('Compliance agent', () {
    Expense expense({
      String id = 'new',
      String supplier = 'Station Afriquia',
      int cents = 49875,
      int vat = 0,
      int? rate,
      String ice = '',
      String currency = 'MAD',
      int? paid,
      int daysAgo = 5,
      ExpenseStatus status = ExpenseStatus.draft,
    }) => Expense(
      id: id,
      employeeId: 'u1',
      employeeName: 'Omar',
      supplier: supplier,
      supplierIce: ice,
      date: DateTime(2026, 11, 20 - daysAgo),
      amountCents: cents,
      vatCents: vat,
      vatRate: rate,
      currency: currency,
      foreignAmountCents: paid,
      category: 'Transport',
      reason: 'Mission',
      status: status,
      createdAt: _today,
    );
    List<String> check(Expense e, [List<Expense> others = const []]) => [
      for (final f in controlExpense(
        e,
        policies: const [
          PolicyRule(
            category: 'Transport',
            limitCents: 50000,
            receiptRequired: false,
          ),
        ],
        others: others,
        today: _today,
      ))
        f.message,
    ];

    test('a coherent VAT and a valid ICE: nothing to report', () {
      expect(
        check(expense(vat: 6125, rate: 14, ice: '001234567000089')),
        isEmpty,
      );
    });

    test('VAT, ICE and currency are checked as on the server', () {
      expect(check(expense(cents: 40000, vat: 2000, rate: 20)), [
        'TVA incohérente avec le taux indiqué',
      ]);
      expect(check(expense(ice: '12345')), [
        'ICE du fournisseur invalide : 15 chiffres attendus',
      ]);
      expect(check(expense(currency: 'EUR', paid: 2000)), [
        'Dépense en devise : conversion en dirhams à vérifier',
      ]);
      expect(
        expense(currency: 'EUR').missingFields,
        contains('montant payé en devise'),
      );
    });

    test('the same supplier and amount a few days apart is a duplicate', () {
      final earlier = expense(
        id: 'old',
        supplier: 'STATION  afriquia',
        daysAgo: 7,
        status: ExpenseStatus.approved,
      );
      expect(check(expense(), [earlier]), [
        'Même fournisseur et même montant à quelques jours d’intervalle',
      ]);
      expect(check(expense(daysAgo: 1), [earlier]), isEmpty);
    });
  });

  group('Agent measures', () {
    Expense submitted({
      required Map<String, String> proposal,
      int amount = 25000,
      Duration took = const Duration(seconds: 90),
      String status = 'needs_review',
    }) {
      final start = DateTime(2026, 11, 20, 10);
      return Expense.fromJson({
        'id': 'e-${proposal.length}-$amount',
        'employee_id': 'u1',
        'employee_name': 'Omar',
        'supplier_name': 'Café Atlas',
        'expense_date': '2026-11-19',
        'amount_cents': amount,
        'category': 'Repas',
        'status': status,
        'created_at': start.toUtc().toIso8601String(),
        'capture_started_at': start.toUtc().toIso8601String(),
        'agent_proposal': {
          'engine': 'device',
          'fields': {
            for (final e in proposal.entries)
              e.key: {'value': e.value, 'agent': 'reading'},
          },
        },
        'status_events': [
          {
            'to_status': 'submitted',
            'actor_kind': 'human',
            'created_at': start.add(took).toUtc().toIso8601String(),
          },
        ],
      });
    }

    test('kept and corrected fields, as the SQL view counts them', () {
      final m = AgentMeasure.of(
        submitted(
          proposal: {
            'supplier': 'CAFÉ ATLAS',
            'amount': '24000',
            'category': 'Repas',
          },
        ),
      )!;
      expect(m.proposed.length, 3);
      expect(m.accepted, 2);
      expect(m.corrected, {'amount'});
      expect(m.declareTime, const Duration(seconds: 90));
    });

    test('a summary over the submitted expenses, drafts left out', () {
      final metrics = AgentMetrics.of([
        submitted(proposal: {'amount': '25000', 'date': '2026-11-19'}),
        submitted(
          proposal: {'amount': '24000'},
          took: const Duration(seconds: 150),
        ),
        submitted(proposal: {}, took: const Duration(seconds: 200)),
        submitted(proposal: {'amount': '1'}, status: 'draft'),
      ]);
      expect(metrics.assisted.length, 2);
      expect(metrics.proposed, 3);
      expect(metrics.accepted, 2);
      expect(metrics.untouched, 1);
      expect(metrics.byField.firstWhere((f) => f.field == 'amount').rate, .5);
      expect(
        metrics.medianDeclare(assisted: true),
        const Duration(seconds: 120),
      );
      expect(
        metrics.medianDeclare(assisted: false),
        const Duration(seconds: 200),
      );
    });
  });
}
