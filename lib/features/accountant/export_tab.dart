import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'export_setup_screen.dart';

/// « À exporter » : pick validated expenses to send to accounting.
class ExportTab extends StatefulWidget {
  const ExportTab({super.key});

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  /// Ids the accountant unticked; everything else is selected.
  final _excluded = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ready = state.toExport;
    final chosen = ready.where((e) => !_excluded.contains(e.id)).toList();
    final total = chosen.fold<int>(0, (s, e) => s + e.amountCents);
    final all = chosen.length == ready.length;

    return RemboPage(
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      bottom: RemboPrimaryButton(
        key: const ValueKey('export-prepare'),
        label: 'Préparer l’export',
        onPressed: chosen.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExportSetupScreen(
                    expenseIds: [for (final e in chosen) e.id],
                  ),
                ),
              ),
      ),
      children: [
        const RemboHero(title: 'À exporter', illustration: RemboArt.folder),
        if (state.loadError != null)
          RemboMessage(
            tone: MessageTone.error,
            title: 'Chargement impossible',
            message: state.loadError!.message,
            action: TextButton(
              onPressed: state.refresh,
              child: const Text('Réessayer'),
            ),
          )
        else if (ready.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              key: const ValueKey('export-empty'),
              children: [
                Text('Rien à exporter', style: RemboText.subtitle),
                Text(
                  'Les dépenses validées apparaîtront ici.',
                  style: RemboText.caption,
                ),
              ],
            ),
          )
        else ...[
          // A Wrap: with large text the action goes under the count.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                chosen.length == 1
                    ? '1 dépense sélectionnée'
                    : '${chosen.length} dépenses sélectionnées',
                key: const ValueKey('export-count'),
                style: RemboText.subtitle,
              ),
              TextButton(
                key: const ValueKey('export-toggle-all'),
                onPressed: () => setState(() {
                  _excluded.clear();
                  if (all) _excluded.addAll(ready.map((e) => e.id));
                }),
                child: Text(all ? 'Tout désélectionner' : 'Tout sélectionner'),
              ),
            ],
          ),
          for (final e in ready)
            ExpenseTile(
              e,
              key: ValueKey('export-${e.id}'),
              subtitle:
                  '${e.employeeName} · '
                  '${e.date == null ? '' : formatDayShort(e.date!)}',
              leading: Checkbox(
                value: !_excluded.contains(e.id),
                onChanged: (v) => setState(
                  () =>
                      v ?? false ? _excluded.remove(e.id) : _excluded.add(e.id),
                ),
              ),
              badge: RemboBadge(
                label: e.approvedByAgent
                    ? 'Validée par l’agent'
                    : 'Par responsable',
                tone: e.approvedByAgent ? BadgeTone.success : BadgeTone.warning,
                icon: e.approvedByAgent
                    ? Icons.check_circle_outline_rounded
                    : Icons.person_outline_rounded,
              ),
              onTap: () => setState(
                () => _excluded.contains(e.id)
                    ? _excluded.remove(e.id)
                    : _excluded.add(e.id),
              ),
            ),
          const SizedBox(height: RemboSpace.sm),
          RemboCard(
            color: RemboColors.surface,
            borderColor: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total sélection', style: RemboText.body),
                      Text(
                        formatMad(total),
                        key: const ValueKey('export-total'),
                        style: RemboText.amount.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),
                const HeroArt(height: 72, art: RemboArt.approved),
              ],
            ),
          ),
        ],
        if (state.exports.isNotEmpty) ...[
          const SectionTitle('Exports récents'),
          for (final b in state.exports.take(5)) ExportBatchTile(b),
        ],
      ],
    );
  }
}

class ExportBatchTile extends StatelessWidget {
  const ExportBatchTile(this.batch, {super.key});
  final ExportBatch batch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.sm),
    child: RemboCard(
      padding: const EdgeInsets.all(RemboSpace.md),
      child: Row(
        children: [
          const IconTile(Icons.description_outlined),
          const SizedBox(width: RemboSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.fileName,
                  style: RemboText.amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${batch.count} dépense${batch.count > 1 ? 's' : ''} · '
                  '${formatDateLong(batch.createdAt)}',
                  style: RemboText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: RemboSpace.sm),
          Text(formatMad(batch.totalCents), style: RemboText.amount),
        ],
      ),
    ),
  );
}
