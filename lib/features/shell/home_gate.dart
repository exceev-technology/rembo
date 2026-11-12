import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../auth/company_setup_screen.dart';
import '../auth/login_screen.dart';
import 'role_shell.dart';

/// Root screen: shows what the session allows, and follows its changes.
class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return const LoginScreen();
    if (user.companyId == null) return const CompanySetupScreen();
    return RoleShell(key: ValueKey(user.id));
  }
}
