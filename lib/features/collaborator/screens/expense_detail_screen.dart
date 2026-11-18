import 'package:flutter/material.dart';

import '../../../core/demo/demo_expenses.dart';
import '../../../core/widgets/rembo_widgets.dart';

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expense});
  final DemoExpense expense;

  static (MessageTone, String, String) _explain(DemoExpenseStatus s) =>
      switch (s) {
        DemoExpenseStatus.draft => (
          MessageTone.info,
          'Brouillon',
          'Cette dépense n’a pas encore été envoyée à votre responsable.',
        ),
        DemoExpenseStatus.submitted => (
          MessageTone.info,
          'En attente de validation',
          'Votre responsable a reçu la dépense et doit la valider.',
        ),
        DemoExpenseStatus.approved => (
          MessageTone.success,
          'Approuvée',
          'La dépense est validée et sera transmise à la comptabilité.',
        ),
        DemoExpenseStatus.rejected => (
          MessageTone.error,
          'Rejetée',
          'Votre responsable a refusé cette dépense. Consultez le motif '
              'et déclarez-la de nouveau si nécessaire.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final (tone, title, message) = _explain(expense.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la dépense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            Text(expense.supplier, style: RemboText.title),
            const SizedBox(height: RemboSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: expense.status),
            ),
            const SizedBox(height: RemboSpace.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(RemboSpace.lg),
                child: Column(
                  children: [
                    _Line('Montant', formatMad(expense.amountCentimes)),
                    const Divider(height: RemboSpace.xl),
                    _Line('Date', formatDate(expense.date)),
                    const Divider(height: RemboSpace.xl),
                    _Line('Devise', 'MAD'),
                    const Divider(height: RemboSpace.xl),
                    _Line('Référence', expense.id),
                  ],
                ),
              ),
            ),
            const SizedBox(height: RemboSpace.lg),
            RemboMessage(tone: tone, title: title, message: message),
            const SizedBox(height: RemboSpace.lg),
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RemboColors.surface,
                borderRadius: BorderRadius.circular(RemboRadius.lg),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 40,
                    color: RemboColors.indigo,
                  ),
                  SizedBox(height: RemboSpace.sm),
                  Text('Justificatif fictif', style: RemboText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: RemboText.caption)),
      const SizedBox(width: RemboSpace.md),
      Flexible(
        child: Text(value, textAlign: TextAlign.right, style: RemboText.amount),
      ),
    ],
  );
}
