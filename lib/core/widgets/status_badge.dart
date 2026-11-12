import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/rembo_tokens.dart';
import '../l10n/l10n.dart';

enum BadgeTone { neutral, info, success, warning, danger }

/// Small pill label. Colours come in accessible text/tint pairs.
class RemboBadge extends StatelessWidget {
  const RemboBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  static (Color, Color) colors(BadgeTone tone) => switch (tone) {
    BadgeTone.neutral => (RemboColors.neutralText, RemboColors.neutralTint),
    BadgeTone.info => (RemboColors.infoText, RemboColors.infoTint),
    BadgeTone.success => (RemboColors.successText, RemboColors.successTint),
    BadgeTone.warning => (RemboColors.warningText, RemboColors.warningTint),
    BadgeTone.danger => (RemboColors.danger, RemboColors.dangerTint),
  };

  @override
  Widget build(BuildContext context) {
    final (text, tint) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(RemboRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: RemboText.label.copyWith(color: text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge for an expense status, with the French wording used everywhere.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.byAgent = false});

  StatusBadge.of(Expense expense, {Key? key})
    : this(
        key: key,
        status: expense.status,
        byAgent:
            expense.status == ExpenseStatus.approved && expense.approvedByAgent,
      );

  final ExpenseStatus status;

  /// Approved by the automatic control rather than by a manager.
  final bool byAgent;

  static BadgeTone toneOf(ExpenseStatus status) => switch (status) {
    ExpenseStatus.draft => BadgeTone.neutral,
    ExpenseStatus.submitted => BadgeTone.info,
    ExpenseStatus.needsReview => BadgeTone.warning,
    ExpenseStatus.approved => BadgeTone.success,
    ExpenseStatus.rejected => BadgeTone.danger,
    ExpenseStatus.exported => BadgeTone.info,
  };

  static IconData? iconOf(ExpenseStatus status) => switch (status) {
    ExpenseStatus.approved => Icons.check_circle_rounded,
    ExpenseStatus.rejected => Icons.cancel_rounded,
    _ => null,
  };

  @override
  Widget build(BuildContext context) => RemboBadge(
    label: byAgent ? tr('Validée par l’agent') : status.label,
    tone: toneOf(status),
    icon: iconOf(status),
  );
}
