import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/local_store.dart';
import 'package:rembo/core/data/local_store_io.dart';
import 'package:rembo/core/data/models.dart';

final _today = DateTime(2026, 11, 11, 10);
final _photo = Uint8List.fromList([1, 2, 3, 4]);

Future<LocalBackend> _open(LocalStore store) =>
    LocalBackend.open(store, clock: () => _today);

Expense _draft({
  String supplier = 'Café Atlas',
  int cents = 12000,
  String category = 'Repas',
  DateTime? date,
}) => Expense(
  id: '',
  employeeId: '',
  employeeName: '',
  supplier: supplier,
  date: date ?? DateTime(2026, 11, 10),
  amountCents: cents,
  category: category,
  reason: 'Déjeuner client',
  createdAt: _today,
);

/// A company with a manager, an employee and an accountant.
/// [autoApprove]: the control approves compliant expenses itself.
Future<LocalBackend> _company(
  LocalStore store, {
  bool autoApprove = false,
}) async {
  final b = await _open(store);
  await b.signUp(
    email: 'Sara@Exemple.ma',
    password: 'Secret#1',
    fullName: 'Sara',
  );
  await b.createCompany(name: 'Atelier Sara');
  if (autoApprove) await b.setAutoApprove(true);
  await b.invite('omar@exemple.ma', UserRole.employee);
  await b.invite('lina@exemple.ma', UserRole.accountant);
  await b.signOut();
  await b.signUp(
    email: 'omar@exemple.ma',
    password: 'Secret#2',
    fullName: 'Omar',
  );
  await b.acceptInvitation();
  await b.signOut();
  await b.signUp(
    email: 'lina@exemple.ma',
    password: 'Secret#3',
    fullName: 'Lina',
  );
  await b.acceptInvitation();
  await b.signOut();
  return b;
}

Future<void> _throws(Future<Object?> Function() action, String part) async {
  try {
    await action();
  } on RemboException catch (e) {
    expect(e.message, contains(part));
    return;
  }
  fail('Expected a RemboException containing « $part »');
}

void main() {
  test('starts empty: no fictional account or expense', () async {
    final b = await _open(MemoryStore());
    expect(b.isDemo, isFalse);
    expect(b.isLocal, isTrue);
    expect(await b.restoreSession(), isNull);
    await _throws(
      () => b.signIn('marius@atlas-conseil.ma', 'demo'),
      'incorrect',
    );
  });

  test(
    'accounts: password checked, e-mail unique and case-insensitive',
    () async {
      final b = await _open(MemoryStore());
      final sara = await b.signUp(
        email: ' Sara@Exemple.ma ',
        password: 'Secret#1',
        fullName: 'Sara',
      );
      expect(sara!.email, 'sara@exemple.ma');
      expect(sara.companyId, isNull);
      await b.signOut();
      await _throws(() => b.signIn('sara@exemple.ma', 'wrong'), 'incorrect');
      await _throws(() => b.signIn('sara@exemple.ma', ''), 'incorrect');
      await _throws(
        () => b.signUp(email: 'SARA@exemple.ma', password: 'x', fullName: 'S'),
        'existe déjà',
      );
      expect((await b.signIn('SARA@exemple.ma', 'Secret#1')).fullName, 'Sara');
      await _throws(() => b.sendPasswordReset('sara@exemple.ma'), 'téléphone');
    },
  );

  test('the password is never stored in clear', () async {
    final store = MemoryStore();
    final b = await _open(store);
    await b.signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'A');
    expect(store.document, isNot(contains('Secret#1')));
  });

  test('no company yet: no expense can be created', () async {
    final b = await _open(MemoryStore());
    await b.signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'A');
    await _throws(() => b.saveDraft(_draft()), 'entreprise');
    expect(await b.fetchExpenses(), isEmpty);
    expect(await b.fetchPolicies(), isEmpty);
  });

  test(
    'creating a company makes its founder manager, with default rules',
    () async {
      final b = await _open(MemoryStore());
      await b.signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'A');
      await _throws(() => b.createCompany(name: '  '), 'obligatoire');
      final me = await b.createCompany(name: ' Atelier A ');
      expect(me.role, UserRole.manager);
      expect(me.companyName, 'Atelier A');
      expect(
        (await b.fetchPolicies()).map((p) => p.category),
        contains('Repas'),
      );
      await _throws(() => b.createCompany(name: 'Autre'), 'déjà');
    },
  );

  test('an invited person joins the company with the given role', () async {
    final b = await _company(MemoryStore());
    final lina = await b.signIn('lina@exemple.ma', 'Secret#3');
    expect(lina.role, UserRole.accountant);
    expect(lina.companyName, 'Atelier Sara');
    final members = await b.fetchMembers();
    expect(members, hasLength(3));
    expect(members.any((m) => m.pending), isFalse);
    await _throws(
      () => b.invite('x@exemple.ma', UserRole.employee),
      'responsables',
    );
  });

  test('full cycle: compliant expense approved alone, then exported', () async {
    final b = await _company(MemoryStore(), autoApprove: true);
    await b.signIn('omar@exemple.ma', 'Secret#2');
    final draft = await b.saveDraft(_draft(), receiptBytes: _photo);
    expect(draft.status, ExpenseStatus.draft);
    final sent = await b.submit(draft.id);
    expect(sent.status, ExpenseStatus.approved);
    expect(sent.approvedByAgent, isTrue);
    await _throws(() => b.saveDraft(sent), 'ne peut plus');
    await b.signOut();

    await b.signIn('lina@exemple.ma', 'Secret#3');
    final toExport = await b.fetchExpenses();
    expect(toExport.single.id, draft.id);
    final batch = await b.createExport([draft.id], requestId: 'r1');
    expect(batch.count, 1);
    expect(batch.totalCents, 12000);
    expect(batch.csv, contains('Café Atlas'));
    expect(batch.csv, contains('120.00'));
    // Same request sent twice: one batch only.
    expect((await b.createExport([draft.id], requestId: 'r1')).id, batch.id);
    await _throws(
      () => b.createExport([draft.id], requestId: 'r2'),
      'non exportées',
    );
    expect((await b.fetchExpenses()).single.status, ExpenseStatus.exported);
    expect(await b.fetchExports(), hasLength(1));
  });

  test(
    'an expense over the limit waits for the manager, who decides',
    () async {
      final b = await _company(MemoryStore(), autoApprove: true);
      await b.signIn('omar@exemple.ma', 'Secret#2');
      final a = await b.saveDraft(_draft(cents: 35000), receiptBytes: _photo);
      final c = await b.saveDraft(_draft(supplier: 'Snack', cents: 5000));
      expect((await b.submit(a.id)).status, ExpenseStatus.needsReview);
      final noReceipt = await b.submit(c.id);
      expect(noReceipt.status, ExpenseStatus.needsReview);
      expect(noReceipt.flags.single.message, 'Justificatif manquant');
      await _throws(() => b.decide(a.id, approve: true), 'responsables');
      await b.signOut();

      await b.signIn('lina@exemple.ma', 'Secret#3');
      expect(await b.fetchExpenses(), isEmpty); // nothing validated yet
      await b.signOut();

      await b.signIn('sara@exemple.ma', 'Secret#1');
      expect(await b.fetchExpenses(), hasLength(2));
      await _throws(() => b.decide(c.id, approve: false), 'motif');
      final rejected = await b.decide(c.id, approve: false, reason: 'Ticket ?');
      expect(rejected.status, ExpenseStatus.rejected);
      expect(
        (await b.decide(a.id, approve: true)).status,
        ExpenseStatus.approved,
      );
      await _throws(() => b.decide(a.id, approve: true), 'déjà été traitée');
      await b.signOut();

      // The employee corrects the rejected expense and sends it again.
      await b.signIn('omar@exemple.ma', 'Secret#2');
      final mine = await b.fetchExpenses();
      final back = mine.firstWhere((e) => e.id == c.id);
      expect(back.lastDecision!.reason, 'Ticket ?');
      await b.saveDraft(back, receiptBytes: _photo);
      expect((await b.submit(c.id)).status, ExpenseStatus.approved);
    },
  );

  test('a manager decides on their own expense', () async {
    final b = await _company(MemoryStore());
    await b.signIn('sara@exemple.ma', 'Secret#1');
    final mine = await b.saveDraft(_draft(cents: 90000), receiptBytes: _photo);
    expect((await b.submit(mine.id)).status, ExpenseStatus.needsReview);
    final decided = await b.decide(mine.id, approve: true);
    expect(decided.status, ExpenseStatus.approved);
  });

  test('the rules changed by the manager drive the control', () async {
    final b = await _company(MemoryStore(), autoApprove: true);
    await b.signIn('sara@exemple.ma', 'Secret#1');
    await b.savePolicy(const PolicyRule(category: 'Repas', limitCents: 50000));
    await _throws(
      () => b.savePolicy(const PolicyRule(category: 'Repas', limitCents: 0)),
      'supérieur',
    );
    await b.signOut();
    await b.signIn('omar@exemple.ma', 'Secret#2');
    final d = await b.saveDraft(_draft(cents: 35000), receiptBytes: _photo);
    expect((await b.submit(d.id)).status, ExpenseStatus.approved);
    await _throws(
      () => b.savePolicy(const PolicyRule(category: 'Repas', limitCents: 1)),
      'responsables',
    );
  });

  test('two companies on one phone never see each other', () async {
    final b = await _company(MemoryStore());
    await b.signIn('omar@exemple.ma', 'Secret#2');
    final d = await b.saveDraft(_draft(cents: 35000), receiptBytes: _photo);
    await b.submit(d.id);
    await b.signOut();

    await b.signUp(email: 'z@autre.ma', password: 'Secret#9', fullName: 'Zed');
    await b.createCompany(name: 'Autre SARL');
    expect(await b.fetchExpenses(), isEmpty);
    expect(await b.fetchMembers(), hasLength(1));
    expect(await b.fetchExports(), isEmpty);
    await _throws(() => b.decide(d.id, approve: true), 'introuvable');
    await _throws(() => b.submit(d.id), 'introuvable');
    await _throws(() => b.loadReceipt(d), 'introuvable');
    await _throws(
      () => b.invite('omar@exemple.ma', UserRole.employee),
      'autre entreprise',
    );
    // Their rules are their own.
    await b.savePolicy(const PolicyRule(category: 'Repas', limitCents: 100));
    await b.signOut();
    await b.signIn('sara@exemple.ma', 'Secret#1');
    final repas = (await b.fetchPolicies()).firstWhere(
      (p) => p.category == 'Repas',
    );
    expect(repas.limitCents, 20000);
  });

  test('everything survives closing the app', () async {
    final store = MemoryStore();
    var b = await _company(store);
    await b.signIn('omar@exemple.ma', 'Secret#2');
    final a = await b.saveDraft(_draft(cents: 35000), receiptBytes: _photo);
    await b.submit(a.id);
    final kept = await b.saveDraft(_draft(supplier: 'Brouillon'));

    b = await _open(store); // the app is opened again
    final me = await b.restoreSession();
    expect(me!.email, 'omar@exemple.ma');
    final mine = await b.fetchExpenses();
    expect(mine, hasLength(2));
    final again = mine.firstWhere((e) => e.id == a.id);
    expect(again.status, ExpenseStatus.needsReview);
    expect(again.flags.single.kind, FlagKind.policy);
    expect(again.events.map((e) => e.status), [
      ExpenseStatus.submitted,
      ExpenseStatus.needsReview,
    ]);
    expect(again.events.last.byAgent, isTrue);
    expect(again.date, DateTime(2026, 11, 10));
    expect(await b.loadReceipt(again), _photo);
    // New ids do not collide with the saved ones.
    final next = await b.saveDraft(_draft(supplier: 'Suivant'));
    expect({a.id, kept.id, next.id}, hasLength(3));
    await b.deleteDraft(kept.id);
    await b.signOut();

    b = await _open(store);
    expect(await b.restoreSession(), isNull); // signed out stays signed out
    await b.signIn('sara@exemple.ma', 'Secret#1');
    expect((await b.fetchExpenses()).single.id, a.id);
    expect(await b.fetchMembers(), hasLength(3));
  });

  test(
    'files on disk: document and receipts are written and read back',
    () async {
      final dir = await Directory.systemTemp.createTemp('rembo-test');
      addTearDown(() => dir.delete(recursive: true));
      var b = await _open(FileStore(dir));
      await b.signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'A');
      await b.createCompany(name: 'Atelier A');
      final d = await b.saveDraft(_draft(), receiptBytes: _photo);
      expect(File('${dir.path}/rembo.json').existsSync(), isTrue);
      expect(File('${dir.path}/rembo.json.tmp').existsSync(), isFalse);

      b = await _open(FileStore(dir));
      final again = (await b.fetchExpenses()).single;
      expect(again.id, d.id);
      expect(await b.loadReceipt(again), _photo);
      await b.deleteDraft(d.id);
      expect(Directory('${dir.path}/receipts').listSync(), isEmpty);
    },
  );

  test('an unreadable document is reported, not silently replaced', () async {
    final store = MemoryStore()..document = '{not json';
    await _throws(() => _open(store), 'illisibles');
    expect(store.document, '{not json');
  });

  testWidgets('the app in on-device mode: sign up, company, first screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final state = AppState(await _open(store));
    await state.restore();
    await tester.pumpWidget(RemboApp(state: state, initialRoute: '/login'));
    await tester.pumpAndSettle();
    // No demo shortcuts and no demo banner with real data.
    expect(find.byKey(const ValueKey('demo-employee')), findsNothing);

    final done = state
        .signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'Amal Rami')
        .then((_) => state.createCompany(name: 'Atelier A'));
    await tester.pumpAndSettle();
    await done;
    await tester.pumpAndSettle();
    expect(state.user!.role, UserRole.manager);
    expect(find.textContaining('Démonstration'), findsNothing);
    expect(find.textContaining('démonstration'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
