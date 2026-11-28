import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'decision_screen.dart';

/// « À examiner » : only what the automatic control could not settle.
class ExceptionsTab extends StatelessWidget {
  const ExceptionsTab({super.key});

  static (IconData, BadgeTone) _look(FlagKind kind) => switch (kind) {
    FlagKind.policy => (Icons.warning_amber_rounded, BadgeTone.warning),
    FlagKind.ambiguity => (Icons.help_outline_rounded, BadgeTone.info),
    FlagKind.duplicate => (Icons.content_copy_rounded, BadgeTone.info),
  };

  Future<void> _confirmCompliant(BuildContext context) async {
    final state = AppScope.read(context);
    final compliant = state.compliantToConfirm;
    final go = await showRemboSheet<bool>(
      context,
      title: tr('Valider les dépenses conformes'),
      subtitle: tr(
        'Le contrôle n’a relevé aucun écart sur ces dépenses. Votre '
        'validation est enregistrée dans leur historique.',
      ),
      builder: (context) => Column(
        children: [
          for (final e in compliant)
            Padding(
              padding: const EdgeInsets.only(bottom: RemboSpace.sm),
              child: ExpenseTile(e, title: e.employeeName, showStatus: false),
            ),
          const SizedBox(height: RemboSpace.md),
          RemboPrimaryButton(
            key: const ValueKey('compliant-confirm'),
            label: tr('Valider {count}', {
              'count': expenseCount(compliant.length),
            }),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Annuler')),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      final n = await state.approveCompliant([for (final e in compliant) e.id]);
      if (!context.mounted) return;
      showRemboSnackBar(
        context,
        tr('Validation enregistrée : {count}.', {'count': expenseCount(n)}),
      );
    } on RemboException catch (e) {
      if (context.mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final compliant = state.compliantToConfirm;
    final pending = state.exceptions;
    int count(bool Function(FlagKind) test) =>
        pending.where((e) => e.flags.any((f) => test(f.kind))).length;
    final policy = count((k) => k == FlagKind.policy);
    final ambiguous = count((k) => k != FlagKind.policy);

    return RemboPage(
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      children: [
        RemboHero(
          overline: formatWeekday(DateTime.now()),
          title: tr('À examiner'),
          illustration: RemboArt.search,
        ),
        Row(
          children: [
            Expanded(
              child: _Count(
                Icons.warning_amber_rounded,
                tr('Écarts aux règles · {policy}', {'policy': policy}),
                RemboColors.warningText,
                RemboColors.warningTint,
              ),
            ),
            const SizedBox(width: RemboSpace.sm),
            Expanded(
              child: _Count(
                Icons.help_outline_rounded,
                tr('Ambiguïtés · {ambiguous}', {'ambiguous': ambiguous}),
                RemboColors.infoText,
                RemboColors.surface,
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.lg),
        if (state.loadError != null)
          RemboMessage(
            tone: MessageTone.error,
            title: tr('Chargement impossible'),
            message: state.loadError!.message,
            action: TextButton(
              onPressed: state.refresh,
              child: Text(tr('Réessayer')),
            ),
          )
        else if (compliant.isNotEmpty) ...[
          RemboCard(
            key: const ValueKey('compliant-card'),
            color: RemboColors.surface,
            borderColor: RemboColors.surface,
            child: Row(
              children: [
                const IconTile(Icons.verified_outlined),
                const SizedBox(width: RemboSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Conformes aux règles'),
                        style: RemboText.subtitle,
                      ),
                      Text(
                        expenseCount(compliant.length),
                        style: RemboText.caption,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  key: const ValueKey('compliant-all'),
                  onPressed: () => _confirmCompliant(context),
                  child: Text(tr('Tout valider')),
                ),
              ],
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (state.loadError == null && pending.isEmpty && compliant.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              key: const ValueKey('exceptions-empty'),
              children: [
                const HeroArt(height: 120, art: RemboArt.approved),
                const SizedBox(height: RemboSpace.lg),
                Text(tr('Rien à examiner'), style: RemboText.subtitle),
                Text(
                  tr('Aucune dépense n’attend votre décision.'),
                  style: RemboText.caption,
                ),
              ],
            ),
          ),
        for (final e in pending)
          ExpenseTile(
            e,
            key: ValueKey('exception-${e.id}'),
            title: e.employeeName,
            subtitle: e.reason,
            badge: e.flags.isEmpty
                ? null
                : RemboBadge(
                    label: trData(e.flags.first.message),
                    tone: _look(e.flags.first.kind).$2,
                    icon: _look(e.flags.first.kind).$1,
                  ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DecisionScreen(expenseId: e.id),
              ),
            ),
          ),
        const SizedBox(height: RemboSpace.sm),
        InfoStrip(
          state.autoApprove
              ? tr('Le reste est validé automatiquement.')
              : tr(
                  'Les dépenses conformes attendent votre validation : '
                  'réglage dans « Règles de remboursement ».',
                ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.icon, this.text, this.color, this.background);
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RemboSpace.md),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(RemboRadius.md),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: RemboSpace.sm),
        Expanded(
          child: Text(
            text,
            style: RemboText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
