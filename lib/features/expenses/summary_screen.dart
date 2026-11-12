import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../collaborator/expense_detail_screen.dart';
import 'interrupted_screen.dart';
import 'receipt_view.dart';

/// « Tout est correct ? » : last look before the expense is submitted.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.expenseId, this.receiptBytes});
  final String expenseId;
  final Uint8List? receiptBytes;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _loading = false;
  String? _failure;

  Future<void> _submit(Expense expense) async {
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
    return RemboPage(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RemboPrimaryButton(
            key: const ValueKey('summary-submit'),
            label: tr('Soumettre la dépense'),
            loading: _loading,
            onPressed: () => _submit(e),
          ),
          TextButton(
            key: const ValueKey('summary-edit'),
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            child: Text(tr('Modifier')),
          ),
        ],
      ),
      children: [
        RemboHero(
          title: tr('Tout est correct ?'),
          illustration: RemboArt.approved,
        ),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        RemboCard(
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RemboRadius.sm),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: ReceiptImage(
                        expense: e,
                        bytes: widget.receiptBytes,
                      ),
                    ),
                  ),
                  const SizedBox(width: RemboSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.supplier, style: RemboText.title),
                        const SizedBox(height: RemboSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RemboSpace.md,
                            vertical: RemboSpace.sm,
                          ),
                          decoration: BoxDecoration(
                            color: RemboColors.surface,
                            borderRadius: BorderRadius.circular(RemboRadius.sm),
                          ),
                          child: Text(
                            formatMad(e.amountCents),
                            key: const ValueKey('summary-amount'),
                            style: RemboText.amount.copyWith(
                              fontSize: 20,
                              color: RemboColors.night,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: RemboSpace.xl),
              DetailRow(
                Icons.calendar_today_outlined,
                tr('Date'),
                e.date == null ? '' : formatDateLong(e.date!),
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
              DetailRow(
                Icons.chat_bubble_outline_rounded,
                tr('Motif'),
                e.reason,
              ),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        InfoStrip(
          tr('Hors règles, votre responsable décide.'),
          icon: Icons.groups_2_outlined,
        ),
      ],
    );
  }
}

/// What the server decided right after the submission.
class SubmissionResultScreen extends StatelessWidget {
  const SubmissionResultScreen({super.key, required this.expenseId});
  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).byId(expenseId);
    if (e == null) return const RemboPage(children: []);
    final approved = e.status == ExpenseStatus.approved;
    return RemboPage(
      showBack: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RemboPrimaryButton(
            key: const ValueKey('result-home'),
            label: tr('Retour à l’accueil'),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          TextButton(
            key: const ValueKey('result-detail'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ExpenseDetailScreen(expenseId: e.id),
              ),
            ),
            child: Text(tr('Voir le suivi')),
          ),
        ],
      ),
      children: [
        RemboMoment(
          title: approved
              ? tr('Dépense validée')
              : tr('Transmise à votre responsable'),
          message: approved
              ? tr('Conforme aux règles de votre entreprise.')
              : tr('Un point est à examiner : votre responsable décide.'),
          illustration: approved ? RemboArt.approved : RemboArt.search,
        ),
        Center(
          child: CountUp(
            value: e.amountCents,
            format: formatMad,
            delay: const Duration(milliseconds: 250),
            style: RemboText.amount.copyWith(fontSize: 26),
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        Center(
          child: Entrance(
            order: 6,
            rise: 0,
            scaleFrom: .8,
            curve: Curves.easeOutBack,
            child: StatusBadge.of(e, key: const ValueKey('result-status')),
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        for (final f in e.flags)
          Padding(
            padding: const EdgeInsets.only(bottom: RemboSpace.sm),
            child: InfoStrip(
              '${f.kind.label} : ${trData(f.message)}',
              icon: Icons.warning_amber_rounded,
              color: RemboColors.warningText,
              background: RemboColors.warningTint,
            ),
          ),
      ],
    );
  }
}
