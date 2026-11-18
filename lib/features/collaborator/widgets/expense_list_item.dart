import 'package:flutter/material.dart';

import '../../../core/demo/demo_expenses.dart';
import '../../../core/widgets/rembo_widgets.dart';
import '../screens/expense_detail_screen.dart';

/// An expense card that opens its detail screen.
class ExpenseListItem extends StatelessWidget {
  const ExpenseListItem({super.key, required this.expense});
  final DemoExpense expense;

  @override
  Widget build(BuildContext context) => ExpenseCard.fromDemo(
    expense,
    key: ValueKey('expense-${expense.id}'),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailScreen(expense: expense),
      ),
    ),
  );
}

/// Shown when a list has nothing to display.
class NoExpenses extends StatelessWidget {
  const NoExpenses({super.key, required this.message, this.onAdd});
  final String message;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RemboSpace.xxl),
    child: Column(
      children: [
        const RemboIllustration(height: 120),
        const SizedBox(height: RemboSpace.lg),
        const Text(
          'Aucune dépense',
          style: RemboText.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RemboSpace.sm),
        Text(message, style: RemboText.caption, textAlign: TextAlign.center),
        if (onAdd != null) ...[
          const SizedBox(height: RemboSpace.xl),
          RemboPrimaryButton(
            label: 'Ajouter une dépense',
            icon: Icons.add_rounded,
            expand: false,
            onPressed: onAdd,
          ),
        ],
      ],
    ),
  );
}
