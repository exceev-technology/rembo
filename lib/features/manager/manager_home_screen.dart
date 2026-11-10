import 'package:flutter/material.dart';

import '../../core/demo/demo_expenses.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'approval_detail_screen.dart';
import 'approval_history_screen.dart';
import 'approval_store.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key, this.store});

  /// Defaults to a fresh fictional team.
  final ApprovalStore? store;

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  late final _store = widget.store ?? ApprovalStore.demo();
  DemoExpenseStatus? _filter = DemoExpenseStatus.submitted;

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  void _open(ApprovalRequest request) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ApprovalDetailScreen(store: _store, requestId: request.id),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final pending = _store.pending;
      final pendingTotal = pending.fold<int>(
        0,
        (sum, r) => sum + r.amountCentimes,
      );
      final shown = _store.requests
          .where((r) => _filter == null || r.status == _filter)
          .toList();
      Widget chip(String label, DemoExpenseStatus? value) => ChoiceChip(
        key: ValueKey('manager-filter-${value?.name ?? 'all'}'),
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      );
      return Scaffold(
        appBar: AppBar(
          title: const RemboLogo(size: 30),
          actions: [
            IconButton(
              key: const ValueKey('manager-history'),
              tooltip: 'Historique des décisions',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ApprovalHistoryScreen(store: _store),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(RemboSpace.xl),
            children: [
              const Text(
                'Espace responsable',
                key: ValueKey('destination-title'),
                style: RemboText.display,
              ),
              const SizedBox(height: RemboSpace.sm),
              Text(
                pending.isEmpty
                    ? 'Aucune demande en attente.'
                    : '${pending.length} demande${pending.length > 1 ? 's' : ''} '
                          'à traiter · ${formatMad(pendingTotal)}',
                key: const ValueKey('manager-summary'),
                style: RemboText.body,
              ),
              const SizedBox(height: RemboSpace.lg),
              Wrap(
                spacing: RemboSpace.sm,
                runSpacing: RemboSpace.sm,
                children: [
                  chip('À traiter', DemoExpenseStatus.submitted),
                  chip('Approuvées', DemoExpenseStatus.approved),
                  chip('Rejetées', DemoExpenseStatus.rejected),
                  chip('Toutes', null),
                ],
              ),
              const SizedBox(height: RemboSpace.lg),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: RemboSpace.xxl),
                  child: Text(
                    'Rien à afficher pour ce filtre.',
                    textAlign: TextAlign.center,
                    style: RemboText.caption,
                  ),
                ),
              for (final r in shown) ...[
                ExpenseCard(
                  key: ValueKey('request-${r.id}'),
                  supplier: r.supplier,
                  date: r.date,
                  amountCentimes: r.amountCentimes,
                  status: r.status,
                  subtitle: r.alerts.isEmpty
                      ? r.employee
                      : '${r.employee} · ⚠ ${r.alerts.length} alerte${r.alerts.length > 1 ? 's' : ''}',
                  onTap: () => _open(r),
                ),
                const SizedBox(height: RemboSpace.md),
              ],
            ],
          ),
        ),
      );
    },
  );
}
