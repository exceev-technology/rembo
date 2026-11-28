import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/agents/compliance_agent.dart';
import 'package:rembo/core/agents/policy_reader.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';

final _today = DateTime(2026, 11, 28);

Expense _expense({int daysAgo = 5, String project = ''}) => Expense(
  id: 'new',
  employeeId: 'u1',
  employeeName: 'Omar',
  supplier: 'Imprimerie Anfa',
  date: _today.subtract(Duration(days: daysAgo)),
  amountCents: 5000,
  category: 'Fournitures',
  reason: 'Cartes',
  project: project,
  createdAt: _today,
);

List<String> _flags(Expense e, CompanyPolicy company) => [
  for (final f in controlExpense(
    e,
    policies: const [],
    others: const [],
    today: _today,
    company: company,
  ))
    f.message,
];

const _policy = '''
Politique de notes de frais de l'Atelier Anfa

Toute dépense doit être déclarée dans les 30 jours.
Le projet ou le client doit être indiqué sur chaque note.
Repas : 150 DH maximum par repas.
Hôtel : jusqu'à 1.200 DH la nuit.
Taxi sans justificatif : 80 DH.
L'alcool n'est pas remboursé.
''';

void main() {
  group('The company policy in the control', () {
    test('REMBO\'s defaults: 60 days, project optional', () {
      expect(_flags(_expense(daysAgo: 40), CompanyPolicy.defaults), isEmpty);
      expect(_flags(_expense(daysAgo: 61), CompanyPolicy.defaults), [
        'Dépense datée de plus de 60 jours',
      ]);
    });

    test('the company\'s deadline and project rule', () {
      const strict = CompanyPolicy(deadlineDays: 30, projectRequired: true);
      expect(_flags(_expense(daysAgo: 40, project: 'Anfa'), strict), [
        'Dépense datée de plus de 30 jours',
      ]);
      expect(_flags(_expense(), strict), ['Projet ou client manquant']);
      expect(_flags(_expense(project: 'Anfa'), strict), isEmpty);
    });
  });

  group('Policy reader without a server', () {
    test('finds the deadline, the project and the limits', () {
      final p = readPolicyText(_policy, documentName: 'politique.txt');
      expect(p.deadlineDays, 30);
      expect(p.projectRequired, isTrue);
      expect(
        [
          for (final r in p.rules)
            '${r.category} ${r.limitCents} ${r.receiptRequired}',
        ],
        ['Repas 15000 true', 'Hébergement 120000 true', 'Transport 8000 false'],
      );
      expect(p.notApplied, ['L\'alcool n\'est pas remboursé']);
    });

    test('a text without rules gives nothing', () {
      final p = readPolicyText(
        'Bienvenue dans notre entreprise.',
        documentName: 'x.txt',
      );
      expect(p.isEmpty, isTrue);
    });
  });

  group('Local backend', () {
    test(
      'a manager applies a read policy, then goes back to the defaults',
      () async {
        final backend = DemoBackend(latency: Duration.zero);
        await backend.signIn(DemoBackend.salma.email, 'x');
        final proposal = await backend.readPolicy(
          const PolicySource.text('politique.txt', _policy),
        );
        await backend.applyPolicy(proposal);

        final policy = await backend.fetchCompanyPolicy();
        expect(policy.deadlineDays, 30);
        expect(policy.projectRequired, isTrue);
        expect(policy.document?.name, 'politique.txt');
        expect(policy.document?.appliedBy, DemoBackend.salma.fullName);
        final repas = (await backend.fetchPolicies()).firstWhere(
          (r) => r.category == 'Repas',
        );
        expect(repas.limitCents, 15000);

        await backend.resetPolicy();
        expect((await backend.fetchCompanyPolicy()).document, isNull);
        expect(
          (await backend.fetchPolicies())
              .firstWhere((r) => r.category == 'Repas')
              .limitCents,
          20000,
        );
      },
    );

    test('a collaborator cannot change the rules', () async {
      final backend = DemoBackend(latency: Duration.zero);
      await backend.signIn(DemoBackend.marius.email, 'x');
      expect(
        () => backend.saveCompanyRules(deadlineDays: 10, projectRequired: true),
        throwsA(isA<RemboException>()),
      );
    });

    test('without a server, only text is read', () async {
      final backend = DemoBackend(latency: Duration.zero);
      await backend.signIn(DemoBackend.salma.email, 'x');
      expect(
        () => backend.readPolicy(const PolicySource.pages('p.pdf', [])),
        throwsA(isA<RemboException>()),
      );
    });
  });
}
