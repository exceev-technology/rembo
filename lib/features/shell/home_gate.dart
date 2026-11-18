import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/motion/rembo_motion.dart';
import '../auth/company_setup_screen.dart';
import '../onboarding/welcome_screen.dart';
import 'role_shell.dart';

/// Root screen: shows what the session allows, and follows its changes.
/// Each change of stage (signed out → company to create → signed in)
/// arrives with a short fade instead of replacing the screen at once.
class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    // The welcome page plays its own arrival.
    if (user == null) return const WelcomeScreen();
    final Widget stage = user.companyId == null
        ? const CompanySetupScreen()
        : RoleShell(key: ValueKey(user.id));
    return ColoredBox(
      color: const Color(0xFFF1EEFF),
      child: Entrance(
        key: ValueKey('${user.id}-${user.companyId == null}'),
        rise: 0,
        scaleFrom: .975,
        child: stage,
      ),
    );
  }
}
