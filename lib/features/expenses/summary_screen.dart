import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'capture_screen.dart';
import 'confirmation_screen.dart';
import 'expense_draft.dart';

/// Step 3: last look before the simulated submission.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.draft});
  final ExpenseDraft draft;

  static const submitDelay = Duration(milliseconds: 900);

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _sending = false;

  Future<void> _submit() async {
    setState(() => _sending = true);
    await Future<void>.delayed(SummaryScreen.submitDelay);
    if (!mounted) return;
    final draft = widget.draft;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmationScreen(
          supplier: draft.value(DraftField.supplier),
          amountCentimes: draft.amountCentimes ?? 0,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    String show(DraftField f) {
      final v = draft.value(f).trim();
      if (v.isEmpty) return '—';
      if (f == DraftField.amount) return formatMad(draft.amountCentimes ?? 0);
      if (f == DraftField.vat) {
        final vat = ExpenseDraft.parseAmount(v);
        return vat == null ? v : formatMad(vat);
      }
      return v;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            const ExpenseStepLabel(3, 'Récapitulatif'),
            const SizedBox(height: RemboSpace.sm),
            const Text('Récapitulatif', style: RemboText.title),
            const SizedBox(height: RemboSpace.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(RemboSpace.lg),
                child: Column(
                  children: [
                    for (final f in DraftField.values) ...[
                      if (f != DraftField.values.first)
                        const Divider(height: RemboSpace.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(f.label, style: RemboText.caption),
                          ),
                          const SizedBox(width: RemboSpace.md),
                          Expanded(
                            flex: 2,
                            child: Text(
                              show(f),
                              key: ValueKey('summary-${f.name}'),
                              textAlign: TextAlign.right,
                              style:
                                  f == DraftField.amount || f == DraftField.vat
                                  ? RemboText.amount
                                  : RemboText.body,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: RemboSpace.lg),
            const RemboMessage(
              tone: MessageTone.info,
              title: 'Simulation',
              message:
                  'La dépense sera envoyée à votre responsable pour '
                  'validation. Rien n’est enregistré dans cette version.',
            ),
            const SizedBox(height: RemboSpace.xl),
            RemboPrimaryButton(
              key: const ValueKey('summary-submit'),
              label: 'Soumettre la dépense',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: _submit,
            ),
            const SizedBox(height: RemboSpace.md),
            RemboSecondaryButton(
              key: const ValueKey('summary-edit'),
              label: 'Modifier',
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
