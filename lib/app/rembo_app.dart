import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/data/app_state.dart';
import '../core/l10n/l10n.dart';
import '../core/theme/rembo_theme.dart';
import '../features/expenses/receipt_picker.dart';
import 'app_router.dart';
import 'app_routes.dart';

class RemboApp extends StatelessWidget {
  const RemboApp({
    super.key,
    required this.state,
    this.initialRoute = AppRoutes.home,
    this.receiptPicker = pickWithDevice,
  });
  final AppState state;
  final String initialRoute;

  /// How the screens obtain a receipt; tests hand over a picture instead.
  final ReceiptPicker receiptPicker;

  @override
  Widget build(BuildContext context) => ReceiptPickerScope(
    picker: receiptPicker,
    child: AppScope(
      state: state,
      child: ValueListenableBuilder<Locale>(
        valueListenable: appLocale,
        builder: (context, locale, _) => MaterialApp(
          title: 'REMBO',
          debugShowCheckedModeBanner: false,
          theme: RemboTheme.light(),
          locale: locale,
          supportedLocales: [for (final (l, _) in appLanguages) l],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          initialRoute: initialRoute,
          onGenerateInitialRoutes: (route) => [
            AppRouter.onGenerateRoute(RouteSettings(name: route)),
          ],
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    ),
  );
}
