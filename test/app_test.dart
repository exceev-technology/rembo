import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/features/expenses/receipt_picker.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/format/formatters.dart';
import 'package:rembo/features/auth/login_screen.dart';

late DemoBackend backend;
late AppState state;

/// Tall screen: every part of a page is laid out and can be tapped.
Future<void> _start(
  WidgetTester tester, {
  String route = AppRoutes.login,
  Size size = const Size(420, 2600),
  double textScale = 1,
  ReceiptPicker receiptPicker = pickWithDevice,
  bool autoApprove = false,
  bool managersDeclare = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  // The welcome page floats for ever: tests ask for reduced motion.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  backend = DemoBackend(
    latency: Duration.zero,
    autoApprove: autoApprove,
    managersDeclare: managersDeclare,
  );
  state = AppState(backend);
  await tester.pumpWidget(
    RemboApp(state: state, initialRoute: route, receiptPicker: receiptPicker),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _signInAs(WidgetTester tester, UserRole role) async {
  // After signing out the app is back on the welcome page.
  if (find.byKey(const ValueKey('welcome-login')).evaluate().isNotEmpty) {
    await _tap(tester, 'welcome-login');
  }
  await _tap(tester, 'demo-${role.name}');
}

/// Without the login screen, whose demo buttons may be scrolled away.
Future<void> _signInDirectly(WidgetTester tester, UserRole role) async {
  final email = switch (role) {
    UserRole.employee => DemoBackend.marius.email,
    UserRole.manager => DemoBackend.salma.email,
    UserRole.accountant => DemoBackend.nadia.email,
  };
  final done = state.signIn(email, 'x');
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, 'tab-profile');
  await _tap(tester, 'profile-signout');
}

/// Fills the manual form and goes to the summary.
Future<void> _declare(
  WidgetTester tester, {
  required String amount,
  String category = 'Transport',
}) async {
  await _tap(tester, 'home-add');
  await _tap(tester, 'capture-manual');
  await _type(tester, 'form-supplier', 'Taxi Vert');
  await _type(tester, 'form-amount', amount);
  await _tap(tester, 'form-category');
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
  await _type(tester, 'form-reason', 'Rendez-vous client');
  await _tap(tester, 'form-continue');
}

void main() {
  testWidgets('Login checks its fields and reports wrong credentials', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, 'login-submit');
    expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);

    await _type(tester, 'login-email', 'inconnu@exemple.ma');
    await _type(tester, 'login-password', 'secret');
    await _tap(tester, 'login-submit');
    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);

    await _type(tester, 'login-email', DemoBackend.marius.email);
    await _tap(tester, 'login-submit');
    expect(find.text('Bonjour Marius'), findsOneWidget);
  });

  testWidgets('Password reset never claims an e-mail was sent in demo', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, 'login-forgot');
    await _type(tester, 'reset-email', 'pas-un-email');
    await _tap(tester, 'reset-submit');
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    await _type(tester, 'reset-email', 'marius@atlas-conseil.ma');
    await _tap(tester, 'reset-submit');
    expect(find.text('Démonstration : aucun e-mail envoyé'), findsOneWidget);
  });

  testWidgets('A new account without invitation creates its company', (
    tester,
  ) async {
    await _start(tester);
    await _tap(tester, 'login-signup');
    await _type(tester, 'signup-email', 'lina@exemple.ma');
    await _type(tester, 'signup-first', 'Lina');
    await _type(tester, 'signup-last', 'Amrani');
    await _type(tester, 'signup-password', 'court');
    await _tap(tester, 'signup-submit');
    expect(
      find.text('Le mot de passe ne respecte pas les règles.'),
      findsOneWidget,
    );
    await _type(tester, 'signup-password', 'Secret12!');
    await _tap(tester, 'signup-submit');
    expect(find.text('Votre entreprise'), findsOneWidget);

    await _type(tester, 'company-ice', '123');
    await _tap(tester, 'company-submit');
    expect(find.text('Saisissez le nom de l’entreprise.'), findsOneWidget);
    expect(find.text('L’ICE compte 15 chiffres.'), findsOneWidget);
    await _type(tester, 'company-name', 'Amrani Études');
    await _type(tester, 'company-ice', '');
    await _tap(tester, 'company-submit');
    // The first manager only decides: nothing waits yet, the team is next.
    expect(state.role, UserRole.manager);
    expect(
      find.byKey(const ValueKey('home-nothing-to-decide')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-invite-team')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-add')), findsNothing);
  });

  testWidgets('Collaborator: a compliant expense is validated automatically', (
    tester,
  ) async {
    await _start(tester, autoApprove: true);
    await _signInAs(tester, UserRole.employee);

    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-manual');
    await _type(tester, 'form-amount', '-24');
    await _tap(tester, 'form-continue');
    expect(find.text('Renseignez le fournisseur.'), findsOneWidget);
    expect(
      find.text('Saisissez un montant positif, ex. 240,00.'),
      findsOneWidget,
    );
    expect(find.text('Choisissez une catégorie.'), findsOneWidget);
    await _tap(tester, 'page-back');
    await _tap(tester, 'page-back');

    // Fournitures needs no receipt: nothing to flag.
    await _declare(tester, amount: '45,50', category: 'Fournitures');
    expect(find.text('Tout est correct ?'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-amount'))).data,
      contains('45,50'),
    );
    await _tap(tester, 'summary-submit');
    expect(find.text('Dépense validée'), findsOneWidget);
    expect(find.text('Validée par l’agent'), findsWidgets);

    await _tap(tester, 'result-home');
    final created = state.mine.first;
    expect(created.supplier, 'Taxi Vert');
    expect(created.amountCents, 4550);
    expect(created.status, ExpenseStatus.approved);
    expect(find.byKey(ValueKey('home-expense-${created.id}')), findsOneWidget);
  });

  testWidgets(
    'Exception: manager rejects, collaborator corrects and resubmits',
    (tester) async {
      await _start(tester, autoApprove: true);
      await _signInAs(tester, UserRole.employee);
      // A meal without a receipt: the control sends it to a manager. The
      // compliance agent says so before anything is sent.
      await _declare(tester, amount: '120', category: 'Repas');
      expect(find.byKey(const ValueKey('summary-preview')), findsOneWidget);
      expect(find.textContaining('Justificatif manquant'), findsOneWidget);
      await _tap(tester, 'summary-submit');
      expect(find.text('Transmise à votre responsable'), findsOneWidget);
      expect(find.textContaining('Justificatif manquant'), findsOneWidget);
      await _tap(tester, 'result-home');
      final id = state.mine.first.id;
      await _signOut(tester);

      await _signInAs(tester, UserRole.manager);
      await _tap(tester, 'tab-exceptions');
      await _tap(tester, 'exception-$id');
      expect(find.text('Décision nécessaire'), findsOneWidget);
      await _tap(tester, 'decision-reject');
      await _tap(tester, 'reject-confirm');
      expect(find.text('Le motif du rejet est obligatoire.'), findsOneWidget);
      await _type(tester, 'reject-reason', 'Merci de joindre le reçu.');
      await _tap(tester, 'reject-confirm');
      expect(find.byKey(ValueKey('exception-$id')), findsNothing);
      expect(state.byId(id)!.status, ExpenseStatus.rejected);
      // Let the confirmation message leave the screen.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _signOut(tester);

      await _signInAs(tester, UserRole.employee);
      expect(find.textContaining('rejetée'), findsWidgets);
      await _tap(tester, 'home-expense-$id');
      expect(find.text('Merci de joindre le reçu.'), findsOneWidget);
      await _tap(tester, 'detail-correct');
      expect(find.text('Corriger ma dépense'), findsOneWidget);
      await _tap(tester, 'form-category');
      await tester.tap(find.text('Fournitures').last);
      await tester.pumpAndSettle();
      await _tap(tester, 'form-continue');
      await _tap(tester, 'summary-submit');
      expect(find.text('Dépense validée'), findsOneWidget);
      expect(state.byId(id)!.status, ExpenseStatus.approved);
    },
  );

  testWidgets(
    'By default a manager confirms compliant expenses in one gesture',
    (tester) async {
      await _start(tester);
      await _signInAs(tester, UserRole.employee);
      // Fournitures needs no receipt: nothing to flag.
      await _declare(tester, amount: '45,50', category: 'Fournitures');
      expect(find.byKey(const ValueKey('summary-preview-ok')), findsOneWidget);
      await _tap(tester, 'summary-submit');
      expect(find.text('Conforme, en attente de validation'), findsOneWidget);
      await _tap(tester, 'result-home');
      final id = state.mine.first.id;
      expect(state.byId(id)!.status, ExpenseStatus.needsReview);
      await _signOut(tester);

      await _signInAs(tester, UserRole.manager);
      await _tap(tester, 'tab-exceptions');
      expect(find.byKey(const ValueKey('compliant-card')), findsOneWidget);
      // Not mixed with the exceptions that need a decision.
      expect(find.byKey(ValueKey('exception-$id')), findsNothing);
      await _tap(tester, 'compliant-all');
      await _tap(tester, 'compliant-confirm');
      expect(state.byId(id)!.status, ExpenseStatus.approved);
      expect(state.byId(id)!.approvedByAgent, isFalse);
      expect(find.byKey(const ValueKey('compliant-card')), findsNothing);
    },
  );

  testWidgets('The manager lets the control approve compliant expenses', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.manager);
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-rules');
    expect(state.autoApprove, isFalse);
    await _tap(tester, 'rules-auto-approve');
    expect(state.autoApprove, isTrue);
    expect(await backend.fetchAutoApprove(), isTrue);
  });

  testWidgets('A receipt in euros keeps what was paid; a rate fills the VAT', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-manual');
    await _type(tester, 'form-supplier', 'Café de Flore');
    await _type(tester, 'form-amount', '220,00');
    // Folded away for the usual receipt.
    expect(find.byKey(const ValueKey('form-currency')), findsNothing);
    await _tap(tester, 'form-details');
    await _tap(tester, 'form-rate-10');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('form-vat')))
          .controller!
          .text,
      '20,00',
    );
    expect(find.text('Calculée'), findsOneWidget);
    await _tap(tester, 'form-currency');
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'form-category');
    await tester.tap(find.text('Repas').last);
    await tester.pumpAndSettle();
    await _type(tester, 'form-reason', 'Déjeuner à Paris');
    await _tap(tester, 'form-continue');
    expect(find.text('Saisissez le montant payé, ex. 85,00.'), findsOneWidget);
    await _type(tester, 'form-foreign', '20,00');
    await _tap(tester, 'form-continue');
    expect(find.text('Montant payé (EUR)'), findsOneWidget);
    final draft = state.mine.first;
    expect(draft.currency, 'EUR');
    expect(draft.foreignAmountCents, 2000);
    expect(draft.amountCents, 22000);
    expect(draft.vatRate, 10);
    expect(draft.vatCents, 2000);
  });

  testWidgets('A captured receipt keeps what the agents proposed', (
    tester,
  ) async {
    await _start(
      tester,
      receiptPicker: ({required bool camera}) async =>
          PickedReceipt(Uint8List.fromList([1, 2, 3]), 'ticket.jpg'),
    );
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-photo');
    await tester.pumpAndSettle();
    await _tap(tester, 'form-save-draft');
    final saved = state.mine.firstWhere(
      (e) => e.status == ExpenseStatus.draft && e.agentProposal != null,
    );
    final fields = saved.agentProposal!['fields'] as Map;
    expect(saved.agentProposal!['engine'], 'demo');
    expect((fields['amount'] as Map)['value'], '24000');
    expect((fields['amount'] as Map)['confidence'], 'high');
    expect((fields['category'] as Map)['agent'], 'classification');
    expect(saved.captureStartedAt, isNotNull);
  });

  testWidgets('A PDF invoice is imported as the picture of its first page', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'home-add');
    pdfPicker = () async => PickedReceipt(
      Uint8List.fromList([1, 2, 3]),
      'facture.png',
      pdfPages: 3,
    );
    addTearDown(() => pdfPicker = pickPdfWithDevice);
    await _tap(tester, 'capture-import');
    await _tap(tester, 'import-pdf');
    await tester.pumpAndSettle();
    expect(find.text('Vérifier les informations'), findsOneWidget);
    expect(find.byKey(const ValueKey('form-pdf-pages')), findsOneWidget);
  });

  testWidgets('The OCR bench lists its 30 receipts', (tester) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-bench');
    expect(find.text('Banc d’essai OCR'), findsWidgets);
    // No ML Kit in tests: the screen says to run it on a phone.
    expect(
      find.text(
        'Pas de lecteur sur cet appareil : lancez le banc sur un téléphone.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('The accountant\'s profile stays short', (tester) async {
    await _start(tester);
    await _signInAs(tester, UserRole.accountant);
    await _tap(tester, 'tab-profile');
    expect(find.byKey(const ValueKey('profile-accounts')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-metrics')), findsNothing);
  });

  testWidgets('The manager reads the measures of the agents', (tester) async {
    await _start(tester);
    await _signInAs(tester, UserRole.manager);
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-metrics');
    expect(find.text('Mesures des agents'), findsWidgets);
    expect(
      find.byKey(const ValueKey('metrics-empty')).evaluate().isNotEmpty ||
          find
              .byKey(const ValueKey('metrics-acceptance'))
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
  });

  testWidgets('A manager cannot decide on their own expense', (tester) async {
    await _start(tester, managersDeclare: true);
    await _signInAs(tester, UserRole.manager);
    await _declare(tester, amount: '900');
    await _tap(tester, 'summary-submit');
    await _tap(tester, 'result-home');
    final own = state.mine.first;
    expect(own.status, ExpenseStatus.needsReview);
    // Not offered in the list of exceptions to decide.
    await _tap(tester, 'tab-exceptions');
    expect(find.byKey(ValueKey('exception-${own.id}')), findsNothing);
  });

  testWidgets('Duplicate: same day and amount is announced before submitting', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    final twin = state.byId('EXP-1041')!;
    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-manual');
    await _type(tester, 'form-supplier', 'Taxi Bleu');
    await _type(tester, 'form-amount', '85');
    final d = twin.date!;
    await _type(
      tester,
      'form-date',
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}',
    );
    await _tap(tester, 'form-category');
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await _type(tester, 'form-reason', 'Retour');
    await _tap(tester, 'form-continue');
    expect(find.text('Doublon possible'), findsOneWidget);
    await _tap(tester, 'duplicate-keep-draft');
    expect(find.text('Doublon possible'), findsNothing);
    expect(state.mine.first.status, ExpenseStatus.draft);
  });

  testWidgets('Interrupted sending keeps the expense and can be retried', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    final before = state.mine.length;
    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-manual');
    await _type(tester, 'form-supplier', 'Bureau Plus');
    await _type(tester, 'form-amount', '60');
    await _tap(tester, 'form-category');
    await tester.tap(find.text('Fournitures').last);
    await tester.pumpAndSettle();
    await _type(tester, 'form-reason', 'Papier');
    backend.offline = true;
    await _tap(tester, 'form-continue');
    expect(find.text('Envoi interrompu'), findsOneWidget);
    await _tap(tester, 'interrupted-retry');
    expect(find.text('Toujours pas de connexion.'), findsOneWidget);
    expect(state.mine.length, before);
    backend.offline = false;
    await _tap(tester, 'interrupted-retry');
    expect(find.text('Tout est correct ?'), findsOneWidget);
    expect(state.mine.length, before + 1);
  });

  testWidgets('Accountant: selection, total, export and history', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.accountant);
    await _tap(tester, 'tab-exports');
    final ready = state.toExport;
    expect(ready.length, 3);
    expect(find.text('3 dépenses sélectionnées'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('export-EXP-1035')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 dépenses sélectionnées'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('export-total'))).data,
      contains('445,00'),
    );

    await _tap(tester, 'export-prepare');
    // The export agent adds up the batch and asks for the missing accounts.
    expect(find.byKey(const ValueKey('export-agent')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-accounts')), findsOneWidget);
    await _tap(tester, 'export-accounts');
    await _type(tester, 'account-Transport', '6142');
    await _tap(tester, 'accounts-save');
    expect(state.accounts['Transport'], '6142');
    // Let the confirmation message leave the button free.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, 'export-generate');
    expect(find.text('Export prêt'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-totals-ok')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('export-summary'))).data,
      allOf(contains('2 dépenses'), contains('445,00')),
    );
    await _tap(tester, 'export-done');
    // The one left was unticked earlier and stays so.
    expect(find.text('0 dépenses sélectionnées'), findsOneWidget);
    expect(state.byId('EXP-1041')!.status, ExpenseStatus.exported);
    expect(state.byId('EXP-1035')!.status, ExpenseStatus.approved);
    expect(state.exports.length, 2);
  });

  testWidgets('Manager: invite a member and change a rule', (tester) async {
    await _start(tester);
    await _signInAs(tester, UserRole.manager);
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-team');
    expect(find.text('Ahmed El Fassi'), findsOneWidget);
    await _tap(tester, 'team-invite');
    await _type(tester, 'invite-email', 'karim@exemple.ma');
    await _tap(tester, 'invite-submit');
    // No e-mail is sent: the screen says what really happened.
    expect(find.text('Invitation enregistrée'), findsOneWidget);
    expect(find.textContaining('n’envoie pas encore d’e-mail'), findsOneWidget);
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation en attente'), findsOneWidget);
    await _tap(tester, 'page-back');

    await _tap(tester, 'profile-rules');
    await _tap(tester, 'rule-toggle-Repas');
    await _type(tester, 'rule-limit-Repas', '0');
    await _tap(tester, 'rule-save-Repas');
    expect(find.textContaining('plafond positif'), findsOneWidget);
    await _type(tester, 'rule-limit-Repas', '350');
    await _tap(tester, 'rule-save-Repas');
    expect(state.policyOf('Repas')!.limitCents, 35000);
  });

  testWidgets('WhatsApp: the author confirms what was understood', (
    tester,
  ) async {
    await _start(tester, autoApprove: true);
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'home-whatsapp');
    expect(find.text('Dépense reçue via WhatsApp'), findsOneWidget);
    expect(find.text('« Taxi, 45 dirhams, client Atlas. »'), findsOneWidget);
    expect(find.text('Client Atlas'), findsOneWidget);
    // Nothing was submitted by merely receiving the message.
    expect(state.byId('EXP-1034')!.status, ExpenseStatus.draft);
    await _tap(tester, 'whatsapp-confirm');
    expect(find.text('Dépense validée'), findsOneWidget);
    expect(state.byId('EXP-1034')!.status, ExpenseStatus.approved);
    await _tap(tester, 'result-home');
    expect(find.byKey(const ValueKey('home-whatsapp')), findsNothing);
  });

  testWidgets('WhatsApp: the demo shows a code but links nothing', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-whatsapp');
    // No number is typed in the app any more.
    expect(find.byKey(const ValueKey('whatsapp-phone')), findsNothing);
    await _tap(tester, 'whatsapp-request');
    final code = tester.widget<Text>(
      find.byKey(const ValueKey('whatsapp-code')),
    );
    expect(code.data, matches(RegExp(r'^LIER \d{6}$')));
    // The demo receives no message: the number stays unlinked.
    await _tap(tester, 'whatsapp-check');
    expect(find.byKey(const ValueKey('whatsapp-error')), findsOneWidget);
    expect(state.user!.whatsappPhone, isNull);
  });

  for (final role in UserRole.values) {
    testWidgets('${role.label}: the member card opens the profile in detail', (
      tester,
    ) async {
      await _start(
        tester,
        route: AppRoutes.home,
        size: const Size(320, 640),
        textScale: 2,
      );
      await _signInDirectly(tester, role);
      await _tap(tester, 'tab-profile');
      // The avatar shows first and last initials, e.g. « SB ».
      expect(state.user!.initials, hasLength(2));
      expect(find.text(state.user!.initials), findsOneWidget);
      // The whole card opens the detail; its centre may be below the
      // fold with large text.
      await _tap(tester, 'profile-name');
      expect(find.byKey(const ValueKey('profile-sheet')), findsOneWidget);
      expect(find.text(state.user!.email), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Accountant overview adds up the validated expenses', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.accountant);
    final now = DateTime.now();
    final month = state.expenses.where(
      (e) => e.date!.year == now.year && e.date!.month == now.month,
    );
    final total = month.fold<int>(0, (s, e) => s + e.amountCents);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-total')),
        matching: find.text(formatMad(total)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-to-export')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    await _tap(tester, 'overview-export');
    expect(find.text('3 dépenses sélectionnées'), findsOneWidget);
  });

  testWidgets('Routes are guarded by session and role', (tester) async {
    await _start(tester, route: AppRoutes.manager);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);

    await _signInAs(tester, UserRole.employee);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.rules);
    await tester.pumpAndSettle();
    expect(find.text('Accès réservé'), findsOneWidget);
    expect(find.text('Votre rôle : Collaborateur'), findsOneWidget);
    await _tap(tester, 'back-to-my-space');
    expect(find.text('Bonjour Marius'), findsOneWidget);

    navigator.pushNamed('/inconnue');
    await tester.pumpAndSettle();
    expect(find.text('Page introuvable'), findsOneWidget);
  });

  testWidgets('Activity lists status changes and marks them read', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    expect(state.unreadCount, greaterThan(0));
    await _tap(tester, 'home-bell');
    expect(find.text('Correction demandée'), findsOneWidget);
    await _tap(tester, 'activity-read-all');
    expect(state.unreadCount, 0);
  });

  testWidgets('What was read stays read after signing out and back in', (
    tester,
  ) async {
    await _start(tester);
    await _signInAs(tester, UserRole.employee);
    expect(state.unreadCount, greaterThan(0));
    state.markAllRead();
    await tester.pumpAndSettle();
    final email = state.user!.email;
    await state.signOut();
    await tester.pumpAndSettle();
    final done = state.signIn(email, 'x');
    await tester.pumpAndSettle();
    await done;
    await tester.pumpAndSettle();
    expect(state.unreadCount, 0);
  });

  for (final role in UserRole.values) {
    testWidgets('${role.label}: every tab fits a narrow phone, large text', (
      tester,
    ) async {
      await _start(
        tester,
        route: AppRoutes.home,
        size: const Size(320, 640),
        textScale: 2,
      );
      await _signInDirectly(tester, role);
      for (final tab in [
        role == UserRole.accountant ? 'tab-overview' : 'tab-home',
        if (role == UserRole.employee) 'tab-expenses',
        if (role == UserRole.manager) 'tab-exceptions',
        if (role == UserRole.accountant) 'tab-exports',
        'tab-activity',
        'tab-profile',
      ]) {
        await _tap(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  testWidgets('Signed out, the app opens on the welcome page', (tester) async {
    await _start(tester, route: AppRoutes.home);
    expect(find.byKey(const ValueKey('welcome-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsNothing);

    await _tap(tester, 'welcome-start');
    expect(find.byKey(const ValueKey('signup-email')), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'welcome-login');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    await _signInAs(tester, UserRole.employee);
    expect(find.byKey(const ValueKey('tab-profile')), findsOneWidget);

    // Signing out leads back to the welcome page.
    await _signOut(tester);
    expect(find.byKey(const ValueKey('welcome-start')), findsOneWidget);
  });

  testWidgets('The welcome page fits a narrow phone, large text', (
    tester,
  ) async {
    await _start(
      tester,
      route: AppRoutes.home,
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('welcome-login')));
    await tester.pumpAndSettle();
    await _tap(tester, 'welcome-login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Entry and form screens fit a narrow phone, large text', (
    tester,
  ) async {
    for (final route in [
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.forgotPassword,
    ]) {
      await _start(
        tester,
        route: route,
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: route);
    }
    await _start(
      tester,
      route: AppRoutes.home,
      size: const Size(320, 640),
      textScale: 2,
    );
    await _signInDirectly(tester, UserRole.manager);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in [
      AppRoutes.capture,
      AppRoutes.review,
      AppRoutes.team,
      AppRoutes.rules,
    ]) {
      navigator.pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'Receipt read: the values are proposed, the VAT can be corrected',
    (tester) async {
      // No camera in tests: a picture is handed over in its place.
      await _start(
        tester,
        receiptPicker: ({required bool camera}) async =>
            PickedReceipt(Uint8List.fromList([1, 2, 3]), 'ticket.jpg'),
      );
      await _signInAs(tester, UserRole.employee);
      await _tap(tester, 'home-add');
      await _tap(tester, 'capture-photo');
      await tester.pumpAndSettle();
      expect(find.text('Vérifier les informations'), findsOneWidget);
      String field(String key) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect(field('form-supplier'), 'Café Atlas');
      expect(field('form-amount'), '240,00');
      expect(field('form-vat'), '21,82');
      // The reading agent explains itself; the classification agent
      // proposes a category, which the person can still change.
      expect(find.byKey(const ValueKey('form-reading-report')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('form-proposed-category')),
        findsOneWidget,
      );
      expect(find.text('10 %'), findsOneWidget);

      // A VAT above the amount is refused, with the reason.
      await _tap(tester, 'form-category');
      await tester.tap(find.text('Repas').last);
      await tester.pumpAndSettle();
      await _type(tester, 'form-reason', 'Déjeuner client');
      await _type(tester, 'form-vat', '300');
      await _tap(tester, 'form-continue');
      expect(
        find.text('La TVA doit être inférieure au montant TTC.'),
        findsOneWidget,
      );

      // Corrected, it is what gets saved and shown.
      await _type(tester, 'form-vat', '40,00');
      await _tap(tester, 'form-continue');
      if (find
          .byKey(const ValueKey('duplicate-continue'))
          .evaluate()
          .isNotEmpty) {
        await _tap(tester, 'duplicate-continue');
      }
      expect(find.text('Tout est correct ?'), findsOneWidget);
      expect(find.text('TVA incluse'), findsOneWidget);
      expect(state.mine.first.vatCents, 4000);
    },
  );
}
