import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../shell/role_shell.dart';
import '../whatsapp/whatsapp_expense_screen.dart';
import 'expense_detail_screen.dart';

/// « Bonjour … » : what needs attention, and the latest expenses.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return const SizedBox.shrink();
    final mine = state.mine;
    final drafts = mine.where((e) => e.status == ExpenseStatus.draft).length;
    final rejected = mine
        .where((e) => e.status == ExpenseStatus.rejected)
        .length;
    final review = mine
        .where((e) => e.status == ExpenseStatus.needsReview)
        .length;
    final toDecide = state.toReview.length;
    final toExport = state.toExport.length;

    void add() => Navigator.of(context).pushNamed(AppRoutes.capture);

    return RemboPage(
      logo: true,
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      trailing: IconButton(
        key: const ValueKey('home-bell'),
        tooltip: tr('Activité'),
        icon: Badge(
          isLabelVisible: state.unreadCount > 0,
          backgroundColor: RemboColors.indigo,
          child: const Icon(Icons.notifications_none_rounded),
        ),
        color: RemboColors.night,
        onPressed: () => ShellTabs.goTo(context, ShellTab.activity),
      ),
      children: [
        if (state.loadError != null) ...[
          RemboMessage(
            tone: MessageTone.error,
            title: tr('Chargement impossible'),
            message: state.loadError!.message,
            action: TextButton(
              key: const ValueKey('retry'),
              onPressed: state.refresh,
              child: Text(tr('Réessayer')),
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (mine.isEmpty && !state.loading && state.loadError == null)
          ..._firstExpense(context, user, add)
        else ...[
          RemboHero(
            title: tr('Bonjour {firstName}', {'firstName': user.firstName}),
          ),
          if (toDecide > 0 && state.role == UserRole.manager) ...[
            _Callout(
              key: const ValueKey('home-to-review'),
              icon: Icons.layers_outlined,
              text: toDecide == 1
                  ? tr('1 dépense attend votre décision')
                  : tr('{toDecide} dépenses attendent votre décision', {
                      'toDecide': toDecide,
                    }),
              onTap: () => ShellTabs.goTo(context, ShellTab.exceptions),
            ),
            const SizedBox(height: RemboSpace.sm),
          ],
          if (toExport > 0 && state.role == UserRole.accountant) ...[
            _Callout(
              key: const ValueKey('home-to-export'),
              icon: Icons.cloud_upload_outlined,
              text: toExport == 1
                  ? tr('1 dépense validée à exporter')
                  : tr('{toExport} dépenses validées à exporter', {
                      'toExport': toExport,
                    }),
              onTap: () => ShellTabs.goTo(context, ShellTab.exports),
            ),
            const SizedBox(height: RemboSpace.sm),
          ],
          for (final w in state.whatsappToConfirm.take(1)) ...[
            _Callout(
              key: const ValueKey('home-whatsapp'),
              icon: Icons.chat_outlined,
              text: state.whatsappToConfirm.length == 1
                  ? tr('1 dépense reçue par WhatsApp à confirmer')
                  : tr(
                      '{whatsappToConfirm} dépenses reçues par WhatsApp à confirmer',
                      {'whatsappToConfirm': state.whatsappToConfirm.length},
                    ),
              onTap: () => WhatsAppExpenseScreen.open(context, w.id),
            ),
            const SizedBox(height: RemboSpace.sm),
          ],
          if (rejected > 0) ...[
            _Callout(
              key: const ValueKey('home-to-fix'),
              icon: Icons.edit_note_rounded,
              warning: true,
              text: rejected == 1
                  ? tr('1 dépense rejetée à corriger')
                  : tr('{rejected} dépenses rejetées à corriger', {
                      'rejected': rejected,
                    }),
              onTap: () => _openList(context, state),
            ),
            const SizedBox(height: RemboSpace.sm),
          ],
          const SizedBox(height: RemboSpace.sm),
          RemboPrimaryButton(
            key: const ValueKey('home-add'),
            label: tr('Nouvelle dépense'),
            icon: Icons.photo_camera_outlined,
            onPressed: add,
          ),
          const SizedBox(height: RemboSpace.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(Icons.layers_outlined, drafts, tr('Brouillons')),
              ),
              const SizedBox(width: RemboSpace.md),
              Expanded(
                child: _Stat(
                  Icons.visibility_outlined,
                  review,
                  tr('À examiner'),
                ),
              ),
            ],
          ),
          SectionTitle(
            tr('Dépenses récentes'),
            action: tr('Voir tout'),
            onAction: () => _openList(context, state),
          ),
          if (state.loading && mine.isEmpty)
            const Padding(
              padding: EdgeInsets.all(RemboSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final e in mine.take(4))
            ExpenseTile(
              e,
              key: ValueKey('home-expense-${e.id}'),
              onTap: () => ExpenseDetailScreen.open(context, e.id),
            ),
        ],
      ],
    );
  }

  static void _openList(BuildContext context, AppState state) {
    if (state.role == UserRole.employee) {
      ShellTabs.goTo(context, ShellTab.expenses);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MyExpensesScreen()));
    }
  }

  List<Widget> _firstExpense(
    BuildContext context,
    AppUser user,
    VoidCallback add,
  ) => [
    const SizedBox(height: RemboSpace.sm),
    Text(
      tr('Bienvenue {firstName}.', {'firstName': user.firstName}),
      style: RemboText.title,
    ),
    const SizedBox(height: RemboSpace.lg),
    const Center(child: HeroArt(height: 170)),
    const SizedBox(height: RemboSpace.xl),
    Semantics(
      header: true,
      child: Text(
        tr('Votre première dépense commence ici.'),
        style: RemboText.display,
        textAlign: TextAlign.center,
      ),
    ),
    const SizedBox(height: RemboSpace.xl),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Step(Icons.photo_camera_outlined, tr('Photo')),
        _Step(Icons.verified_user_outlined, tr('Vérification')),
        _Step(Icons.layers_outlined, tr('Suivi')),
      ],
    ),
    const SizedBox(height: RemboSpace.xl),
    RemboPrimaryButton(
      key: const ValueKey('home-add'),
      label: tr('Ajouter une dépense'),
      icon: Icons.photo_camera_outlined,
      onPressed: add,
    ),
  ];
}

/// The « Dépenses » list as a pushed screen, for roles without that tab.
class MyExpensesScreen extends StatelessWidget {
  const MyExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return RemboPage(
      logo: true,
      children: [
        RemboHero(title: tr('Mes dépenses')),
        for (final e in state.mine)
          ExpenseTile(e, onTap: () => ExpenseDetailScreen.open(context, e.id)),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.warning = false,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? RemboColors.warningText : RemboColors.infoText;
    return RemboCard(
      onTap: onTap,
      color: warning ? RemboColors.warningTint : RemboColors.surface,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: RemboSpace.lg,
        vertical: RemboSpace.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: RemboSpace.md),
          Expanded(
            child: Text(
              text,
              style: RemboText.subtitle.copyWith(color: color, fontSize: 14.5),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.count, this.label);
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => RemboCard(
    color: RemboColors.surface,
    borderColor: Colors.transparent,
    onTap: () => ShellTabs.goTo(context, ShellTab.expenses),
    child: Row(
      children: [
        Icon(icon, color: RemboColors.indigo, size: 28),
        const SizedBox(width: RemboSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: RemboText.title),
              Text(label, style: RemboText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconTile(icon, size: 52),
      const SizedBox(height: RemboSpace.sm),
      Text(label, style: RemboText.caption.copyWith(color: RemboColors.ink)),
    ],
  );
}
