import 'package:flutter/material.dart';

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
    initialRoute: initialRoute,
    onGenerateInitialRoutes: (route) => [
      AppRouter.onGenerateRoute(RouteSettings(name: route)),
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
