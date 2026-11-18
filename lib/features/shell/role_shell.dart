import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../accountant/export_tab.dart';
import '../accountant/overview_tab.dart';
import '../collaborator/expenses_tab.dart';
import '../collaborator/home_tab.dart';
import '../common/activity_tab.dart';
import '../common/profile_tab.dart';
import '../manager/exceptions_tab.dart';

/// Lets a tab switch to another one (« Voir tout », the bell…).
class ShellTabs extends InheritedNotifier<ValueNotifier<int>> {
  const ShellTabs({super.key, required super.notifier, required super.child});

  static void goTo(BuildContext context, ShellTab tab) {
    final scope = context.getInheritedWidgetOfExactType<ShellTabs>();
    final shell = context.findAncestorStateOfType<_RoleShellState>();
    if (scope == null || shell == null) return;
    final index = shell._tabs.indexWhere((t) => t.tab == tab);
    if (index >= 0) scope.notifier!.value = index;
  }
}

enum ShellTab {
  home,
  overview,
  expenses,
  exceptions,
  exports,
  activity,
  profile,
}

class _TabSpec {
  const _TabSpec(this.tab, this.label, this.icon, this.selectedIcon);
  final ShellTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The signed-in space: four tabs, chosen by the role given by the server.
class RoleShell extends StatefulWidget {
  const RoleShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell>
    with SingleTickerProviderStateMixin {
  late final _index = ValueNotifier<int>(widget.initialTab)
    ..addListener(_tabChanged);

  /// The tab that comes in fades and rises a little; tabs keep their state.
  late final _tabIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  void _tabChanged() {
    if (!RemboMotion.reduced(context)) _tabIn.forward(from: 0);
  }

  List<_TabSpec> _tabs = const [];

  static const _home = _TabSpec(
    ShellTab.home,
    'Accueil',
    Icons.home_outlined,
    Icons.home_rounded,
  );
  static const _expenses = _TabSpec(
    ShellTab.expenses,
    'Dépenses',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  );
  static const _activity = _TabSpec(
    ShellTab.activity,
    'Activité',
    Icons.notifications_none_rounded,
    Icons.notifications_rounded,
  );
  static const _profile = _TabSpec(
    ShellTab.profile,
    'Profil',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  );

  static List<_TabSpec> _tabsOf(UserRole role) => switch (role) {
    UserRole.employee => const [_home, _expenses, _activity, _profile],
    UserRole.manager => const [
      _home,
      _TabSpec(
        ShellTab.exceptions,
        'Exceptions',
        Icons.layers_outlined,
        Icons.layers_rounded,
      ),
      _activity,
      _profile,
    ],
    UserRole.accountant => const [
      _TabSpec(
        ShellTab.overview,
        'Synthèse',
        Icons.home_outlined,
        Icons.home_rounded,
      ),
      _TabSpec(
        ShellTab.exports,
        'Exports',
        Icons.cloud_upload_outlined,
        Icons.cloud_upload_rounded,
      ),
      _activity,
      _profile,
    ],
  };

  static Widget _body(ShellTab tab) => switch (tab) {
    ShellTab.home => const HomeTab(),
    ShellTab.overview => const OverviewTab(),
    ShellTab.expenses => const ExpensesTab(),
    ShellTab.exceptions => const ExceptionsTab(),
    ShellTab.exports => const ExportTab(),
    ShellTab.activity => const ActivityTab(),
    ShellTab.profile => const ProfileTab(),
  };

  @override
  void dispose() {
    _index.dispose();
    _tabIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _tabs = _tabsOf(state.role);
    return ShellTabs(
      notifier: _index,
      child: ValueListenableBuilder<int>(
        valueListenable: _index,
        builder: (context, index, _) {
          final current = index.clamp(0, _tabs.length - 1);
          return Scaffold(
            backgroundColor: RemboColors.background,
            body: RemboBackground(
              child: Column(
                children: [
                  if (state.isDemo) const _DemoBanner(),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: state.isDemo,
                      child: AnimatedBuilder(
                        animation: _tabIn,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic.transform(_tabIn.value);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - t)),
                              child: child,
                            ),
                          );
                        },
                        child: IndexedStack(
                          index: current,
                          children: [for (final t in _tabs) _body(t.tab)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: current,
              onDestinationSelected: (i) => _index.value = i,
              destinations: [
                for (final t in _tabs)
                  NavigationDestination(
                    key: ValueKey('tab-${t.tab.name}'),
                    icon: _TabIcon(t, state, selected: false),
                    selectedIcon: _TabIcon(t, state, selected: true),
                    label: tr(t.label),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon(this.spec, this.state, {required this.selected});
  final _TabSpec spec;
  final AppState state;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final count = switch (spec.tab) {
      ShellTab.activity => state.unreadCount,
      ShellTab.exceptions => state.toReview.length,
      _ => 0,
    };
    final icon = Icon(
      selected ? spec.selectedIcon : spec.icon,
      color: selected ? RemboColors.indigo : RemboColors.muted,
    );
    return count == 0
        ? icon
        : Badge(
            label: Text('$count'),
            backgroundColor: RemboColors.indigo,
            child: icon,
          );
  }
}

/// Always visible in demo mode: nothing shown is real or saved.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Material(
    color: RemboColors.night,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RemboSpace.lg,
          vertical: 6,
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 16, color: Colors.white),
            const SizedBox(width: RemboSpace.sm),
            Expanded(
              child: Text(
                tr('Démonstration · données fictives'),
                style: RemboText.caption.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
