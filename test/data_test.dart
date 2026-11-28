import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/data/csv_export.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/format/formatters.dart';
import 'package:rembo/core/format/parsers.dart';
import 'package:rembo/core/format/phone_countries.dart';

final _now = DateTime(2026, 11, 10, 15);

DemoBackend _backend({
  bool autoApprove = false,
  bool managersDeclare = false,
}) => DemoBackend(
  clock: () => _now,
  latency: Duration.zero,
  autoApprove: autoApprove,
  managersDeclare: managersDeclare,
);

Expense _draft({
  int cents = 15000,
  String category = 'Repas',
  DateTime? date,
}) => Expense(
  id: '',
  employeeId: '',
  employeeName: '',
  supplier: 'Le Zellige',
  date: date ?? DateTime(2026, 11, 8),
  amountCents: cents,
  category: category,
  reason: 'Déjeuner client',
  createdAt: _now,
);

Future<void> _expectRefused(Future<Object?> call, String part) async {
  try {
    await call;
    fail('Expected a RemboException containing « $part »');
  } on RemboException catch (e) {
    expect(e.message, contains(part));
  }
}

void main() {
  test('lists show one short date', () {
    final today = DateTime(2026, 11, 12);
    expect(formatDayShort(DateTime(2026, 11, 12), today: today), 'Aujourd’hui');
    expect(formatDayShort(DateTime(2026, 11, 11), today: today), 'Hier');
    expect(formatDayShort(DateTime(2026, 11, 3), today: today), '3 nov.');
    expect(
      formatDayShort(DateTime(2025, 12, 30), today: today),
      '30 déc. 2025',
    );
  });

  group('Parsers', () {
    test('amounts are read as centimes without floating point', () {
      expect(parseAmount('240'), 24000);
      expect(parseAmount('240,5'), 24050);
      expect(parseAmount('1 234,56'), 123456);
      expect(parseAmount('0,07'), 7);
      expect(parseAmount('-24'), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('12,345'), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('dates must exist and not be in the future', () {
      expect(parseDay('09/11/2026', today: _now), DateTime(2026, 11, 9));
      expect(parseDay('31/02/2026', today: _now), isNull);
      expect(parseDay('11/11/2026', today: _now), isNull);
      expect(parseDay('01/01/1999', today: _now), isNull);
      expect(parseDay('9/11/2026', today: _now), isNull);
    });

    test('phone numbers are normalised to the international form', () {
      expect(parsePhone('06 12 34 56 78'), '+212612345678');
      expect(parsePhone('+212 612-345-678'), '+212612345678');
      expect(parsePhone('00212612345678'), '+212612345678');
      expect(parsePhone('12'), isNull);
      expect(parsePhone('abc'), isNull);
    });

    test('a number is read with the rules of the country chosen', () {
      PhoneCountry of(String iso) =>
          phoneCountries.firstWhere((c) => c.iso == iso);
      expect(parsePhone('612345678'), '+212612345678');
      expect(parsePhone('06 12 34 56 78', country: of('FR')), '+33612345678');
      expect(parsePhone('77 123 45 67', country: of('SN')), '+221771234567');
      // Côte d'Ivoire keeps its leading zero abroad.
      expect(parsePhone('07 12 34 56 78', country: of('CI')), '+2250712345678');
      expect(parsePhone('202 555 0123', country: of('US')), '+12025550123');
      // Too short for the country, or not a mobile prefix in Morocco.
      expect(parsePhone('06 12 34', country: of('FR')), isNull);
      expect(parsePhone('01 12 34 56 78'), isNull);
      // A full number wins over the country chosen, listed or not.
      expect(parsePhone('+33 6 12 34 56 78'), '+33612345678');
      expect(parsePhone('+81 90 1234 5678'), '+819012345678');
      expect(parsePhone('+212 12'), isNull);
    });

    test('a linked number is shown the way its country writes it', () {
      expect(countryOf('+212612345678')!.iso, 'MA');
      expect(countryOf('+12025550123')!.iso, 'US');
      expect(countryOf('+819012345678'), isNull);
      expect(morocco.toNational('+212612345678'), '0612345678');
      for (final c in phoneCountries) {
        final number = parsePhone(c.example, country: c);
        expect(number, isNotNull, reason: 'example of ${c.name}');
        expect(countryOf(number!)!.iso, c.iso, reason: c.name);
        expect(parsePhone(c.toNational(number), country: c), number);
      }
    });

    test('amounts are displayed the French way', () {
      expect(formatMad(123456), '1\u00A0234,56\u00A0MAD');
      expect(amountInput(24000), '240,00');
    });
  });

  group('Automatic control', () {
    test('by default a compliant expense waits for a manager, who confirms '
        'the compliant ones in one gesture', () async {
      final b = _backend();
      await b.signIn(DemoBackend.marius.email, 'x');
      final saved = await b.saveDraft(
        _draft(),
        receiptBytes: Uint8List(4),
        receiptName: 'r.jpg',
      );
      final sent = await b.submit(saved.id);
      expect(sent.status, ExpenseStatus.needsReview);
      expect(sent.flags, isEmpty);
      expect(sent.compliantToConfirm, isTrue);
      expect(sent.events.last.byAgent, isTrue);
      expect(sent.events.last.reason, 'Conforme aux règles');
      await _expectRefused(b.approveCompliant([sent.id]), 'responsables');

      await b.signIn(DemoBackend.salma.email, 'x');
      expect(await b.fetchAutoApprove(), isFalse);
      final flagged = (await b.fetchExpenses()).firstWhere(
        (e) => e.status == ExpenseStatus.needsReview && e.flags.isNotEmpty,
      );
      expect(await b.approveCompliant([sent.id, flagged.id]), 1);
      final mine = (await b.fetchExpenses()).firstWhere((e) => e.id == sent.id);
      expect(mine.status, ExpenseStatus.approved);
      expect(mine.approvedByAgent, isFalse);
      expect(mine.lastDecision!.actorName, DemoBackend.salma.fullName);
      expect(
        (await b.fetchExpenses()).firstWhere((e) => e.id == flagged.id).status,
        ExpenseStatus.needsReview,
      );
      // Confirming again changes nothing.
      expect(await b.approveCompliant([sent.id]), 0);

      await b.setAutoApprove(true);
      await b.signIn(DemoBackend.marius.email, 'x');
      final next = await b.saveDraft(
        _draft(cents: 9000, date: DateTime(2026, 11, 7)),
        receiptBytes: Uint8List(4),
        receiptName: 'r.jpg',
      );
      expect((await b.submit(next.id)).approvedByAgent, isTrue);
    });

    test(
      'a compliant expense with a receipt is approved by the agent',
      () async {
        final b = _backend(autoApprove: true);
        await b.signIn(DemoBackend.marius.email, 'x');
        final saved = await b.saveDraft(
          _draft(),
          receiptBytes: Uint8List(4),
          receiptName: 'r.jpg',
        );
        expect(saved.status, ExpenseStatus.draft);
        final result = await b.submit(saved.id);
        expect(result.status, ExpenseStatus.approved);
        expect(result.approvedByAgent, isTrue);
        expect(result.flags, isEmpty);
      },
    );

    test(
      'over the limit, without receipt, other category: needs review',
      () async {
        final b = _backend();
        await b.signIn(DemoBackend.marius.email, 'x');
        final over = await b.submit(
          (await b.saveDraft(_draft(cents: 26000))).id,
        );
        expect(over.status, ExpenseStatus.needsReview);
        expect(
          over.flags.map((f) => f.message),
          containsAll([
            'Plafond Repas dépassé de ${formatMad(6000)}',
            'Justificatif manquant',
          ]),
        );
        final other = await b.submit(
          (await b.saveDraft(_draft(category: 'Autre', cents: 1000))).id,
        );
        expect(other.flags.single.kind, FlagKind.ambiguity);
      },
    );

    test('same day and amount as a declared expense: duplicate', () async {
      final b = _backend();
      await b.signIn(DemoBackend.marius.email, 'x');
      // EXP-1041: Taxi Bleu, 2 days ago, 85,00, already approved.
      final twin = await b.saveDraft(
        _draft(cents: 8500, category: 'Transport', date: DateTime(2026, 11, 8)),
        receiptBytes: Uint8List(1),
      );
      final result = await b.submit(twin.id);
      expect(result.flags.single.kind, FlagKind.duplicate);
    });

    test(
      'an incomplete draft is refused, a second submit changes nothing',
      () async {
        final b = _backend();
        await b.signIn(DemoBackend.marius.email, 'x');
        final empty = await b.saveDraft(
          Expense(id: '', employeeId: '', employeeName: '', createdAt: _now),
        );
        await _expectRefused(b.submit(empty.id), 'Complétez');
        final ok = await b.saveDraft(_draft(), receiptBytes: Uint8List(1));
        final first = await b.submit(ok.id);
        final second = await b.submit(ok.id);
        expect(second.events.length, first.events.length);
      },
    );

    test(
      'saving twice with the same creation id creates one expense',
      () async {
        final b = _backend();
        await b.signIn(DemoBackend.marius.email, 'x');
        final before = (await b.fetchExpenses()).length;
        final a = await b.saveDraft(_draft(), createId: 'abc');
        final again = await b.saveDraft(_draft(cents: 9900), createId: 'abc');
        expect(again.id, a.id);
        expect(again.amountCents, 9900);
        expect((await b.fetchExpenses()).length, before + 1);
      },
    );
  });

  group('Rights', () {
    test('each role sees only what it may', () async {
      final b = _backend();
      await b.signIn(DemoBackend.marius.email, 'x');
      expect(
        (await b.fetchExpenses()).every((e) => e.employeeId == 'u-marius'),
        isTrue,
      );
      await b.signIn(DemoBackend.salma.email, 'x');
      final manager = await b.fetchExpenses();
      expect(manager.any((e) => e.employeeId == 'u-ahmed'), isTrue);
      expect(
        manager
            .where((e) => e.employeeId != 'u-salma')
            .any((e) => e.status == ExpenseStatus.draft),
        isFalse,
      );
      await b.signIn(DemoBackend.nadia.email, 'x');
      expect(
        (await b.fetchExpenses()).every(
          (e) =>
              e.status == ExpenseStatus.approved ||
              e.status == ExpenseStatus.exported,
        ),
        isTrue,
      );
    });

    test('only a manager decides, never on their own expense', () async {
      final b = _backend(managersDeclare: true);
      await b.signIn(DemoBackend.marius.email, 'x');
      await _expectRefused(b.decide('EXP-1036', approve: true), 'responsables');

      await b.signIn(DemoBackend.salma.email, 'x');
      final own = await b.submit((await b.saveDraft(_draft(cents: 99000))).id);
      expect(own.status, ExpenseStatus.needsReview);
      await _expectRefused(b.decide(own.id, approve: true), 'propre dépense');
      await _expectRefused(b.decide('EXP-1037', approve: false), 'motif');

      final rejected = await b.decide(
        'EXP-1037',
        approve: false,
        reason: 'Hors plafond.',
      );
      expect(rejected.status, ExpenseStatus.rejected);
      expect(rejected.lastDecision!.reason, 'Hors plafond.');
      await _expectRefused(b.decide('EXP-1037', approve: true), 'déjà');
    });

    test('rules and invitations are reserved to managers', () async {
      final b = _backend();
      await b.signIn(DemoBackend.marius.email, 'x');
      await _expectRefused(
        b.savePolicy(const PolicyRule(category: 'Repas', limitCents: 1)),
        'responsables',
      );
      await _expectRefused(
        b.invite('a@b.ma', UserRole.manager),
        'responsables',
      );
    });

    test('an invited address joins the company only when it accepts', () async {
      final b = _backend();
      await b.signIn(DemoBackend.salma.email, 'x');
      await b.invite('Karim@Exemple.ma', UserRole.accountant);
      expect((await b.fetchMembers()).last.pending, isTrue);
      final karim = await b.signUp(
        email: 'karim@exemple.ma',
        password: 'Secret1!',
        fullName: 'Karim Alaoui',
      );
      // Signing up joins nothing: the invitation waits for an answer.
      expect(karim!.companyId, isNull);
      final waiting = await b.pendingInvitation();
      expect(waiting!.companyName, DemoBackend.companyName);
      expect(waiting.role, UserRole.accountant);
      final joined = await b.acceptInvitation();
      expect(joined.role, UserRole.accountant);
      expect(joined.companyName, DemoBackend.companyName);
      expect(await b.pendingInvitation(), isNull);
      final stranger = await b.signUp(
        email: 'x@y.ma',
        password: 'Secret1!',
        fullName: 'X Y',
      );
      expect(stranger!.companyId, isNull);
      expect(await b.pendingInvitation(), isNull);
      await _expectRefused(b.acceptInvitation(), 'plus valable');
    });
  });

  group('Export', () {
    test('exports approved expenses once, with a matching total', () async {
      final b = _backend();
      await b.signIn(DemoBackend.nadia.email, 'x');
      final approved = (await b.fetchExpenses())
          .where((e) => e.status == ExpenseStatus.approved)
          .toList();
      final ids = [for (final e in approved) e.id];
      final batch = await b.createExport(ids, requestId: 'r1');
      expect(batch.count, approved.length);
      expect(
        batch.totalCents,
        approved.fold<int>(0, (s, e) => s + e.amountCents),
      );
      final lines = batch.csv!.split('\r\n');
      expect(lines.first, CsvExport.columns.join(';'));
      expect(lines.length, approved.length + 1);
      expect(lines[1], contains(';85.00;'));

      // Same request: same batch. New request on the same ids: refused.
      expect((await b.createExport(ids, requestId: 'r1')).id, batch.id);
      await _expectRefused(b.createExport(ids, requestId: 'r2'), 'validées');
      expect(
        (await b.fetchExpenses()).every(
          (e) => e.status == ExpenseStatus.exported,
        ),
        isTrue,
      );
    });

    test('CSV cells are quoted and formulas neutralised', () {
      final csv = CsvExport.build([
        Expense(
          id: 'e1',
          employeeId: 'u',
          employeeName: 'A; B',
          supplier: '=SUM(A1)',
          date: DateTime(2026, 11, 9),
          amountCents: 110000,
          vatCents: 10000,
          category: 'Repas',
          reason: 'Dîner "client"',
          createdAt: _now,
        ),
      ], batchId: 'b1');
      final row = csv.split('\r\n')[1];
      expect(row, contains('"A; B"'));
      expect(row, contains("'=SUM(A1)"));
      expect(row, contains(';1100.00;;100.00;1000.00;MAD;;'));
      expect(row, contains('"Dîner ""client"""'));
    });
  });

  test('a WhatsApp draft is only submitted by its author', () async {
    final b = _backend(autoApprove: true);
    await b.signIn(DemoBackend.marius.email, 'x');
    final draft = (await b.fetchExpenses()).firstWhere((e) => e.fromWhatsApp);
    expect(draft.status, ExpenseStatus.draft);
    expect(draft.transcript, contains('45 dirhams'));
    await b.signIn(DemoBackend.salma.email, 'x');
    // Not visible to the manager while it is a draft, and not hers to send.
    expect((await b.fetchExpenses()).any((e) => e.id == draft.id), isFalse);
    await _expectRefused(b.submit(draft.id), 'introuvable');
    await b.signIn(DemoBackend.marius.email, 'x');
    final sent = await b.submit(draft.id);
    expect(sent.status, ExpenseStatus.approved);
    expect(sent.fromWhatsApp, isTrue);
  });

  test('a lost connection is reported as retryable', () async {
    final b = _backend();
    await b.signIn(DemoBackend.marius.email, 'x');
    b.offline = true;
    try {
      await b.fetchExpenses();
      fail('should throw');
    } on RemboException catch (e) {
      expect(e.network, isTrue);
    }
  });
}
