import 'package:flutter/material.dart';

import '../../core/demo/demo_expenses.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'export_history_screen.dart';
import 'export_preview_screen.dart';
import 'export_store.dart';

class AccountantHomeScreen extends StatefulWidget {
  const AccountantHomeScreen({super.key, this.store});

  /// Defaults to fictional approved expenses.
  final ExportStore? store;

  @override
  State<AccountantHomeScreen> createState() => _AccountantHomeScreenState();
}

class _AccountantHomeScreenState extends State<AccountantHomeScreen> {
  late final _store = widget.store ?? ExportStore.demo();
  String? _category;

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  void _push(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) {
      final visible = _store.toExport
          .where((e) => _category == null || e.category == _category)
          .toList();
      final allSelected =
          visible.isNotEmpty &&
          visible.every((e) => _store.selected.contains(e.id));
      Widget chip(String label, String? value) => ChoiceChip(
        key: ValueKey('category-${value ?? 'all'}'),
        label: Text(label),
        selected: _category == value,
        onSelected: (_) => setState(() => _category = value),
      );
      return Scaffold(
        appBar: AppBar(
          title: const RemboLogo(size: 30),
          actions: [
            IconButton(
              key: const ValueKey('export-history'),
              tooltip: 'Historique des exports',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => _push(ExportHistoryScreen(store: _store)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(RemboSpace.xl),
            children: [
              const Text(
                'Espace comptable',
                key: ValueKey('destination-title'),
                style: RemboText.display,
              ),
              const SizedBox(height: RemboSpace.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RemboSpace.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_store.toExport.length} dépenses approuvées '
                              'à exporter',
                              key: const ValueKey('accountant-count'),
                              style: RemboText.caption,
                            ),
                            const SizedBox(height: RemboSpace.xs),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatMad(_store.pendingTotal),
                                style: RemboText.amount.copyWith(fontSize: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.account_balance_outlined,
                        color: RemboColors.indigo,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RemboSpace.lg),
              Wrap(
                spacing: RemboSpace.sm,
                runSpacing: RemboSpace.sm,
                children: [
                  chip('Toutes', null),
                  for (final c in ExportStore.categories) chip(c, c),
                ],
              ),
              const SizedBox(height: RemboSpace.md),
              if (visible.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('select-all'),
                    icon: Icon(
                      allSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                    label: Text(
                      allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                    ),
                    onPressed: () => _store.toggleAll(visible),
                  ),
                ),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: RemboSpace.xxl),
                  child: Text(
                    'Aucune dépense approuvée à exporter.',
                    textAlign: TextAlign.center,
                    style: RemboText.caption,
                  ),
                ),
              for (final e in visible) ...[
                ExpenseCard(
                  key: ValueKey('accounting-${e.id}'),
                  supplier: e.supplier,
                  date: e.date,
                  amountCentimes: e.amountCentimes,
                  status: DemoExpenseStatus.approved,
                  subtitle: '${e.employee} · ${e.category}',
                  onTap: () => _store.toggle(e.id),
                  trailing: Checkbox(
                    value: _store.selected.contains(e.id),
                    onChanged: (_) => _store.toggle(e.id),
                  ),
                ),
                const SizedBox(height: RemboSpace.md),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(RemboSpace.lg),
            decoration: const BoxDecoration(
              color: RemboColors.card,
              border: Border(top: BorderSide(color: RemboColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _store.selected.isEmpty
                      ? 'Sélectionnez les dépenses à exporter.'
                      : '${_store.selected.length} sélectionnée'
                            '${_store.selected.length > 1 ? 's' : ''} · '
                            '${formatMad(_store.selectedTotal)}',
                  key: const ValueKey('selection-total'),
                  style: RemboText.caption.copyWith(color: RemboColors.ink),
                ),
                const SizedBox(height: RemboSpace.sm),
                RemboPrimaryButton(
                  key: const ValueKey('preview-export'),
                  label: 'Prévisualiser l’export',
                  onPressed: _store.selected.isEmpty
                      ? null
                      : () => _push(ExportPreviewScreen(store: _store)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
