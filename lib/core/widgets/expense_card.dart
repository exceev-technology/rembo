import 'package:flutter/material.dart';

import '../demo/demo_expenses.dart';
import '../format/formatters.dart';
import '../theme/rembo_tokens.dart';
import 'status_badge.dart';

/// One expense in a list: supplier, date, amount and status.
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.supplier,
    required this.date,
    required this.amountCentimes,
    required this.status,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  ExpenseCard.fromDemo(
    DemoExpense expense, {
    Key? key,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) : this(
         key: key,
         supplier: expense.supplier,
         date: expense.date,
         amountCentimes: expense.amountCentimes,
         status: expense.status,
         subtitle: subtitle,
         onTap: onTap,
         trailing: trailing,
       );

  final String supplier;
  final DateTime date;
  final int amountCentimes;
  final DemoExpenseStatus status;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RemboSpace.lg),
        child: Row(
          children: [
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: RemboSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          supplier,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RemboText.subtitle,
                        ),
                      ),
                      const SizedBox(width: RemboSpace.sm),
                      Flexible(child: StatusBadge(status: status)),
                    ],
                  ),
                  const SizedBox(height: RemboSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle == null
                              ? formatDate(date)
                              : '${formatDate(date)} · $subtitle',
                          style: RemboText.caption,
                        ),
                      ),
                      const SizedBox(width: RemboSpace.sm),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatMad(amountCentimes),
                            style: RemboText.amount,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
