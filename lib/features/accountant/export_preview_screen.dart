import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'export_store.dart';

class ExportPreviewScreen extends StatelessWidget {
  const ExportPreviewScreen({super.key, required this.store});
  final ExportStore store;

  Future<void> _export(BuildContext context) async {
    final selection = store.selection;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporter en CSV ?'),
        content: Text(
          '${selection.length} dépense${selection.length > 1 ? 's' : ''} · '
          '${formatMad(store.selectedTotal)}\n'
          'Elles sortiront de la liste à exporter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('confirm-export'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exporter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final record = store.export(DateTime.now());
    showRemboSnackBar(context, '${record.fileName} prêt (simulation)');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selection = store.selection;
    final lines = ExportStore.csvLines(selection);
    DataCell cell(String text, {bool mono = false}) =>
        DataCell(Text(text, style: mono ? RemboText.amount : RemboText.body));
    return Scaffold(
      appBar: AppBar(title: const Text('Prévisualisation de l’export')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            Text(
              '${selection.length} dépense${selection.length > 1 ? 's' : ''}'
              ' · ${formatMad(store.selectedTotal)}',
              key: const ValueKey('preview-summary'),
              style: RemboText.title,
            ),
            const SizedBox(height: RemboSpace.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: RemboText.label.copyWith(
                    color: RemboColors.muted,
                  ),
                  columns: const [
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('FOURNISSEUR')),
                    DataColumn(label: Text('MONTANT'), numeric: true),
                    DataColumn(label: Text('TVA'), numeric: true),
                    DataColumn(label: Text('CATÉGORIE')),
                    DataColumn(label: Text('PROJET')),
                  ],
                  rows: [
                    for (final e in selection)
                      DataRow(
                        cells: [
                          cell(formatDate(e.date)),
                          cell(e.supplier),
                          cell(formatMad(e.amountCentimes), mono: true),
                          cell(formatMad(e.vatCentimes), mono: true),
                          cell(e.category),
                          cell(e.project ?? '—'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: RemboSpace.xl),
            const Text('Aperçu du fichier', style: RemboText.subtitle),
            const SizedBox(height: RemboSpace.sm),
            Container(
              padding: const EdgeInsets.all(RemboSpace.lg),
              decoration: BoxDecoration(
                color: RemboColors.ink,
                borderRadius: BorderRadius.circular(RemboRadius.md),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  lines.join('\n'),
                  key: const ValueKey('csv-preview'),
                  style: RemboText.amount.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: RemboSpace.lg),
            const RemboMessage(
              tone: MessageTone.info,
              title: 'Simulation',
              message: 'Aucun fichier n’est créé dans cette version.',
            ),
            const SizedBox(height: RemboSpace.xl),
            RemboPrimaryButton(
              key: const ValueKey('export-csv'),
              label: 'Exporter en CSV',
              icon: Icons.download_rounded,
              onPressed: selection.isEmpty ? null : () => _export(context),
            ),
          ],
        ),
      ),
    );
  }
}
