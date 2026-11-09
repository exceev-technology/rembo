import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'navigation_menu_screen.dart';
import 'placeholder_screen.dart';

abstract final class AppRouter {
  /// Destinations whose real screen exists; every other one is provisional.
  static final Map<String, WidgetBuilder> screens = {};

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
