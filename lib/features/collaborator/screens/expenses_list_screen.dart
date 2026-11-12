import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/demo/demo_expenses.dart';
import '../../../core/widgets/rembo_widgets.dart';
import '../widgets/expense_list_item.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key, this.expenses, this.initialFilter});
  final List<DemoExpense>? expenses;
  final DemoExpenseStatus? initialFilter;

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  late DemoExpenseStatus? _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final all = widget.expenses ?? demoExpenses;
    final shown =
        all.where((e) => _filter == null || e.status == _filter).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    Widget chip(String label, DemoExpenseStatus? value, String key) => Padding(
      padding: const EdgeInsets.only(right: RemboSpace.sm),
      child: ChoiceChip(
        key: ValueKey(key),
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mes dépenses')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: RemboSpace.xl,
                vertical: RemboSpace.sm,
              ),
              child: Row(
                children: [
                  chip('Toutes', null, 'filter-all'),
                  for (final s in DemoExpenseStatus.values)
                    chip(StatusBadge.labelOf(s), s, 'filter-${s.name}'),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(RemboSpace.xl),
                      child: NoExpenses(
                        message: _filter == null
                            ? 'Ajoutez votre premier justificatif pour commencer.'
                            : 'Aucune dépense avec le statut '
                                  '« ${StatusBadge.labelOf(_filter!)} ».',
                        onAdd: () =>
                            Navigator.of(context).pushNamed(AppRoutes.capture),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(RemboSpace.xl),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: RemboSpace.md),
                      itemBuilder: (_, i) => ExpenseListItem(expense: shown[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
