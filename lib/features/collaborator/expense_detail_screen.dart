import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../expenses/expense_form_screen.dart';
import '../expenses/receipt_view.dart';
import '../manager/alone_manager_notice.dart';
import '../whatsapp/whatsapp.dart';
import '../whatsapp/whatsapp_expense_screen.dart';
import 'decision_explanation_screen.dart';

/// One expense: amount, status, receipt and the history of its statuses.
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});
  final String expenseId;

  static Future<void> open(BuildContext context, String id) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseDetailScreen(expenseId: id),
        ),
      );

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Supprimer ce brouillon ?')),
        content: Text(tr('Cette action est définitive.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Annuler')),
          ),
          TextButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Supprimer')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await AppScope.read(context).deleteDraft(expenseId);
      navigator.pop();
    } on RemboException catch (e) {
      if (context.mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.byId(expenseId);
    if (e == null) {
      return RemboPage(
        children: [
          RemboMoment(
            title: tr('Dépense introuvable'),
            message: tr('Elle a peut-être été supprimée.'),
          ),
        ],
      );
    }
    final own = e.employeeId == state.user?.id;
    final rejection = e.status == ExpenseStatus.rejected
        ? e.lastDecision
        : null;

    Widget? action;
    if (own && e.status == ExpenseStatus.draft && e.fromWhatsApp) {
      action = RemboPrimaryButton(
        key: const ValueKey('detail-whatsapp'),
        label: tr('Confirmer la dépense WhatsApp'),
        icon: Icons.chat_outlined,
        onPressed: () => WhatsAppExpenseScreen.open(context, e.id),
      );
    } else if (own && e.status == ExpenseStatus.draft) {
      action = RemboPrimaryButton(
        key: const ValueKey('detail-resume'),
        label: tr('Reprendre le brouillon'),
        icon: Icons.edit_outlined,
        onPressed: () => ExpenseFormScreen.open(context, expense: e),
      );
    } else if (own && e.status == ExpenseStatus.rejected) {
      action = RemboPrimaryButton(
        key: const ValueKey('detail-correct'),
        label: tr('Corriger ma dépense'),
        icon: Icons.edit_outlined,
        onPressed: () => ExpenseFormScreen.open(context, expense: e),
      );
    }

    return RemboPage(
      trailing: own && e.status == ExpenseStatus.draft
          ? IconButton(
              key: const ValueKey('detail-delete'),
              tooltip: tr('Supprimer le brouillon'),
              icon: const Icon(Icons.delete_outline_rounded),
              color: RemboColors.danger,
              onPressed: () => _delete(context),
            )
          : null,
      bottom: action,
      children: [
        RemboHero(
          overline: own
              ? tr('Dépense · {id}', {'id': e.id})
              : tr('Dépense de {employeeName}', {
                  'employeeName': e.employeeName,
                }),
          title: e.reason.isEmpty ? e.title : e.reason,
          below: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMad(e.amountCents),
                key: const ValueKey('detail-amount'),
                style: RemboText.amount.copyWith(fontSize: 26),
              ),
              const SizedBox(height: RemboSpace.md),
              StatusBadge.of(e, key: const ValueKey('detail-status')),
            ],
          ),
        ),
        if (rejection?.reason != null) ...[
          RemboMessage(
            tone: MessageTone.warning,
            title: tr('Commentaire du responsable'),
            message: rejection!.reason,
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (AloneManagerNotice.appliesTo(state, e)) ...[
          AloneManagerNotice(expense: e),
          const SizedBox(height: RemboSpace.lg),
        ],
        for (final f in e.flags)
          if (e.status == ExpenseStatus.needsReview)
            Padding(
              padding: const EdgeInsets.only(bottom: RemboSpace.sm),
              child: InfoStrip(
                '${f.kind.label} : ${trData(f.message)}',
                icon: Icons.warning_amber_rounded,
                color: RemboColors.warningText,
                background: RemboColors.warningTint,
              ),
            ),
        RemboCard(
          padding: const EdgeInsets.symmetric(
            horizontal: RemboSpace.lg,
            vertical: RemboSpace.sm,
          ),
          child: Column(
            children: [
              DetailRow(
                Icons.calendar_today_outlined,
                tr('Date'),
                e.date == null ? '' : formatWeekday(e.date!),
              ),
              DetailRow(
                Icons.storefront_outlined,
                tr('Fournisseur'),
                e.supplier,
              ),
              if (e.vatCents > 0)
                DetailRow(
                  Icons.percent_rounded,
                  tr('TVA incluse'),
                  formatMad(e.vatCents),
                  mono: true,
                ),
              DetailRow(
                categoryIcon(e.category),
                tr('Catégorie'),
                tr(e.category),
              ),
              if (e.project.isNotEmpty)
                DetailRow(Icons.layers_outlined, tr('Projet'), e.project),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        ReceiptCard(expense: e),
        if (e.fromWhatsApp) ...[
          const SizedBox(height: RemboSpace.md),
          RemboCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RemboBadge(
                  label: tr('Reçue par WhatsApp'),
                  tone: BadgeTone.success,
                  icon: Icons.chat_outlined,
                ),
                if ((e.transcript ?? '').isNotEmpty) ...[
                  const SizedBox(height: RemboSpace.sm),
                  Text('« ${e.transcript} »', style: RemboText.body),
                ],
                if (e.hasVoice)
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(tr('Écouter le message vocal')),
                    onPressed: () => playVoiceNote(context, e),
                  ),
              ],
            ),
          ),
        ],
        SectionTitle(tr('Suivi de la dépense')),
        _Timeline(e),
        if (e.status != ExpenseStatus.draft) ...[
          const SizedBox(height: RemboSpace.md),
          RemboCard(
            key: const ValueKey('detail-explain'),
            color: RemboColors.surface,
            borderColor: Colors.transparent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DecisionExplanationScreen(expenseId: e.id),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: RemboColors.indigo,
                ),
                const SizedBox(width: RemboSpace.md),
                Expanded(
                  child: Text(
                    tr('Comprendre la décision'),
                    style: RemboText.subtitle.copyWith(
                      color: RemboColors.indigo,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RemboColors.indigo,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.expense);
  final Expense expense;

  static String _label(ExpenseEvent ev) => switch (ev.status) {
    ExpenseStatus.draft => tr('Brouillon'),
    ExpenseStatus.submitted => tr('Confirmée et soumise'),
    ExpenseStatus.needsReview => tr('Transmise au responsable'),
    ExpenseStatus.approved =>
      ev.byAgent
          ? tr('Validée par l’agent')
          : tr('Validée par {actorName}', {'actorName': trData(ev.actorName)}),
    ExpenseStatus.rejected => tr('Rejetée par {actorName}', {
      'actorName': trData(ev.actorName),
    }),
    ExpenseStatus.exported => tr('Exportée en comptabilité'),
  };

  /// What the manager wrote with a decision, so the history reads alone.
  static String? _note(ExpenseEvent ev) {
    final text = ev.reason?.trim() ?? '';
    if (text.isEmpty || ev.byAgent) return null;
    return switch (ev.status) {
      ExpenseStatus.rejected => tr('Motif : {text}', {'text': text}),
      ExpenseStatus.approved => tr('Commentaire : {text}', {'text': text}),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    String at(DateTime d) => '${formatWeekday(d)} · ${formatTime(d)}';
    final steps = <(String, String, bool, bool, String?)>[
      (
        expense.fromWhatsApp ? tr('Reçue par WhatsApp') : tr('Capturée'),
        at(expense.createdAt),
        true,
        false,
        null,
      ),
      for (final ev in expense.events)
        (
          _label(ev),
          at(ev.at),
          true,
          ev.status == ExpenseStatus.rejected,
          _note(ev),
        ),
      if (expense.status == ExpenseStatus.draft)
        (tr('Soumission'), tr('À faire'), false, false, null),
      if (expense.status == ExpenseStatus.needsReview)
        (tr('Décision du responsable'), tr('En attente'), false, false, null),
      if (expense.status == ExpenseStatus.approved)
        (tr('Export'), tr('À préparer'), false, false, null),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Icon(
                      steps[i].$4
                          ? Icons.cancel_rounded
                          : (steps[i].$3
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked),
                      color: steps[i].$4
                          ? RemboColors.danger
                          : (steps[i].$3
                                ? RemboColors.green
                                : RemboColors.muted),
                      size: 24,
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: steps[i + 1].$3
                              ? RemboColors.green
                              : RemboColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: RemboSpace.lg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: RemboSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: RemboText.subtitle),
                        Text(steps[i].$2, style: RemboText.caption),
                        if (steps[i].$5 != null) ...[
                          const SizedBox(height: RemboSpace.xs),
                          Text(
                            steps[i].$5!,
                            key: ValueKey('timeline-note-$i'),
                            style: RemboText.body,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
