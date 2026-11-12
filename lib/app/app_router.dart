import 'package:flutter/material.dart';

import '../core/data/app_state.dart';
import '../core/data/models.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/common/profile_tab.dart';
import '../features/expenses/capture_screen.dart';
import '../features/expenses/expense_form_screen.dart';
import '../features/manager/rules_screen.dart';
import '../features/manager/team_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/shell/access_denied_screen.dart';
import '../features/shell/home_gate.dart';
import '../features/shell/role_shell.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static const _public = {
    AppRoutes.home,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
  };

  /// Routes open to some roles only. The server enforces the same rule
  /// (row level security); this keeps the interface consistent with it.
  static const _roles = <String, Set<UserRole>>{
    AppRoutes.manager: {UserRole.manager},
    AppRoutes.team: {UserRole.manager},
    AppRoutes.rules: {UserRole.manager},
    AppRoutes.accountant: {UserRole.accountant},
  };

  static final Map<String, WidgetBuilder> screens = {
    AppRoutes.home: (_) => const HomeGate(),
    AppRoutes.welcome: (_) => const WelcomeScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signup: (_) => const SignupScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.collaborator: (_) => const RoleShell(),
    AppRoutes.manager: (_) => const RoleShell(initialTab: 1),
    AppRoutes.accountant: (_) => const RoleShell(initialTab: 1),
    AppRoutes.capture: (_) => const CaptureScreen(),
    AppRoutes.review: (_) => const ExpenseFormScreen(),
    AppRoutes.team: (_) => const TeamScreen(),
    AppRoutes.rules: (_) => const RulesScreen(),
    AppRoutes.settings: (_) => const ProfileTab(embedded: false),
  };

  static Route<void> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    final screen = screens[name];
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        if (screen == null) return const NotFoundScreen();
        if (_public.contains(name)) return screen(context);
        final state = AppScope.of(context);
        if (state.user == null) return const LoginScreen();
        final allowed = _roles[name];
        if (allowed != null && !allowed.contains(state.role)) {
          return AccessDeniedScreen(reservedTo: allowed.first);
        }
        return screen(context);
      },
    );
  }
}
