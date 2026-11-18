import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../collaborator/home_tab.dart';
import '../shell/role_shell.dart';

/// « Synthèse » : the month at a glance, from the expenses the accountant
/// may read (validated or exported).
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final month = state.expenses.where((e) {
      final d = e.date;
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          (e.status == ExpenseStatus.approved ||
              e.status == ExpenseStatus.exported);
    }).toList();
    int sum(Iterable<Expense> list) =>
        list.fold<int>(0, (s, e) => s + e.amountCents);
    final total = sum(month);
    final byAgent = month.where((e) => e.approvedByAgent).length;
    final vat = month.fold<int>(0, (s, e) => s + e.vatCents);
    final toExport = state.toExport;
    final categories = <String, int>{};
    for (final e in month) {
      categories[e.category] = (categories[e.category] ?? 0) + e.amountCents;
    }
    final ranked = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.isEmpty ? 1 : ranked.first.value;

    return RemboPage(
      logo: true,
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      children: [
        RemboHero(
          overline: formatMonth(now),
          title: 'Le mois, d’un coup d’œil',
          art: false,
        ),
        if (state.loadError != null) ...[
          RemboMessage(
            tone: MessageTone.error,
            title: 'Chargement impossible',
            message: state.loadError!.message,
            action: TextButton(
              onPressed: state.refresh,
              child: const Text('Réessayer'),
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        Row(
          children: [
            Expanded(
              child: _Figure(
                'Dépenses validées',
                formatMad(total),
                '${month.length} ce mois-ci',
                key: const ValueKey('overview-total'),
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: _Figure(
                'Validées par l’agent',
                '$byAgent / ${month.length}',
                'sans intervention humaine',
                key: const ValueKey('overview-agent'),
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.md),
        Row(
          children: [
            Expanded(
              child: _Figure(
                'TVA déclarée',
                formatMad(vat),
                'sur les justificatifs',
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: _Figure(
                'À exporter',
                '${toExport.length}',
                formatMad(sum(toExport)),
                key: const ValueKey('overview-to-export'),
              ),
            ),
          ],
        ),
        const SectionTitle('Dépenses par catégorie'),
        if (ranked.isEmpty)
          Text('Aucune dépense validée ce mois-ci.', style: RemboText.caption)
        else
          RemboCard(
            child: Column(
              children: [
                for (final c in ranked)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: RemboSpace.sm,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              categoryIcon(c.key),
                              size: 18,
                              color: RemboColors.night,
                            ),
                            const SizedBox(width: RemboSpace.sm),
                            Expanded(child: Text(c.key, style: RemboText.body)),
                            Text(formatMad(c.value), style: RemboText.amount),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: c.value / top,
                            minHeight: 6,
                            backgroundColor: RemboColors.surface,
                            color: RemboColors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: RemboSpace.lg),
        RemboPrimaryButton(
          key: const ValueKey('overview-export'),
          label: 'Préparer un export',
          icon: Icons.cloud_upload_outlined,
          onPressed: toExport.isEmpty
              ? null
              : () => ShellTabs.goTo(context, ShellTab.exports),
        ),
        const SectionTitle('Mes propres dépenses'),
        Row(
          children: [
            Expanded(
              child: RemboSecondaryButton(
                key: const ValueKey('home-add'),
                label: 'Nouvelle',
                icon: Icons.photo_camera_outlined,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.capture),
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: RemboSecondaryButton(
                label: 'Voir (${state.mine.length})',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyExpensesScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.note, {super.key});
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => RemboCard(
    padding: const EdgeInsets.all(RemboSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RemboText.caption),
        const SizedBox(height: RemboSpace.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: RemboText.amount.copyWith(fontSize: 20)),
        ),
        Text(note, style: RemboText.caption),
      ],
    ),
  );
}
