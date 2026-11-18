import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/features/whatsapp/whatsapp.dart';

/// Stands for the server: the number becomes linked once the person has
/// sent « LIER 123456 » from it ([received]).
class _Server extends DemoBackend {
  _Server() : super(latency: Duration.zero);

  bool received = false;
  int codesGiven = 0;

  @override
  Future<WhatsAppLinkCode> requestWhatsAppCode() async {
    codesGiven++;
    return WhatsAppLinkCode(
      code: '123456',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<AppUser?> restoreSession() async {
    final user = await super.restoreSession();
    return received ? user?.withWhatsApp('+212612345678') : user;
  }

  @override
  Future<AppUser> unlinkWhatsApp() async {
    received = false;
    return super.unlinkWhatsApp();
  }
}

late AppState state;
late _Server _server;

Future<void> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  _server = _Server();
  state = AppState(_server);
  await tester.pumpWidget(
    RemboApp(state: state, initialRoute: AppRoutes.login),
  );
  await tester.pumpAndSettle();
  final done = state.signIn(DemoBackend.marius.email, 'x');
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  showWhatsAppSheet(navigator.context);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A number is linked only after its code came from WhatsApp', (
    tester,
  ) async {
    await _openSheet(tester);
    await _tap(tester, 'whatsapp-request');
    expect(find.text('LIER 123456'), findsOneWidget);

    // Not sent yet: nothing is linked.
    await _tap(tester, 'whatsapp-check');
    expect(find.byKey(const ValueKey('whatsapp-error')), findsOneWidget);
    expect(state.user!.whatsappPhone, isNull);

    // The server received the code from the person's WhatsApp.
    _server.received = true;
    await _tap(tester, 'whatsapp-check');
    expect(state.user!.whatsappPhone, '+212612345678');
    expect(find.byKey(const ValueKey('whatsapp-linked')), findsOneWidget);
    expect(find.byKey(const ValueKey('whatsapp-code')), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, 'whatsapp-unlink');
    expect(state.user!.whatsappPhone, isNull);
  });

  testWidgets('Without a server, no code can be asked for', (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final local = AppState(LocalBackend());
    await expectLater(
      local.requestWhatsAppCode(),
      throwsA(isA<RemboException>()),
    );
  });
}
