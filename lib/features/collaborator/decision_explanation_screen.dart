import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Comprendre la décision » : each control, and what it concluded.
/// Everything shown comes from the expense, its flags and the rules.
class DecisionExplanationScreen extends StatelessWidget {
  const DecisionExplanationScreen({super.key, required this.expenseId});
  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.byId(expenseId);
    if (e == null) return const RemboPage(children: []);
    final rule = state.policyOf(e.category);
    bool has(FlagKind k) => e.flags.any((f) => f.kind == k);
    String messages(FlagKind k) =>
        e.flags.where((f) => f.kind == k).map((f) => f.message).join(' · ');
    final over = rule != null && e.amountCents > rule.limitCents;
    final decision = e.lastDecision;

    return RemboPage(
      children: [
        const Center(child: HeroArt(height: 120)),
        const SizedBox(height: RemboSpace.lg),
        Semantics(
          header: true,
          child: Text(
            'Comprendre la décision',
            style: RemboText.display.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: RemboSpace.xs),
        Text(
          '${e.id} · ${formatMad(e.amountCents)}',
          style: RemboText.subtitle.copyWith(color: RemboColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RemboSpace.md),
        Center(child: StatusBadge.of(e)),
        const SizedBox(height: RemboSpace.xl),
        _Check(
          icon: Icons.document_scanner_outlined,
          title: 'Justificatif',
          summary: e.hasReceipt ? 'Justificatif joint' : 'Aucun justificatif',
          ok: e.hasReceipt || !(rule?.receiptRequired ?? false),
          details: [
            (
              'Exigé pour ${e.category}',
              (rule?.receiptRequired ?? false) ? 'Oui' : 'Non',
            ),
          ],
        ),
        _Check(
          icon: Icons.sell_outlined,
          title: 'Catégorie',
          summary: e.category,
          ok: e.category != 'Autre',
          details: const [],
        ),
        _Check(
          icon: Icons.shield_outlined,
          title: 'Règles',
          summary: rule == null
              ? 'Aucun plafond défini pour cette catégorie'
              : (over ? 'Plafond dépassé' : 'Dans le plafond'),
          ok: !over,
          expanded: true,
          details: [
            if (rule != null) ('Plafond interne', formatMad(rule.limitCents)),
            ('Montant', formatMad(e.amountCents)),
            if (over)
              ('Dépassement', formatMad(e.amountCents - rule.limitCents)),
          ],
        ),
        _Check(
          icon: Icons.layers_outlined,
          title: 'Doublons',
          summary: has(FlagKind.duplicate)
              ? messages(FlagKind.duplicate)
              : 'Aucun doublon détecté',
          ok: !has(FlagKind.duplicate),
          details: const [],
        ),
        if (has(FlagKind.ambiguity))
          _Check(
            icon: Icons.help_outline_rounded,
            title: 'Ambiguïtés',
            summary: messages(FlagKind.ambiguity),
            ok: false,
            details: const [],
          ),
        _Check(
          icon: Icons.task_alt_rounded,
          title: 'Décision',
          summary: switch (e.status) {
            ExpenseStatus.needsReview =>
              'En attente de la décision d’un responsable',
            ExpenseStatus.rejected => 'Rejetée par ${decision?.actorName}',
            ExpenseStatus.approved || ExpenseStatus.exported =>
              e.approvedByAgent
                  ? 'Contrôles conformes, dépense validée automatiquement'
                  : 'Validée par ${decision?.actorName}',
            _ => 'Pas encore soumise',
          },
          ok:
              e.status == ExpenseStatus.approved ||
              e.status == ExpenseStatus.exported,
          expanded: decision?.reason != null,
          details: [
            if (decision?.reason != null) ('Motif', decision!.reason!),
            if (decision != null)
              (
                'Date',
                '${formatDate(decision.at)} · ${formatTime(decision.at)}',
              ),
          ],
        ),
        const SizedBox(height: RemboSpace.sm),
        Text(
          'Une erreur ? Parlez-en à votre responsable : lui seul peut revoir '
          'une décision.',
          style: RemboText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.icon,
    required this.title,
    required this.summary,
    required this.ok,
    required this.details,
    this.expanded = false,
  });
  final IconData icon;
  final String title;
  final String summary;
  final bool ok;
  final List<(String, String)> details;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.sm),
    child: RemboCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded && details.isNotEmpty,
          enabled: details.isNotEmpty,
          leading: Icon(icon, color: RemboColors.night),
          title: Text(title, style: RemboText.subtitle),
          subtitle: Text(
            summary,
            style: RemboText.caption.copyWith(
              color: ok ? RemboColors.muted : RemboColors.warningText,
            ),
          ),
          trailing: details.isEmpty
              ? Icon(
                  ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: ok ? RemboColors.green : RemboColors.orange,
                )
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(
            RemboSpace.lg,
            0,
            RemboSpace.lg,
            RemboSpace.md,
          ),
          children: [
            for (final (label, value) in details)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label, style: RemboText.body)),
                    const SizedBox(width: RemboSpace.md),
                    Flexible(
                      child: Text(
                        value,
                        style: RemboText.amount,
                        textAlign: TextAlign.right,
                      ),
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
