import 'package:flutter/material.dart';

import '../data/models.dart';
import '../format/formatters.dart';
import '../theme/rembo_tokens.dart';
import 'rembo_page.dart';
import 'status_badge.dart';
import '../l10n/l10n.dart';

IconData categoryIcon(String category) => switch (category) {
  'Repas' => Icons.restaurant_rounded,
  'Transport' => Icons.local_taxi_outlined,
  'Hébergement' => Icons.bed_outlined,
  'Fournitures' => Icons.shopping_cart_outlined,
  _ => Icons.receipt_long_outlined,
};

/// One expense in a list: category pictogram, title, date, amount, status.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile(
    this.expense, {
    super.key,
    this.onTap,
    this.leading,
    this.title,
    this.subtitle,
    this.badge,
    this.showStatus = true,
  });
  final Expense expense;
  final VoidCallback? onTap;

  /// Replaces the pictogram, e.g. with a checkbox.
  final Widget? leading;
  final String? title;
  final String? subtitle;

  /// Replaces the status badge, e.g. with the reason of a review.
  final Widget? badge;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final date = expense.date;
    final when = date == null ? tr('Date à compléter') : formatDayShort(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: RemboSpace.sm),
      child: RemboCard(
        onTap: onTap,
        padding: const EdgeInsets.all(RemboSpace.md),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: RemboSpace.xs),
            ],
            IconTile(categoryIcon(expense.category)),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, box) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RemboText.subtitle,
                          ),
                        ),
                        const SizedBox(width: RemboSpace.sm),
                        // With very large text the amount shrinks to stay
                        // whole rather than push out of the card.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: box.maxWidth * .62,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              formatMad(expense.amountCents),
                              style: RemboText.amount,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RemboSpace.xs),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: RemboSpace.sm,
                      runSpacing: RemboSpace.xs,
                      children: [
                        Text(subtitle ?? when, style: RemboText.caption),
                        if (badge != null)
                          badge!
                        else if (showStatus)
                          StatusBadge.of(expense),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
