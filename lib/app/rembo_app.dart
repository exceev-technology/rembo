import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/rembo_theme.dart';
import 'app_router.dart';
import 'app_routes.dart';

class RemboApp extends StatelessWidget {
  const RemboApp({super.key, this.initialRoute = AppRoutes.menu});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'REMBO',
    debugShowCheckedModeBanner: false,
    theme: RemboTheme.light(),
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    initialRoute: initialRoute,
    onGenerateInitialRoutes: (route) => [
      AppRouter.onGenerateRoute(RouteSettings(name: route)),
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
