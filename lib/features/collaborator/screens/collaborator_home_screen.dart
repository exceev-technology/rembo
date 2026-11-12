import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/demo/demo_expenses.dart';
import '../../../core/widgets/rembo_widgets.dart';
import '../widgets/expense_list_item.dart';
import 'expenses_list_screen.dart';

class CollaboratorHomeScreen extends StatelessWidget {
  const CollaboratorHomeScreen({super.key, this.expenses});

  /// Defaults to the shared fictional expenses.
  final List<DemoExpense>? expenses;

  @override
  Widget build(BuildContext context) {
    final expenses = this.expenses ?? demoExpenses;
    final total = expenses.fold<int>(0, (sum, e) => sum + e.amountCentimes);
    final recent = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    void add() => Navigator.of(context).pushNamed(AppRoutes.capture);
    void openList([DemoExpenseStatus? filter]) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ExpensesListScreen(expenses: expenses, initialFilter: filter),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const RemboLogo(size: 30),
        actions: [
          IconButton(
            tooltip: 'Paramètres',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            const Text('Bonjour Amina', style: RemboText.caption),
            const SizedBox(height: RemboSpace.xs),
            const Text(
              'Espace collaborateur',
              key: ValueKey('destination-title'),
              style: RemboText.display,
            ),
            const SizedBox(height: RemboSpace.xl),
            _TotalCard(count: expenses.length, totalCentimes: total),
            const SizedBox(height: RemboSpace.lg),
            RemboPrimaryButton(
              key: const ValueKey('collab-add'),
              label: 'Ajouter une dépense',
              icon: Icons.add_a_photo_outlined,
              onPressed: add,
            ),
            const SizedBox(height: RemboSpace.xl),
            const Text('Par statut', style: RemboText.subtitle),
            const SizedBox(height: RemboSpace.md),
            Wrap(
              spacing: RemboSpace.sm,
              runSpacing: RemboSpace.sm,
              children: [
                for (final status in DemoExpenseStatus.values)
                  ActionChip(
                    key: ValueKey('collab-status-${status.name}'),
                    label: Text(
                      '${StatusBadge.labelOf(status)} · '
                      '${expenses.where((e) => e.status == status).length}',
                    ),
                    onPressed: () => openList(status),
                  ),
              ],
            ),
            const SizedBox(height: RemboSpace.xl),
            Row(
              children: [
                const Expanded(
                  child: Text('Dernières dépenses', style: RemboText.subtitle),
                ),
                TextButton(
                  key: const ValueKey('collab-see-all'),
                  onPressed: openList,
                  child: const Text('Tout voir'),
                ),
              ],
            ),
            const SizedBox(height: RemboSpace.sm),
            if (recent.isEmpty)
              const NoExpenses(
                message: 'Vos dépenses apparaîtront ici dès la première.',
              )
            else
              for (final e in recent.take(3)) ...[
                ExpenseListItem(expense: e),
                const SizedBox(height: RemboSpace.md),
              ],
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.count, required this.totalCentimes});
  final int count;
  final int totalCentimes;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RemboSpace.xl),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [RemboColors.indigo, RemboColors.night],
      ),
      borderRadius: BorderRadius.circular(RemboRadius.lg),
      boxShadow: RemboElevation.floating,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count == 1 ? '1 dépense ce mois-ci' : '$count dépenses ce mois-ci',
          style: RemboText.caption.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: RemboSpace.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMad(totalCentimes),
            key: const ValueKey('collab-total'),
            style: RemboText.amount.copyWith(color: Colors.white, fontSize: 30),
          ),
        ),
      ],
    ),
  );
}
