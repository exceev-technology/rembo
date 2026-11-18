import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../expenses/receipt_view.dart';

/// « Décision nécessaire » : approve the exception or reject with a reason.
class DecisionScreen extends StatefulWidget {
  const DecisionScreen({super.key, required this.expenseId});
  final String expenseId;

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  final _note = TextEditingController();
  bool _loading = false;
  String? _failure;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve, String? reason}) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      await state.decide(
        widget.expenseId,
        approve: approve,
        reason: reason ?? _note.text,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Exception approuvée.' : 'Dépense rejetée.'),
        ),
      );
    } on RemboException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = e.message;
        });
      }
    }
  }

  Future<void> _reject(Expense e) async {
    final reason = await showRemboSheet<String>(
      context,
      title: 'Motiver le rejet',
      subtitle: '${e.employeeName} · ${formatMad(e.amountCents)}',
      builder: (context) => _RejectForm(initial: _note.text),
    );
    if (reason != null) await _decide(approve: false, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.byId(widget.expenseId);
    if (e == null) return const RemboPage(children: []);
    final own = e.employeeId == state.user?.id;
    final open = e.status == ExpenseStatus.needsReview;
    final rule = state.policyOf(e.category);

    return RemboPage(
      bottom: !open
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RemboPrimaryButton(
                  key: const ValueKey('decision-approve'),
                  label: 'Approuver l’exception',
                  loading: _loading,
                  onPressed: own ? null : () => _decide(approve: true),
                ),
                const SizedBox(height: RemboSpace.sm),
                RemboSecondaryButton(
                  key: const ValueKey('decision-reject'),
                  label: 'Rejeter',
                  onPressed: own || _loading ? null : () => _reject(e),
                ),
              ],
            ),
      children: [
        RemboMoment(
          title: open ? 'Décision nécessaire' : 'Dépense traitée',
          message: open
              ? 'Le contrôle automatique a relevé un point.'
              : 'Statut actuel : ${e.status.label}.',
          illustration: RemboArt.warning,
        ),
        if (own) ...[
          const RemboMessage(
            key: ValueKey('decision-own'),
            tone: MessageTone.info,
            title: 'C’est votre dépense',
            message: 'Un autre responsable doit prendre la décision.',
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        RemboCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: RemboColors.surface,
                child: Text(
                  e.employeeName.isEmpty ? '?' : e.employeeName[0],
                  style: RemboText.subtitle.copyWith(color: RemboColors.night),
                ),
              ),
              const SizedBox(width: RemboSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.employeeName, style: RemboText.subtitle),
                    Text(
                      e.date == null
                          ? e.supplier
                          : '${e.supplier} · ${formatDayShort(e.date!)}',
                      style: RemboText.caption,
                    ),
                  ],
                ),
              ),
              Text(formatMad(e.amountCents), style: RemboText.amount),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        for (final f in e.flags)
          Padding(
            padding: const EdgeInsets.only(bottom: RemboSpace.md),
            child: RemboCard(
              color: RemboColors.warningTint,
              borderColor: RemboColors.orange,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: RemboColors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: RemboSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.message,
                          style: RemboText.subtitle.copyWith(
                            color: RemboColors.warningText,
                          ),
                        ),
                        Text(
                          f.kind == FlagKind.policy && rule != null
                              ? 'Règle interne ${e.category} : '
                                    '${formatMad(rule.limitCents)}'
                              : f.kind.label,
                          style: RemboText.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ReceiptCard(expense: e),
        const SizedBox(height: RemboSpace.md),
        RemboCard(
          padding: const EdgeInsets.symmetric(
            horizontal: RemboSpace.lg,
            vertical: RemboSpace.sm,
          ),
          child: Column(
            children: [
              DetailRow(Icons.sell_outlined, 'Motif', e.reason),
              DetailRow(categoryIcon(e.category), 'Catégorie', e.category),
              if (e.project.isNotEmpty)
                DetailRow(Icons.layers_outlined, 'Projet', e.project),
            ],
          ),
        ),
        if (open && !own) ...[
          const SizedBox(height: RemboSpace.lg),
          RemboTextField(
            fieldKey: const ValueKey('decision-note'),
            label: 'Justification de la décision',
            hint: 'Facultative pour approuver',
            controller: _note,
            maxLines: 2,
            maxLength: 200,
          ),
        ],
      ],
    );
  }
}

class _RejectForm extends StatefulWidget {
  const _RejectForm({required this.initial});
  final String initial;

  @override
  State<_RejectForm> createState() => _RejectFormState();
}

class _RejectFormState extends State<_RejectForm> {
  late final _reason = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RemboTextField(
        fieldKey: const ValueKey('reject-reason'),
        label: 'Motif',
        required: true,
        hint: 'Ex. : merci de joindre un justificatif lisible.',
        controller: _reason,
        errorText: _error,
        helper: 'Ce message sera visible par le collaborateur.',
        maxLines: 3,
        maxLength: 200,
      ),
      const SizedBox(height: RemboSpace.lg),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('reject-confirm'),
          style: FilledButton.styleFrom(backgroundColor: RemboColors.danger),
          onPressed: () {
            final text = _reason.text.trim();
            if (text.isEmpty) {
              setState(() => _error = 'Le motif du rejet est obligatoire.');
            } else {
              Navigator.of(context).pop(text);
            }
          },
          child: const Text('Confirmer le rejet'),
        ),
      ),
      const SizedBox(height: RemboSpace.sm),
      RemboSecondaryButton(
        label: 'Annuler',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
