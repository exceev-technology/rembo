import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../expenses/expense_form_screen.dart';
import '../expenses/interrupted_screen.dart';
import '../expenses/summary_screen.dart';
import 'whatsapp.dart';

/// « Dépense reçue via WhatsApp » : what was understood from the message,
/// for its author to confirm. Nothing is submitted without that tap.
class WhatsAppExpenseScreen extends StatefulWidget {
  const WhatsAppExpenseScreen({super.key, required this.expenseId});
  final String expenseId;

  static Future<void> open(BuildContext context, String id) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WhatsAppExpenseScreen(expenseId: id),
        ),
      );

  @override
  State<WhatsAppExpenseScreen> createState() => _WhatsAppExpenseScreenState();
}

class _WhatsAppExpenseScreenState extends State<WhatsAppExpenseScreen> {
  bool _loading = false;
  String? _failure;

  Future<void> _confirm(Expense expense) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _failure = null;
    });
    Expense? result;
    try {
      result = await state.submit(expense.id);
    } on RemboException catch (e) {
      if (!mounted) return;
      if (e.network) {
        result = await InterruptedScreen.show<Expense>(
          context,
          expense: expense,
          retry: () => state.submit(expense.id),
        );
      } else {
        setState(() => _failure = e.message);
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SubmissionResultScreen(expenseId: expense.id),
      ),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).byId(widget.expenseId);
    if (e == null) return const RemboPage(children: []);
    final missing = e.missingFields;
    final open = e.status == ExpenseStatus.draft;
    return RemboPage(
      bottom: !open
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RemboPrimaryButton(
                  key: const ValueKey('whatsapp-confirm'),
                  label: 'Confirmer et envoyer',
                  icon: Icons.arrow_forward_rounded,
                  loading: _loading,
                  onPressed: missing.isEmpty ? () => _confirm(e) : null,
                ),
                TextButton(
                  key: const ValueKey('whatsapp-edit'),
                  onPressed: _loading
                      ? null
                      : () => ExpenseFormScreen.open(context, expense: e),
                  child: Text(missing.isEmpty ? 'Modifier' : 'Compléter'),
                ),
              ],
            ),
      children: [
        RemboHero(
          title: 'Dépense reçue via WhatsApp',
          subtitle: e.hasVoice
              ? 'Votre message vocal a été converti en dépense.'
              : 'Votre message a été converti en dépense.',
          below: open ? null : StatusBadge.of(e),
        ),
        RemboCard(
          color: RemboColors.surface,
          borderColor: Colors.transparent,
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, color: RemboColors.night),
                  ),
                  const SizedBox(width: RemboSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.employeeName, style: RemboText.subtitle),
                        Text(
                          '${formatRelativeDay(e.createdAt)}, '
                          '${formatTime(e.createdAt)}',
                          style: RemboText.caption,
                        ),
                      ],
                    ),
                  ),
                  const RemboBadge(
                    label: 'WhatsApp',
                    tone: BadgeTone.success,
                    icon: Icons.chat_outlined,
                  ),
                ],
              ),
              if (e.hasVoice) ...[
                const SizedBox(height: RemboSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('whatsapp-play'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Écouter le message vocal'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () => playVoiceNote(context, e),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        if ((e.transcript ?? '').isNotEmpty)
          InfoStrip(
            '« ${e.transcript} »',
            icon: e.hasVoice ? Icons.translate_rounded : Icons.notes_rounded,
          )
        else
          const InfoStrip(
            'Le message n’a pas pu être transcrit : écoutez-le puis '
            'complétez la dépense.',
            icon: Icons.hearing_outlined,
            color: RemboColors.warningText,
            background: RemboColors.warningTint,
          ),
        const SizedBox(height: RemboSpace.lg),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        RemboCard(
          padding: const EdgeInsets.symmetric(
            horizontal: RemboSpace.lg,
            vertical: RemboSpace.sm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DetailRow(
                      categoryIcon(e.category),
                      'Catégorie',
                      e.category,
                    ),
                  ),
                  if (open && e.category.isNotEmpty)
                    const RemboBadge(
                      label: 'Proposé',
                      tone: BadgeTone.info,
                      icon: Icons.auto_awesome_outlined,
                    ),
                ],
              ),
              DetailRow(
                Icons.payments_outlined,
                'Montant',
                e.amountCents > 0 ? formatMad(e.amountCents) : '',
                mono: true,
              ),
              DetailRow(Icons.storefront_outlined, 'Fournisseur', e.supplier),
              DetailRow(Icons.groups_outlined, 'Client ou projet', e.project),
              DetailRow(
                Icons.calendar_today_outlined,
                'Date',
                e.date == null ? '' : formatDateLong(e.date!),
              ),
              DetailRow(Icons.notes_rounded, 'Motif', e.reason),
            ],
          ),
        ),
        if (open && missing.isNotEmpty) ...[
          const SizedBox(height: RemboSpace.md),
          InfoStrip(
            'À compléter avant l’envoi : ${missing.join(', ')}.',
            key: const ValueKey('whatsapp-missing'),
            icon: Icons.edit_note_rounded,
            color: RemboColors.warningText,
            background: RemboColors.warningTint,
          ),
        ],
      ],
    );
  }
}
