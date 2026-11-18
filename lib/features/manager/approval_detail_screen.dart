import 'package:flutter/material.dart';

import '../../core/demo/demo_expenses.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'approval_store.dart';

class ApprovalDetailScreen extends StatelessWidget {
  const ApprovalDetailScreen({
    super.key,
    required this.store,
    required this.requestId,
  });
  final ApprovalStore store;
  final String requestId;

  Future<void> _approve(BuildContext context, ApprovalRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver la dépense ?'),
        content: Text(
          '${r.supplier} · ${formatMad(r.amountCentimes)}\n'
          'Elle sera transmise à la comptabilité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('confirm-approve'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    store.approve(r.id);
    showRemboSnackBar(context, 'Dépense approuvée');
    Navigator.of(context).pop();
  }

  Future<void> _reject(BuildContext context, ApprovalRequest r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !context.mounted) return;
    store.reject(r.id, reason);
    showRemboSnackBar(context, 'Dépense rejetée', tone: MessageTone.warning);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final r = store.byId(requestId);
      final open = r.status == DemoExpenseStatus.submitted;
      return Scaffold(
        appBar: AppBar(title: const Text('Détail de la demande')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(RemboSpace.xl),
            children: [
              Text(r.supplier, style: RemboText.title),
              const SizedBox(height: RemboSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(status: r.status),
              ),
              const SizedBox(height: RemboSpace.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RemboSpace.lg),
                  child: Column(
                    children: [
                      _Line('Collaborateur', r.employee),
                      const Divider(height: RemboSpace.xl),
                      _Line('Montant', formatMad(r.amountCentimes), mono: true),
                      const Divider(height: RemboSpace.xl),
                      _Line('Date', formatDate(r.date)),
                      const Divider(height: RemboSpace.xl),
                      _Line('Catégorie', r.category),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RemboSpace.lg),
              for (final alert in r.alerts) ...[
                RemboMessage(
                  tone: MessageTone.warning,
                  title: 'À vérifier',
                  message: alert,
                ),
                const SizedBox(height: RemboSpace.md),
              ],
              Container(
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RemboColors.surface,
                  borderRadius: BorderRadius.circular(RemboRadius.lg),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 40,
                      color: RemboColors.indigo,
                    ),
                    SizedBox(height: RemboSpace.sm),
                    Text('Justificatif fictif', style: RemboText.caption),
                  ],
                ),
              ),
              const SizedBox(height: RemboSpace.xl),
              if (open && r.mine) ...[
                const RemboMessage(
                  key: ValueKey('self-approval'),
                  tone: MessageTone.info,
                  title: 'Action indisponible',
                  message:
                      'Une autre personne doit valider vos propres dépenses.',
                ),
                const SizedBox(height: RemboSpace.lg),
              ],
              if (open) ...[
                RemboPrimaryButton(
                  key: const ValueKey('approve'),
                  label: 'Approuver',
                  icon: Icons.check_rounded,
                  onPressed: r.mine ? null : () => _approve(context, r),
                ),
                const SizedBox(height: RemboSpace.md),
                RemboSecondaryButton(
                  key: const ValueKey('reject'),
                  label: 'Rejeter',
                  icon: Icons.close_rounded,
                  onPressed: r.mine ? null : () => _reject(context, r),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _reason.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Le motif est obligatoire.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Motif du rejet'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Le collaborateur verra ce motif.',
            style: RemboText.caption,
          ),
          const SizedBox(height: RemboSpace.md),
          TextField(
            key: const ValueKey('reject-reason'),
            controller: _reason,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex. justificatif incomplet',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-reject'),
        onPressed: _confirm,
        child: const Text('Rejeter'),
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: RemboText.caption)),
      const SizedBox(width: RemboSpace.md),
      Expanded(
        flex: 2,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: mono ? RemboText.amount : RemboText.body,
        ),
      ),
    ],
  );
}
