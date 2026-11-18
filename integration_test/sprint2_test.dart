// Sprint 2 on a real phone, against a real Supabase: a person declares an
// expense with its receipt, and the picture lands in the private storage
// where nobody else can read it.
//
// Against the local stack (nothing leaves the PC):
//   supabase start
//   adb reverse tcp:54321 tcp:54321
//   flutter test integration_test/sprint2_test.dart -d <phone> \
//     --dart-define-from-file=.env.local
//
// The camera cannot be driven by a test: the picture is drawn here and
// handed to the app in place of the gallery. Everything after that (form,
// upload, storage rules, display) is the real path.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rembo/features/expenses/receipt_picker.dart';
import 'package:rembo/features/onboarding/splash_screen.dart';
import 'package:rembo/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Pause after each action, so that a person can follow on the phone.
const _pace = Duration(milliseconds: 900);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Still not on screen after ${timeout.inSeconds} s: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(_pace);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _waitFor(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(_key(key));
  await tester.pump(_pace);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await _waitFor(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _signUpWithCompany(
  WidgetTester tester, {
  required String first,
  required String email,
  required String company,
}) async {
  await _tap(tester, 'welcome-start');
  await _type(tester, 'signup-email', email);
  await _type(tester, 'signup-first', first);
  await _type(tester, 'signup-last', 'Test');
  await _type(tester, 'signup-password', 'Secret#2026');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(_pace);
  await _tap(tester, 'signup-submit');
  await _type(tester, 'company-name', company);
  FocusManager.instance.primaryFocus?.unfocus();
  await _tap(tester, 'company-submit');
  await _waitFor(tester, _key('tab-profile'));
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, 'tab-profile');
  await _tap(tester, 'profile-signout');
  await _waitFor(tester, _key('welcome-start'));
}

/// A white « ticket » with a few dark lines, as a PNG.
Future<Uint8List> _drawReceipt() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 300, 420),
    Paint()..color = Colors.white,
  );
  final ink = Paint()..color = const Color(0xFF2E2A7E);
  for (var i = 0; i < 6; i++) {
    canvas.drawRect(Rect.fromLTWH(30, 40.0 + i * 50, 240.0 - i * 25, 14), ink);
  }
  final image = await recorder.endRecording().toImage(300, 420);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// HTTP status of a request made with the public key only, signed out.
Future<int> _anonymousGet(String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_url$path'));
    request.headers.set('apikey', _anonKey);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sprint 2: an expense and its receipt, in private storage', (
    tester,
  ) async {
    final run = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final supplier = 'Café Test $run';
    final picture = await _drawReceipt();
    // The app as main() starts it, with the drawn picture as the gallery.
    runApp(
      app.RemboBoot(
        receiptPicker: ({required bool camera}) async =>
            PickedReceipt(picture, 'ticket-test.png'),
      ),
    );
    // The app is built behind the opening: wait until the logo is gone.
    await tester.pump(const Duration(seconds: 1));
    final opened = DateTime.now().add(const Duration(seconds: 40));
    while (find.byType(SplashScreen).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(opened)) fail('The opening never ended.');
      await tester.pump(const Duration(milliseconds: 200));
    }
    // A previous run may have left someone signed in.
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('welcome-start') ||
            w.key == const ValueKey('tab-profile'),
      ),
    );
    if (_key('tab-profile').evaluate().isNotEmpty) await _signOut(tester);
    final supabase = Supabase.instance.client;

    // 1. Sara creates her account and her company.
    await _signUpWithCompany(
      tester,
      first: 'Sara',
      email: 'sara.s2.$run@exemple.ma',
      company: 'Atelier S2 $run',
    );
    final sara = supabase.auth.currentUser!.id;

    // 2. She declares an expense from a picture of the receipt.
    await _tap(tester, 'tab-home');
    await _tap(tester, 'home-add');
    await _tap(tester, 'capture-import');
    await _type(tester, 'form-supplier', supplier);
    await _type(tester, 'form-amount', '45,50');
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'form-category');
    await tester.tap(find.text('Repas').last);
    await tester.pump(_pace);
    await _type(tester, 'form-reason', 'Déjeuner client');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(_pace);
    await _tap(tester, 'form-continue');

    // 3. The summary shows what will be sent; she submits.
    await _waitFor(tester, _key('summary-amount'));
    expect(tester.widget<Text>(_key('summary-amount')).data, contains('45,50'));
    await _tap(tester, 'summary-submit');
    await _waitFor(tester, _key('result-status'));
    expect(find.text('Dépense validée'), findsOneWidget);

    // 4. On the server: the row belongs to her, is approved by the
    //    automatic control, and points to a file in her own folder.
    final row = await supabase
        .from('expenses')
        .select('id, employee_id, amount_cents, status, receipt_path')
        .eq('supplier_name', supplier)
        .single();
    final path = row['receipt_path'] as String;
    expect(row['employee_id'], sara);
    expect(row['amount_cents'], 4550);
    expect(row['status'], 'approved');
    expect(path, '$sara/${row['id']}');

    // 5. The file stored is the picture that was chosen, byte for byte.
    final stored = await supabase.storage.from('receipts').download(path);
    expect(stored, picture);

    // 6. The bucket is private: no public address, nothing when signed out.
    expect(
      await _anonymousGet('/storage/v1/object/public/receipts/$path'),
      isNot(200),
    );
    expect(
      await _anonymousGet('/storage/v1/object/receipts/$path'),
      isNot(200),
    );

    // 7. The app shows the receipt again on the expense.
    await _tap(tester, 'result-detail');
    await _waitFor(tester, _key('receipt-zoom'));
    await _waitFor(
      tester,
      find.descendant(
        of: find
            .ancestor(of: _key('receipt-zoom'), matching: find.byType(Row))
            .first,
        matching: find.byType(Image),
      ),
    );
    await _tap(tester, 'page-back');

    // 8. Someone from another company can neither read nor list it.
    await _signOut(tester);
    await _signUpWithCompany(
      tester,
      first: 'Zed',
      email: 'zed.s2.$run@autre.ma',
      company: 'Autre S2 $run',
    );
    expect(supabase.auth.currentUser!.id, isNot(sara));
    Object? refused;
    try {
      await supabase.storage.from('receipts').download(path);
    } on Object catch (e) {
      refused = e;
    }
    expect(refused, isNotNull, reason: 'another company read the receipt');
    expect(await supabase.storage.from('receipts').list(path: sara), isEmpty);
    expect(
      await supabase
          .from('expenses')
          .select('id')
          .eq('supplier_name', supplier),
      isEmpty,
    );
    await _signOut(tester);
  });
}
