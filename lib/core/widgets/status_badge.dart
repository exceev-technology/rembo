import 'package:flutter/material.dart';

import '../demo/demo_expenses.dart';
import '../theme/rembo_tokens.dart';

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
  const StatusBadge({super.key, required this.status});
  final DemoExpenseStatus status;

  static String labelOf(DemoExpenseStatus status) => switch (status) {
    DemoExpenseStatus.draft => 'Brouillon',
    DemoExpenseStatus.submitted => 'Soumise',
    DemoExpenseStatus.approved => 'Approuvée',
    DemoExpenseStatus.rejected => 'Rejetée',
  };

  static BadgeTone toneOf(DemoExpenseStatus status) => switch (status) {
    DemoExpenseStatus.draft => BadgeTone.neutral,
    DemoExpenseStatus.submitted => BadgeTone.info,
    DemoExpenseStatus.approved => BadgeTone.success,
    DemoExpenseStatus.rejected => BadgeTone.danger,
  };

  @override
  Widget build(BuildContext context) =>
      RemboBadge(label: labelOf(status), tone: toneOf(status));
}
