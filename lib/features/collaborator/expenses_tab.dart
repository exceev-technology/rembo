import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'expense_detail_screen.dart';

/// « Mes dépenses » : search, status filter and the full list.
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _search = TextEditingController();
  ExpenseStatus? _filter;

  static const _filters = <(ExpenseStatus?, String)>[
    (null, 'Toutes'),
    (ExpenseStatus.draft, 'Brouillons'),
    (ExpenseStatus.needsReview, 'À examiner'),
    (ExpenseStatus.approved, 'Validées'),
    (ExpenseStatus.rejected, 'Rejetées'),
    (ExpenseStatus.exported, 'Exportées'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final shown = state.mine.where((e) {
      if (_filter != null && e.status != _filter) return false;
      if (query.isEmpty) return true;
      return '${e.supplier} ${e.reason} ${e.category} ${e.project}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return RemboPage(
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('expenses-add'),
        tooltip: 'Nouvelle dépense',
        backgroundColor: RemboColors.indigo,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.capture),
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        const RemboHero(
          title: 'Mes dépenses',
          subtitle: 'Suivez vos dépenses, du brouillon à l’export.',
        ),
        TextField(
          key: const ValueKey('expenses-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher une dépense…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (status, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: RemboSpace.sm),
                  child: ChoiceChip(
                    key: ValueKey('filter-${status?.name ?? 'all'}'),
                    label: Text(label),
                    selected: _filter == status,
                    showCheckmark: false,
                    selectedColor: RemboColors.indigo,
                    labelStyle: RemboText.caption.copyWith(
                      color: _filter == status ? Colors.white : RemboColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              children: [
                const RemboIllustration(height: 110),
                const SizedBox(height: RemboSpace.lg),
                Text(
                  state.mine.isEmpty
                      ? 'Aucune dépense pour le moment'
                      : 'Aucune dépense ne correspond',
                  style: RemboText.subtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RemboSpace.xs),
                Text(
                  state.mine.isEmpty
                      ? 'Ajoutez votre premier justificatif avec le bouton +.'
                      : 'Modifiez la recherche ou le filtre.',
                  style: RemboText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final e in shown)
          ExpenseTile(
            e,
            key: ValueKey('expense-${e.id}'),
            onTap: () => ExpenseDetailScreen.open(context, e.id),
          ),
        const SizedBox(height: 72),
      ],
    );
  }
}
