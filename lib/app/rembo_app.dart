import 'package:flutter/material.dart';

import '../core/theme/skeleton_colors.dart';
import 'app_router.dart';
import 'app_routes.dart';

class RemboApp extends StatelessWidget {
  const RemboApp({super.key, this.initialRoute = AppRoutes.menu});
  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'REMBO · Première ébauche',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SkeletonColors.primary,
        primary: SkeletonColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: SkeletonColors.ink,
      ),
      scaffoldBackgroundColor: SkeletonColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: SkeletonColors.background,
        foregroundColor: SkeletonColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    initialRoute: initialRoute,
    onGenerateInitialRoutes: (route) => [
      AppRouter.onGenerateRoute(RouteSettings(name: route)),
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
