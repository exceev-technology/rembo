import 'package:flutter/material.dart';

import '../features/accountant/accountant_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/collaborator/screens/collaborator_home_screen.dart';
import '../features/common/screens/settings_screen.dart';
import '../features/expenses/capture_screen.dart';
import '../features/expenses/review_screen.dart';
import '../features/manager/manager_home_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import 'app_routes.dart';
import 'navigation_menu_screen.dart';
import 'placeholder_screen.dart';

abstract final class AppRouter {
  /// Destinations whose real screen exists; every other one is provisional.
  static final Map<String, WidgetBuilder> screens = {
    AppRoutes.welcome: (_) => const WelcomeScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.collaborator: (_) => const CollaboratorHomeScreen(),
    AppRoutes.capture: (_) => const CaptureScreen(),
    AppRoutes.review: (_) => const ReviewScreen(),
    AppRoutes.manager: (_) => const ManagerHomeScreen(),
    AppRoutes.accountant: (_) => const AccountantHomeScreen(),
    AppRoutes.settings: (_) => const SettingsScreen(),
  };

  static Route<void> onGenerateRoute(RouteSettings settings) {
    final WidgetBuilder builder = settings.name == AppRoutes.menu
        ? (_) => const NavigationMenuScreen()
        : screens[settings.name] ??
              (_) => PlaceholderScreen(
                destination: AppRoutes.destinationFor(settings.name),
              );
    return MaterialPageRoute<void>(settings: settings, builder: builder);
  }
}
